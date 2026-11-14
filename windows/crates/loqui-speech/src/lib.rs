//! Speech into text on the PC itself: sherpa-onnx (v2.0.1, its C API) running
//! NVIDIA's Parakeet TDT 0.6B v3 model, with the Silero voice activity model
//! cutting the recording into segments at pauses. Each segment is turned into
//! text as soon as it ends, so when a dictation stops only the last one is
//! left to do. Nothing here touches the network.
//!
//! The engine's library is loaded when loqui starts. The structs below copy
//! the start of the v2.0.1 header (`sherpa-onnx/c-api/c-api.h`) exactly; every
//! field after the ones loqui sets is left zero, which the library reads as
//! "use the default". Upgrading the engine means checking them against the
//! new header.

use libloading::Library;
use std::ffi::{c_char, c_void, CStr, CString};
use std::path::{Path, PathBuf};

pub const SAMPLE_RATE: i32 = 16_000;

/// Where the engine and model files sit, relative to one folder (the
/// install folder on Windows).
#[derive(Debug, Clone)]
pub struct Files {
    pub engine: PathBuf,
    pub model: PathBuf,
    pub vad: PathBuf,
}

impl Files {
    pub fn under(root: &Path) -> Self {
        Self {
            engine: root.join("engine").join(LIBRARY),
            model: root.join("models").join("parakeet"),
            vad: root.join("models").join("silero_vad.onnx"),
        }
    }
}

#[cfg(windows)]
const LIBRARY: &str = "sherpa-onnx-c-api.dll";
#[cfg(target_os = "macos")]
const LIBRARY: &str = "libsherpa-onnx-c-api.dylib";
#[cfg(not(any(windows, target_os = "macos")))]
const LIBRARY: &str = "libsherpa-onnx-c-api.so";

/// How the voice activity model cuts segments. A pause of half a second ends a
/// segment; a segment that runs past 8 s is cut at its next short pause, so
/// the last one, decoded after you stop, stays short.
const MIN_SILENCE: f32 = 0.5;
const MIN_SPEECH: f32 = 0.25;
const MAX_SPEECH: f32 = 8.0;
const VAD_WINDOW: i32 = 512;
const VAD_BUFFER_SECONDS: f32 = 120.0;

/// A stretch of speech and its text. Times are seconds since the recording began.
#[derive(Debug, Clone, PartialEq)]
pub struct Segment {
    pub text: String,
    pub start: f64,
    pub end: f64,
}

#[repr(C)]
struct FeatureConfig {
    sample_rate: i32,
    feature_dim: i32,
}

#[repr(C)]
struct TransducerConfig {
    encoder: *const c_char,
    decoder: *const c_char,
    joiner: *const c_char,
}

#[repr(C)]
struct WhisperConfig {
    encoder: *const c_char,
    decoder: *const c_char,
    language: *const c_char,
    task: *const c_char,
    tail_paddings: i32,
    enable_token_timestamps: i32,
    enable_segment_timestamps: i32,
}

/// `SherpaOnnxOfflineModelConfig` up to `telespeech_ctc`.
#[repr(C)]
struct ModelConfigStart {
    transducer: TransducerConfig,
    paraformer: *const c_char,
    nemo_ctc: *const c_char,
    whisper: WhisperConfig,
    tdnn: *const c_char,
    tokens: *const c_char,
    num_threads: i32,
    debug: i32,
    provider: *const c_char,
    model_type: *const c_char,
    modeling_unit: *const c_char,
    bpe_vocab: *const c_char,
    telespeech_ctc: *const c_char,
}

/// `SherpaOnnxOfflineRecognizerConfig`: the fields loqui sets, then zeros
/// covering the rest of the struct (about 550 bytes in v2.0.1) with room to spare.
#[repr(C)]
struct RecognizerConfig {
    feat: FeatureConfig,
    model: ModelConfigStart,
    rest: [u64; 256],
}

