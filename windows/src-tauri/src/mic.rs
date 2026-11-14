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
        diag::begin();
        let stop_at = std::cell::Cell::new(None::<Instant>);
        let mut pending = Vec::with_capacity(BLOCK * 4);
        let mut checked = Instant::now();
        let mut broken = false;
        // Where Windows dropped sound, in seconds into the dictation. Its very
        // first packet is always marked, so that one isn't counted.
        let mut gaps: Vec<f64> = Vec::new();
        let mut heard = 0usize;
        loop {
            let stopping = stop.load(Ordering::SeqCst);
            if stopping && stop_at.get().is_none() {
                stop_at.set(Some(Instant::now()));
            }
            let before = pending.len();
            let read = self.read(&mut pending);
            let failed = read.is_err();
            if read.is_ok_and(|g| g > 0) && heard > 0 {
                gaps.push(heard as f64 / 16_000.0);
            }
            heard += pending.len() - before;
            diag::keep(&pending[before..]);
            while pending.len() >= BLOCK {
                let mut block: Vec<f32> = pending.drain(..BLOCK).collect();
                out.pass(&mut block);
            }
            if stopping {
                let final_read = pending.len();
                if !pending.is_empty() {
                    out.pass(&mut pending);
                }
                // DIAG: keep reading 800 ms after the stop, without passing it
                // on, to see what the release left behind.
                let after_started = Instant::now();
                let mut after: Vec<f32> = Vec::new();
                while after_started.elapsed() < Duration::from_millis(800) {
                    let _ = self.read(&mut after);
                    std::thread::sleep(Duration::from_millis(10));
                }
                diag::stop(out, &stop_at, heard, final_read, &after);
                if !gaps.is_empty() {
                    let at: Vec<String> = gaps.iter().map(|g| format!("{g:.2}s")).collect();
                    out.log(&format!(
                        "WARNING: Windows dropped sound during this dictation, at {}",
                        at.join(", ")
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

/// DIAG ONLY (branch diag-dict04, never merged): what the microphone heard
/// before and after the stop, logged and saved as a WAV.
mod diag {
    use super::Outlets;
    use std::cell::RefCell;
    use std::time::Instant;

    thread_local! {
        static HEARD: RefCell<Vec<f32>> = const { RefCell::new(Vec::new()) };
    }

    pub fn begin() {
        HEARD.with(|h| h.borrow_mut().clear());
    }

    pub fn keep(samples: &[f32]) {
        HEARD.with(|h| h.borrow_mut().extend_from_slice(samples));
    }

    fn rms(s: &[f32]) -> f32 {
        if s.is_empty() {
            return 0.0;
        }
        (s.iter().map(|x| x * x).sum::<f32>() / s.len() as f32).sqrt()
    }

    pub fn stop(
        out: &Outlets,
        stop_at: &std::cell::Cell<Option<Instant>>,
        heard: usize,
        final_read: usize,
        after: &[f32],
    ) {
        let lag = stop_at
            .get()
            .map_or(0.0, |t| t.elapsed().as_secs_f64() - 0.8);
        let loud: Vec<String> = after
            .chunks(320)
            .enumerate()
            .filter(|(_, b)| rms(b) > 0.005)
            .map(|(i, b)| format!("{}ms:{:.3}", i * 20, rms(b)))
            .collect();
        // The last 1 s of what was kept, in 100 ms levels.
        let tail: Vec<String> = HEARD.with(|h| {
            let h = h.borrow();
            let from = h.len().saturating_sub(16_000);
            h[from..]
                .chunks(1600)
                .map(|b| format!("{:.3}", rms(b)))
                .collect()
        });
        out.log(&format!(
            "DIAG stop: id {} kept {heard} samples ({:.3}s), last read at stop {final_read}; after stop {} samples in 800ms (lag {lag:.3}s), loud 20ms blocks after stop [{}]; levels of last 1s kept [{}]",
            out.id,
            heard as f64 / 16_000.0,
            after.len(),
            loud.join(" "),
            tail.join(" ")
        ));
        let Some(dir) = loqui_core::records::data_dir() else {
            return;
        };
        let path = dir.join("logs").join(format!("diag-{}.wav", out.id));
        HEARD.with(|h| {
            let mut all = h.borrow().clone();
            all.extend_from_slice(after);
            let _ = write_wav(&path, &all);
            let _ = write_wav(
                &dir.join("logs").join(format!("diag-{}-kept.wav", out.id)),
                &h.borrow(),
            );
        });
    }

    fn write_wav(path: &std::path::Path, samples: &[f32]) -> std::io::Result<()> {
        let data = (samples.len() * 2) as u32;
        let mut b = Vec::with_capacity(44 + data as usize);
        b.extend_from_slice(b"RIFF");
        b.extend_from_slice(&(36 + data).to_le_bytes());
        b.extend_from_slice(b"WAVEfmt ");
        b.extend_from_slice(&16u32.to_le_bytes());
        b.extend_from_slice(&1u16.to_le_bytes());
        b.extend_from_slice(&1u16.to_le_bytes());
        b.extend_from_slice(&16_000u32.to_le_bytes());
        b.extend_from_slice(&32_000u32.to_le_bytes());
        b.extend_from_slice(&2u16.to_le_bytes());
        b.extend_from_slice(&16u16.to_le_bytes());
        b.extend_from_slice(b"data");
        b.extend_from_slice(&data.to_le_bytes());
        for s in samples {
            let v = (s.clamp(-1.0, 1.0) * 32_767.0) as i16;
            b.extend_from_slice(&v.to_le_bytes());
        }
        std::fs::write(path, b)
    }
}
