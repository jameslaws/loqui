//! The microphone, through WASAPI in shared mode on Windows' default
//! communications microphone. Windows converts whatever the microphone gives
//! into 16 kHz mono, the speech engine's format.
//!
//! Each dictation opens the microphone on its own thread and closes it when
//! it stops. If the microphone changes mid-dictation (a headset plugged in,
//! a device unplugged), the capture is rebuilt on the new default.

use crate::dictation::Event;
use crate::speech::ToSpeech;
use loqui_core::dictation::rms;
use loqui_core::records::Records;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{sync_channel, Sender};
use std::sync::Arc;
use std::thread::JoinHandle;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use windows::core::HRESULT;
use windows::Win32::Media::Audio::{
    eCapture, eCommunications, IAudioCaptureClient, IAudioClient, IMMDevice, IMMDeviceEnumerator,
    MMDeviceEnumerator, AUDCLNT_BUFFERFLAGS_DATA_DISCONTINUITY, AUDCLNT_BUFFERFLAGS_SILENT,
    AUDCLNT_SHAREMODE_SHARED, AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM,
    AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY, WAVEFORMATEX,
};
use windows::Win32::System::Com::{
    CoCreateInstance, CoInitializeEx, CoTaskMemFree, CoUninitialize, CLSCTX_ALL,
    COINIT_MULTITHREADED,
};
use windows_sys::Win32::System::Threading::{
    AvRevertMmThreadCharacteristics, AvSetMmThreadCharacteristicsW,
};

/// Why the microphone couldn't open.
#[derive(Debug)]
pub enum MicError {
    /// Windows' "Let desktop apps access your microphone" is off.
    Blocked,
    /// There is no microphone.
    Missing,
    Other(String),
}

const E_ACCESSDENIED: HRESULT = HRESULT(0x8007_0005_u32 as i32);
const E_NOTFOUND: HRESULT = HRESULT(0x8007_0490_u32 as i32);
const WAVE_FORMAT_IEEE_FLOAT: u16 = 3;
/// 20 ms at 16 kHz: how often the level is measured and audio passed on.
const BLOCK: usize = 320;
/// How much sound Windows holds for loqui between reads, in 100 ns units: one
/// second, so a moment's delay on a busy PC loses nothing.
const BUFFER: i64 = 10_000_000;

fn wide(text: &str) -> Vec<u16> {
    text.encode_utf16().chain(Some(0)).collect()
}

impl std::fmt::Display for MicError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Blocked => {
                f.write_str("Windows' microphone privacy setting is off for desktop apps")
            }
            Self::Missing => f.write_str("there is no microphone"),
            Self::Other(why) => f.write_str(why),
        }
    }
}

impl From<windows::core::Error> for MicError {
    fn from(e: windows::core::Error) -> Self {
        match e.code() {
            E_ACCESSDENIED => Self::Blocked,
            E_NOTFOUND => Self::Missing,
            _ => Self::Other(format!("{} ({:#010x})", e.message(), e.code().0)),
        }
    }
}

/// A running capture. Stopping it waits until every sample heard has been
/// passed on, so the speech thread has the whole recording.
pub struct Capture {
    stop: Arc<AtomicBool>,
    thread: Option<JoinHandle<()>>,
}

impl Capture {
    pub fn stop(mut self) {
        self.stop.store(true, Ordering::SeqCst);
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
    }
}

/// Where a capture sends its audio and level readings.
pub struct Outlets {
    pub id: u64,
    pub speech: Sender<ToSpeech>,
    pub events: Sender<Event>,
    pub records: Records,
}

impl Outlets {
    fn pass(&self, block: &mut Vec<f32>) {
        let _ = self.events.send(Event::Level(rms(block)));
        let _ = self
            .speech
            .send(ToSpeech::Audio(self.id, std::mem::take(block)));
    }

    fn log(&self, message: &str) {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_or(0, |d| d.as_secs() as i64);
        self.records.log(message, now);
    }
}