#[repr(C)]
#[derive(Clone, Copy)]
struct SileroConfig {
    model: *const c_char,
    threshold: f32,
    min_silence_duration: f32,
    min_speech_duration: f32,
    window_size: i32,
    max_speech_duration: f32,
}

/// `SherpaOnnxVadModelConfig`, all of it. `ten_vad` has the Silero layout.
#[repr(C)]
struct VadConfig {
    silero: SileroConfig,
    sample_rate: i32,
    num_threads: i32,
    provider: *const c_char,
    debug: i32,
    ten_vad: SileroConfig,
}

#[repr(C)]
struct SpeechSegment {
    start: i64,
    samples: *const f32,
    n: i32,
}

/// `SherpaOnnxOfflineRecognizerResult`: only its first field is read.
#[repr(C)]
struct RecognizerResult {
    text: *const c_char,
}

type Ptr = *const c_void;

struct Api {
    create_recognizer: unsafe extern "C" fn(*const RecognizerConfig) -> Ptr,
    destroy_recognizer: unsafe extern "C" fn(Ptr),
    create_stream: unsafe extern "C" fn(Ptr) -> Ptr,
    destroy_stream: unsafe extern "C" fn(Ptr),
    accept_waveform: unsafe extern "C" fn(Ptr, i32, *const f32, i32),
    decode: unsafe extern "C" fn(Ptr, Ptr),
    get_result: unsafe extern "C" fn(Ptr) -> *const RecognizerResult,
    destroy_result: unsafe extern "C" fn(*const RecognizerResult),
    create_vad: unsafe extern "C" fn(*const VadConfig, f32) -> Ptr,
    destroy_vad: unsafe extern "C" fn(Ptr),
    vad_accept: unsafe extern "C" fn(Ptr, *const f32, i32),
    vad_empty: unsafe extern "C" fn(Ptr) -> i32,
    vad_front: unsafe extern "C" fn(Ptr) -> *const SpeechSegment,
    vad_pop: unsafe extern "C" fn(Ptr),
    vad_flush: unsafe extern "C" fn(Ptr),
    vad_reset: unsafe extern "C" fn(Ptr),
    vad_detected: unsafe extern "C" fn(Ptr) -> i32,
    destroy_segment: unsafe extern "C" fn(*const SpeechSegment),
    // Last, so the library is unloaded after everything above is gone.
    _library: Library,
}

impl Api {
    fn load(path: &Path) -> Result<Self, String> {
        let library = open(path).map_err(|e| format!("can't load {}: {e}", path.display()))?;
        macro_rules! sym {
            ($name:literal) => {
                // SAFETY: each type above matches the v2.0.1 header's declaration.
                *unsafe { library.get(concat!($name, "\0").as_bytes()) }
                    .map_err(|e| format!("the engine has no {}: {e}", $name))?
            };
        }
        Ok(Self {
            create_recognizer: sym!("SherpaOnnxCreateOfflineRecognizer"),
            destroy_recognizer: sym!("SherpaOnnxDestroyOfflineRecognizer"),
            create_stream: sym!("SherpaOnnxCreateOfflineStream"),
            destroy_stream: sym!("SherpaOnnxDestroyOfflineStream"),
            accept_waveform: sym!("SherpaOnnxAcceptWaveformOffline"),
            decode: sym!("SherpaOnnxDecodeOfflineStream"),
            get_result: sym!("SherpaOnnxGetOfflineStreamResult"),
            destroy_result: sym!("SherpaOnnxDestroyOfflineRecognizerResult"),
            create_vad: sym!("SherpaOnnxCreateVoiceActivityDetector"),
            destroy_vad: sym!("SherpaOnnxDestroyVoiceActivityDetector"),
            vad_accept: sym!("SherpaOnnxVoiceActivityDetectorAcceptWaveform"),
            vad_empty: sym!("SherpaOnnxVoiceActivityDetectorEmpty"),
            vad_front: sym!("SherpaOnnxVoiceActivityDetectorFront"),
            vad_pop: sym!("SherpaOnnxVoiceActivityDetectorPop"),
            vad_flush: sym!("SherpaOnnxVoiceActivityDetectorFlush"),
            vad_reset: sym!("SherpaOnnxVoiceActivityDetectorReset"),
            vad_detected: sym!("SherpaOnnxVoiceActivityDetectorDetected"),
            destroy_segment: sym!("SherpaOnnxDestroySpeechSegment"),
            _library: library,
        })
    }
}

