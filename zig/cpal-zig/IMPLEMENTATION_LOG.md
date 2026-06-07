# Implementation Log

## 2026-06-07

Initial goal: port the architecture of RustAudio CPAL to idiomatic Zig, starting
with an ALSA-on-Linux MVP.

Design decisions:

- The API is architecture-inspired, not a line-by-line Rust translation.
- Backends are represented by tagged unions and small backend-specific structs.
- Public fallible operations use Zig error unions instead of Rust-style result
  enums.
- Optional values are used for absent default devices and backend availability.
- The ALSA backend owns duplicated device strings and requires callers to pass an
  allocator for enumeration.
- Stream callbacks use a plain function pointer plus optional userdata. This is
  explicit, C-compatible, and avoids hidden allocation.
- The first stream formats wired through ALSA are `f32` and `i16` interleaved
  audio. Additional sample formats are modeled in the public API but not all are
  wired into ALSA stream creation yet.

Current ALSA behavior:

- ALSA output and input stream configuration enumeration probe
  `snd_pcm_hw_params` for interleaved playback/capture support and report
  `f32`/`i16` ranges only when ALSA accepts those formats.
- Default output and input devices are represented by the ALSA `default` PCM.
- Output streams use `snd_pcm_writei`; input streams use `snd_pcm_readi`.
- `f32` and `i16` typed stream builders are implemented for playback and
  capture.
- Public config negotiation helpers can choose a supported format, channel
  count, sample rate, and requested/default buffer size from probed ranges.
- Stream callbacks carry callback and playback/capture timestamps. ALSA
  timestamps come from `snd_pcm_htimestamp` when available, with a monotonic
  fallback.
- Stream error callbacks are supported. ALSA `EPIPE` is surfaced as
  `AudioError.Xrun`; failed recovery stops the worker thread.
- `Stream.bufferSize()` returns the ALSA period size when it can be queried.
- `play()` prepares the ALSA PCM before starting the worker thread, and output
  streams now handle short `snd_pcm_writei` results by continuing until the
  requested period has been written or an error occurs.

Unsupported or incomplete:

- ALSA channel discovery still collapses ALSA's min/max channel range to one
  representative channel count because the current public
  `SupportedStreamConfigRange` model only stores a single channel count. It
  prefers stereo when available, otherwise the minimum supported channel count.
- ALSA sample-rate and period-size ranges are direct `snd_pcm_hw_params` ranges;
  they may still be broad for virtual devices such as PulseAudio/ALSA plugins.
- ALSA streams use ordinary worker threads, `snd_pcm_readi`, and
  `snd_pcm_writei`; this is not yet a low-latency real-time callback
  integration with scheduling/priority tuning.
- Input streams deliver short reads to the callback when ALSA returns fewer
  frames than requested; deeper buffering/poll integration remains future work.
- The input-output feedback example now negotiates matching default-device
  format, channel count, and sample rate, but more CPAL-like cross-device
  negotiation remains future work.
- Only `f32` and `i16` stream creation are implemented. Other sample formats are
  modeled, but not yet probed and exposed through typed builders.
- CoreAudio, WASAPI, JACK, and PulseAudio are extension stubs only.
- Device metadata is much smaller than CPAL's `DeviceDescription`.
- Backend-specific latency correction and precise drift handling are not
  implemented.
- Hotplug monitoring, exhaustive format/channel matrices, device-specific
  quirks, and advanced plugin behavior remain outside this milestone.

Validation performed:

- `zig build` passes with Zig 0.16.0.
- `zig build test` passes.
- `./zig-out/bin/list_hosts_devices` enumerates ALSA PCM hints and the null
  fallback on the local Linux environment.
- `./zig-out/bin/print_stream_configs` prints ALSA-probed output and input
  config ranges for the default devices, including period-size frame ranges.
- `./zig-out/bin/open_output_stream` successfully opens a silent ALSA output
  stream on the local default device.
- `./zig-out/bin/record_input` successfully opens a local ALSA input stream and
  records callback meter data for two seconds. Local run used 2 channels at
  48 kHz with a 1200-frame buffer and reported zero callback errors.
- `./zig-out/bin/open_i16_streams` successfully opens local ALSA `i16` playback
  and capture streams. Local run used 2 channels at 48 kHz and reported
  `output_calls=59`, `input_calls=33`, `input_samples=16896`, and zero callback
  errors.
- `./zig-out/bin/open_output_stream` and `./zig-out/bin/open_i16_streams` were
  rerun after the ALSA prepare/short-write changes and both passed locally.
- `./zig-out/bin/sine_wave` is built but was not run automatically because it
  produces audible output.
- `./zig-out/bin/input_output_feedback` is built but was not run automatically
  because it monitors live input to output and can create audible feedback.

Runtime fixes found during smoke testing:

- ALSA hint values are nullable C pointers, not Zig optionals; hint parsing now
  checks for null before converting to slices.
- Backend device ownership now moves into the public `DeviceList` exactly once.
  The first version deinitialized moved device strings too early.
- ALSA device IDs are stored as sentinel-terminated slices before passing them
  to `snd_pcm_open`.
- ALSA output config probing replaced the initial fixed placeholder ranges.
  The local default device reports `f32` and `i16` interleaved playback support.
- ALSA input config probing now uses the same hardware-parameter path for
  capture devices.
- ALSA `i16` stream creation now uses `SND_PCM_FORMAT_S16_LE`; `f32` stream
  creation uses `SND_PCM_FORMAT_FLOAT_LE`.
- The input-output feedback example now uses public config negotiation rather
  than force-copying output channel count and sample rate into the input stream.
- ALSA `play()` now resets the running flag if prepare or thread spawn fails,
  avoiding a stuck running state after startup errors.
- ALSA output streams now handle partial writes rather than treating any
  non-negative `snd_pcm_writei` return as a full period.
- The null backend now exposes separate input and output devices so input stream
  and `i16` stream tests can run without hardware.

Differences from Rust CPAL:

- `Host`, `Device`, and `Stream` are Zig tagged unions instead of Rust enums
  generated through macros.
- The Zig API separates `buildOutputStreamF32`/`buildOutputStreamI16` from future
  typed/comptime stream builders.
- The Zig API has matching `buildInputStreamF32`/`buildInputStreamI16` rather
  than CPAL's generic typed builder surface.
- Callers explicitly deinitialize devices, device lists, hosts, and streams that
  own memory or native handles.
- Unsupported backends are present as named extension points rather than hidden
  behind feature flags in this first milestone.