/// Open the microphone and start passing its audio on.
pub fn start(out: Outlets) -> Result<Capture, MicError> {
    let stop = Arc::new(AtomicBool::new(false));
    let flag = stop.clone();

    #[cfg(feature = "test-audio")]
    if let Some(path) = std::env::var_os("LOQUI_TEST_AUDIO") {
        let thread = std::thread::spawn(move || {
            test_audio::play(&std::path::PathBuf::from(path), &out, &flag)
        });
        return Ok(Capture {
            stop,
            thread: Some(thread),
        });
    }

    // Windows doesn't always refuse a blocked microphone: a desktop app can be
    // handed silence instead. So read the privacy switches first, every time
    // (switching them back on works without restarting loqui).
    if !crate::windows_shell::microphone_allowed() {
        return Err(MicError::Blocked);
    }

    let (opened, result) = sync_channel(1);
    let thread = std::thread::Builder::new()
        .name("loqui microphone".into())
        .spawn(move || {
            // SAFETY: COM is set up for this thread and torn down when it ends.
            if let Err(e) = unsafe { CoInitializeEx(None, COINIT_MULTITHREADED) }.ok() {
                let _ = opened.send(Err(MicError::from(e)));
                return;
            }
            // Windows' audio priority for this thread, so a busy PC doesn't
            // leave the microphone unread long enough to drop sound.
            let task = wide("Audio");
            let mut index = 0u32;
            // SAFETY: the name is null-terminated; the handle is reverted below.
            let priority = unsafe { AvSetMmThreadCharacteristicsW(task.as_ptr(), &mut index) };
            match Stream::open() {
                Ok(stream) => {
                    let _ = opened.send(Ok(()));
                    stream.run(&out, &flag);
                }
                Err(e) => {
                    let _ = opened.send(Err(e));
                }
            }
            if !priority.is_null() {
                // SAFETY: the handle came from AvSetMmThreadCharacteristicsW on this thread.
                unsafe { AvRevertMmThreadCharacteristics(priority) };
            }
            // SAFETY: matches the CoInitializeEx above; every COM object is gone.
            unsafe { CoUninitialize() };
        })
        .map_err(|e| MicError::Other(e.to_string()))?;
    match result.recv() {
        Ok(Ok(())) => Ok(Capture {
            stop,
            thread: Some(thread),
        }),
        Ok(Err(e)) => {
            let _ = thread.join();
            Err(e)
        }
        Err(_) => Err(MicError::Other("the microphone thread stopped".into())),
    }
}

struct Stream {
    enumerator: IMMDeviceEnumerator,
    client: IAudioClient,
    capture: IAudioCaptureClient,
    device: String,
}

fn device_id(device: &IMMDevice) -> String {
    // SAFETY: the string Windows returns is copied, then freed.
    unsafe {
        let Ok(id) = device.GetId() else {
            return String::new();
        };
        let text = id.to_string().unwrap_or_default();
        CoTaskMemFree(Some(id.0 as *const _));
        text
    }
}

impl Stream {
    fn open() -> Result<Self, MicError> {
        let format = WAVEFORMATEX {
            wFormatTag: WAVE_FORMAT_IEEE_FLOAT,
            nChannels: 1,
            nSamplesPerSec: 16_000,
            nAvgBytesPerSec: 64_000,
            nBlockAlign: 4,
            wBitsPerSample: 32,
            cbSize: 0,
        };
        // SAFETY: COM is initialised on this thread; `format` outlives Initialize.
        unsafe {
            let enumerator: IMMDeviceEnumerator =
                CoCreateInstance(&MMDeviceEnumerator, None, CLSCTX_ALL)?;
            let device = enumerator.GetDefaultAudioEndpoint(eCapture, eCommunications)?;
            let client: IAudioClient = device.Activate(CLSCTX_ALL, None)?;
            client.Initialize(
                AUDCLNT_SHAREMODE_SHARED,
                AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM | AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY,
                BUFFER,
                0,
                &format,
                None,
            )?;
            let capture: IAudioCaptureClient = client.GetService()?;
            client.Start()?;
            Ok(Self {
                enumerator,
                client,
                capture,
                device: device_id(&device),
            })
        }
    }

    /// Whether Windows' default microphone is still the one in use.
    fn still_default(&self) -> bool {
        // SAFETY: plain COM calls on live objects.
        unsafe {
            self.enumerator
                .GetDefaultAudioEndpoint(eCapture, eCommunications)
        }
        .is_ok_and(|device| device_id(&device) == self.device)
    }