/// Load by full path. On Windows the engine's own folder is searched for the
/// libraries it needs (onnxruntime.dll), and nothing else is.
fn open(path: &Path) -> Result<Library, libloading::Error> {
    #[cfg(windows)]
    {
        use libloading::os::windows::{Library as WinLibrary, LOAD_WITH_ALTERED_SEARCH_PATH};
        // SAFETY: the engine's initialisers are plain C++ static setup.
        unsafe { WinLibrary::load_with_flags(path, LOAD_WITH_ALTERED_SEARCH_PATH) }.map(Into::into)
    }
    #[cfg(not(windows))]
    {
        // SAFETY: as above.
        unsafe { Library::new(path) }
    }
}

fn c_path(path: &Path) -> Result<CString, String> {
    if !path.exists() {
        return Err(format!("missing {}", path.display()));
    }
    CString::new(path.to_string_lossy().as_bytes()).map_err(|e| e.to_string())
}

/// The loaded model and voice activity detector. Load once; it takes a few
/// seconds and keeps about 1 GB of memory.
pub struct Engine {
    api: Api,
    recognizer: Ptr,
    vad: Ptr,
}

// SAFETY: the engine's handles are used from one thread at a time (the
// speech thread owns the Engine); sherpa-onnx objects aren't tied to the
// thread that made them.
unsafe impl Send for Engine {}

impl Engine {
    pub fn load(files: &Files, threads: i32) -> Result<Self, String> {
        let api = Api::load(&files.engine)?;
        let part = |name: &str| c_path(&files.model.join(name));
        let (encoder, decoder, joiner, tokens) = (
            part("encoder.int8.onnx")?,
            part("decoder.int8.onnx")?,
            part("joiner.int8.onnx")?,
            part("tokens.txt")?,
        );
        let vad_model = c_path(&files.vad)?;
        let provider = c"cpu";
        let null = std::ptr::null();

        let config = RecognizerConfig {
            feat: FeatureConfig {
                sample_rate: SAMPLE_RATE,
                feature_dim: 80,
            },
            model: ModelConfigStart {
                transducer: TransducerConfig {
                    encoder: encoder.as_ptr(),
                    decoder: decoder.as_ptr(),
                    joiner: joiner.as_ptr(),
                },
                paraformer: null,
                nemo_ctc: null,
                whisper: WhisperConfig {
                    encoder: null,
                    decoder: null,
                    language: null,
                    task: null,
                    tail_paddings: 0,
                    enable_token_timestamps: 0,
                    enable_segment_timestamps: 0,
                },
                tdnn: null,
                tokens: tokens.as_ptr(),
                num_threads: threads,
                debug: 0,
                provider: provider.as_ptr(),
                model_type: c"nemo_transducer".as_ptr(),
                modeling_unit: null,
                bpe_vocab: null,
                telespeech_ctc: null,
            },
            rest: [0; 256],
        };
        // SAFETY: the config and every string it points to outlive the call;
        // the library copies what it keeps.
        let recognizer = unsafe { (api.create_recognizer)(&config) };
        if recognizer.is_null() {
            return Err("the speech model didn't load".into());
        }

        let silero = SileroConfig {
            model: vad_model.as_ptr(),
            threshold: 0.5,
            min_silence_duration: MIN_SILENCE,
            min_speech_duration: MIN_SPEECH,
            window_size: VAD_WINDOW,
            max_speech_duration: MAX_SPEECH,
        };
        let vad_config = VadConfig {
            silero,
            sample_rate: SAMPLE_RATE,
            num_threads: 1,
            provider: provider.as_ptr(),
            debug: 0,
            ten_vad: SileroConfig {
                model: null,
                ..silero
            },
        };
        // SAFETY: as above.
        let vad = unsafe { (api.create_vad)(&vad_config, VAD_BUFFER_SECONDS) };
        if vad.is_null() {
            // SAFETY: made just above, used nowhere else.
            unsafe { (api.destroy_recognizer)(recognizer) };
            return Err("the voice activity model didn't load".into());
        }
        Ok(Self {
            api,
            recognizer,
            vad,
        })
    }

