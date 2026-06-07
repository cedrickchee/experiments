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
- The first output stream format is `f32` interleaved audio. Additional sample
  formats are modeled in the public API but not all are wired into ALSA stream
  creation yet.

Unsupported or incomplete:

- Input streams are not implemented.
- ALSA output stream configuration enumeration now probes `snd_pcm_hw_params`
  for interleaved playback support and reports `f32`/`i16` ranges only when ALSA
  accepts those formats.
- ALSA channel discovery still collapses ALSA's min/max channel range to one
  representative channel count because the current public
  `SupportedStreamConfigRange` model only stores a single channel count. It
  prefers stereo when available, otherwise the minimum supported channel count.
- ALSA sample-rate and period-size ranges are direct `snd_pcm_hw_params` ranges;
  they may still be broad for virtual devices such as PulseAudio/ALSA plugins.
- ALSA output stream uses a worker thread and `snd_pcm_writei`; it is not yet a
  low-latency real-time callback integration.
- CoreAudio, WASAPI, JACK, and PulseAudio are extension stubs only.
- Device metadata is much smaller than CPAL's `DeviceDescription`.
- Stream timestamps are represented, but backend-specific latency correction is
  not implemented.

Validation performed:

- `zig build` passes with Zig 0.16.0.
- `zig build test` passes.
- `./zig-out/bin/list_hosts_devices` enumerates ALSA PCM hints and the null
  fallback on the local Linux environment.
- `./zig-out/bin/print_stream_configs` prints ALSA-probed output config ranges
  for the default output device, including period-size frame ranges.
- `./zig-out/bin/open_output_stream` successfully opens a silent ALSA output
  stream on the local default device.
- `./zig-out/bin/sine_wave` is built but was not run automatically because it
  produces audible output.

Runtime fixes found during smoke testing:

- ALSA hint values are nullable C pointers, not Zig optionals; hint parsing now
  checks for null before converting to slices.
- Backend device ownership now moves into the public `DeviceList` exactly once.
  The first version deinitialized moved device strings too early.
- ALSA device IDs are stored as sentinel-terminated slices before passing them
  to `snd_pcm_open`.
- ALSA output config probing replaced the initial fixed placeholder ranges.
  The local default device reports `f32` and `i16` interleaved playback support.

Differences from Rust CPAL:

- `Host`, `Device`, and `Stream` are Zig tagged unions instead of Rust enums
  generated through macros.
- The Zig API separates `buildOutputStreamF32` from future typed/comptime stream
  builders.
- Callers explicitly deinitialize devices, device lists, hosts, and streams that
  own memory or native handles.
- Unsupported backends are present as named extension points rather than hidden
  behind feature flags in this first milestone.