    /// Everything captured since the last read, and how many gaps Windows
    /// reported in it (sound it had to drop).
    fn read(&self, into: &mut Vec<f32>) -> windows::core::Result<u32> {
        let mut gaps = 0;
        // SAFETY: each buffer is read within the frame count Windows gives,
        // then released.
        unsafe {
            while self.capture.GetNextPacketSize()? > 0 {
                let mut data = std::ptr::null_mut();
                let (mut frames, mut flags) = (0u32, 0u32);
                self.capture
                    .GetBuffer(&mut data, &mut frames, &mut flags, None, None)?;
                if flags & AUDCLNT_BUFFERFLAGS_DATA_DISCONTINUITY.0 as u32 != 0 {
                    gaps += 1;
                }
                if flags & AUDCLNT_BUFFERFLAGS_SILENT.0 as u32 != 0 || data.is_null() {
                    into.extend(std::iter::repeat_n(0.0, frames as usize));
                } else {
                    into.extend_from_slice(std::slice::from_raw_parts(
                        data.cast::<f32>(),
                        frames as usize,
                    ));
                }
                self.capture.ReleaseBuffer(frames)?;
            }
        }
        Ok(gaps)
    }

    fn run(mut self, out: &Outlets, stop: &AtomicBool) {
        let mut pending = Vec::with_capacity(BLOCK * 4);
        let mut checked = Instant::now();
        let mut broken = false;
        let mut gaps = 0;
        loop {
            let stopping = stop.load(Ordering::SeqCst);
            let read = self.read(&mut pending);
            let failed = read.is_err();
            gaps += read.unwrap_or(0);
            while pending.len() >= BLOCK {
                let mut block: Vec<f32> = pending.drain(..BLOCK).collect();
                out.pass(&mut block);
            }
            if stopping {
                if !pending.is_empty() {
                    out.pass(&mut pending);
                }
                if gaps > 0 {
                    out.log(&format!(
                        "WARNING: Windows dropped sound {gaps} times during this dictation"
                    ));
                }
                break;
            }
            let changed = checked.elapsed() > Duration::from_millis(500) && {
                checked = Instant::now();
                !self.still_default()
            };
            if failed || changed {
                if !broken {
                    out.log("audio device changed mid-dictation, rebuilding the capture");
                }
                match Self::open() {
                    Ok(fresh) => {
                        // SAFETY: stopping the old stream before it's dropped.
                        let _ = unsafe { self.client.Stop() };
                        self = fresh;
                        out.log("capture rebuilt, dictation continues");
                        broken = false;
                    }
                    Err(e) => {
                        if !broken {
                            out.log(&format!("capture rebuild FAILED: {e}; retrying"));
                        }
                        broken = true;
                    }
                }
            }
            std::thread::sleep(Duration::from_millis(10));
        }
        // SAFETY: the stream is live until dropped just after.
        let _ = unsafe { self.client.Stop() };
    }
}

/// Test builds only: a WAV file stands in for the microphone, played at the
/// speed it was recorded, then silence.
#[cfg(feature = "test-audio")]
mod test_audio {
    use super::{Outlets, BLOCK};
    use std::path::Path;
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::time::{Duration, Instant};

    /// The samples of a 16 kHz mono 16-bit WAV.
    fn read(path: &Path) -> Vec<f32> {
        let bytes = std::fs::read(path).unwrap_or_default();
        let mut i = 12;
        while i + 8 <= bytes.len() {
            let len = u32::from_le_bytes([bytes[i + 4], bytes[i + 5], bytes[i + 6], bytes[i + 7]])
                as usize;
            if &bytes[i..i + 4] == b"data" {
                let end = (i + 8 + len).min(bytes.len());
                return bytes[i + 8..end]
                    .as_chunks::<2>()
                    .0
                    .iter()
                    .map(|b| f32::from(i16::from_le_bytes(*b)) / 32_768.0)
                    .collect();
            }
            i += 8 + len + (len & 1);
        }
        Vec::new()
    }

    pub fn play(path: &Path, out: &Outlets, stop: &AtomicBool) {
        let samples = read(path);
        out.log(&format!(
            "test audio: {} samples from a file",
            samples.len()
        ));
        let started = Instant::now();
        let mut sent = 0usize;
        while !stop.load(Ordering::SeqCst) {
            let due = (started.elapsed().as_secs_f64() * 16_000.0) as usize;
            while sent + BLOCK <= due {
                let mut block: Vec<f32> = (sent..sent + BLOCK)
                    .map(|i| samples.get(i).copied().unwrap_or(0.0))
                    .collect();
                out.pass(&mut block);
                sent += BLOCK;
            }
            std::thread::sleep(Duration::from_millis(10));
        }
    }
}