    /// Start a new recording: segment times count from here.
    pub fn reset(&mut self) {
        // SAFETY: `vad` is live for as long as `self`.
        unsafe { (self.api.vad_reset)(self.vad) };
    }

    /// Feed 16 kHz mono audio. Returns the text of any segments that ended.
    pub fn accept(&mut self, samples: &[f32]) -> Vec<Segment> {
        if !samples.is_empty() {
            // SAFETY: the pointer and length describe `samples`.
            unsafe { (self.api.vad_accept)(self.vad, samples.as_ptr(), samples.len() as i32) };
        }
        self.drain()
    }

    /// DIAG: whether the voice activity model is inside speech right now.
    pub fn detected(&self) -> bool {
        // SAFETY: `vad` is live.
        unsafe { (self.api.vad_detected)(self.vad) != 0 }
    }

    /// The recording stopped: turn whatever speech is left into text.
    pub fn finish(&mut self) -> Vec<Segment> {
        // SAFETY: `vad` is live.
        unsafe { (self.api.vad_flush)(self.vad) };
        self.drain()
    }

    fn drain(&mut self) -> Vec<Segment> {
        let mut out = Vec::new();
        // SAFETY: `front` is only read while the queue is non-empty, and each
        // segment is copied out before it's destroyed and popped.
        unsafe {
            while (self.api.vad_empty)(self.vad) == 0 {
                let seg = (self.api.vad_front)(self.vad);
                if !seg.is_null() {
                    let s = &*seg;
                    let samples = std::slice::from_raw_parts(s.samples, s.n.max(0) as usize);
                    let start = s.start as f64 / f64::from(SAMPLE_RATE);
                    let end = start + samples.len() as f64 / f64::from(SAMPLE_RATE);
                    let text = self.decode(samples);
                    (self.api.destroy_segment)(seg);
                    if !text.is_empty() {
                        out.push(Segment { text, start, end });
                    }
                }
                (self.api.vad_pop)(self.vad);
            }
        }
        out
    }

    /// Turn one stretch of audio into text.
    pub fn decode(&self, samples: &[f32]) -> String {
        if samples.is_empty() {
            return String::new();
        }
        // SAFETY: the stream and result are made, read and destroyed here.
        unsafe {
            let stream = (self.api.create_stream)(self.recognizer);
            if stream.is_null() {
                return String::new();
            }
            (self.api.accept_waveform)(stream, SAMPLE_RATE, samples.as_ptr(), samples.len() as i32);
            (self.api.decode)(self.recognizer, stream);
            let result = (self.api.get_result)(stream);
            let text = if result.is_null() || (*result).text.is_null() {
                String::new()
            } else {
                CStr::from_ptr((*result).text)
                    .to_string_lossy()
                    .trim()
                    .to_string()
            };
            if !result.is_null() {
                (self.api.destroy_result)(result);
            }
            (self.api.destroy_stream)(stream);
            text
        }
    }
}

impl Drop for Engine {
    fn drop(&mut self) {
        // SAFETY: both handles are live and used nowhere else.
        unsafe {
            (self.api.destroy_vad)(self.vad);
            (self.api.destroy_recognizer)(self.recognizer);
        }
    }
}

/// Threads for the model: the experiment's four, or fewer on a smaller PC.
pub fn threads() -> i32 {
    std::thread::available_parallelism().map_or(2, |n| n.get().min(4) as i32)
}
