# cpal-zig

An idiomatic Zig audio I/O library inspired by RustAudio CPAL.

This is not a line-by-line translation. The public API keeps CPAL's core ideas:
hosts, devices, stream configs, sample formats, typed errors, and callback-driven
input/output streams. The first implementation target is ALSA on Linux.

## Status

- ALSA host boundary: implemented for Linux
- ALSA device enumeration: PCM hint enumeration with input/output/duplex labels
  plus ALSA description metadata
- ALSA config probing: interleaved `f32`, `i8`, `u8`, `i16`, `u16`, `i32`, `u32`, and `f64`
  playback/capture ranges when accepted by ALSA
- ALSA rich capability probing: channel min/max, preferred channel candidates,
  sample-rate ranges, period-size ranges, and total buffer-size ranges for
  buildable formats
- ALSA output streams: `f32`, `i8`, `u8`, `i16`, `u16`, `i32`, `u32`, and `f64` callback streams using ALSA poll descriptors plus `snd_pcm_writei`
- ALSA input streams: `f32`, `i8`, `u8`, `i16`, `u16`, `i32`, `u32`, and `f64` callback streams using ALSA poll descriptors plus `snd_pcm_readi`
- Config negotiation: helper APIs for choosing format, channel count, sample
  rate, callback period size, and total buffer size from probed ranges or rich
  capabilities while preserving total-buffer ranges on supported configs
- Hotplug foundation: host device snapshots, snapshot tracking, snapshot
  diffing with previous metadata and availability for changed devices, metadata
  fingerprints, ALSA control-event wakeups when available, and bounded polling
  fallback
- Device availability probes: `Device.isAvailable()` checks whether a backend
  device still appears present/openable for its declared direction
- Stream lifecycle: `play`, `pause`, `drain`, `isRunning`, `status`, `deinit`,
  buffer-size query, xrun recovery, stream error callbacks, and ALSA-backed
  timestamps
- Stream builders: explicit typed builders such as `buildOutputStreamF32` plus
  Zig comptime generic builders such as `buildOutputStream(f32, ...)`
- Device invalidation: unavailable/disconnected PCM errors map to
  `DeviceNotAvailable` or `StreamInvalidated` and stop stream workers cleanly;
  ALSA suspend events surface as `StreamSuspended` and use ALSA recovery before
  invalidation
- Stream diagnostics: timestamp status, total buffer and period frames,
  available/available-max frames, signed delay frames/durations, direct
  non-negative latency duration, capture overrange, callback cadence/drift,
  stream error/xrun/recovery counters, run status,
  backend PCM state, and worker scheduling status
- ALSA stream setup: explicit `snd_pcm_hw_params`/`snd_pcm_sw_params`
  negotiation with latency-oriented defaults and optional fixed total-buffer
  requests
- CoreAudio, WASAPI, JACK, PulseAudio: extension stubs

See `IMPLEMENTATION_LOG.md` for design notes and gaps.

## Build

```sh
zig build
zig build test
```

## Examples

```sh
zig build
./zig-out/bin/list_hosts_devices
./zig-out/bin/print_stream_configs
./zig-out/bin/open_output_stream
./zig-out/bin/open_fixed_buffer_stream
./zig-out/bin/deinit_running_stream
./zig-out/bin/stream_lifecycle
./zig-out/bin/sine_wave
./zig-out/bin/record_input
./zig-out/bin/input_output_feedback
./zig-out/bin/open_f32_streams
./zig-out/bin/open_u8_streams
./zig-out/bin/open_i16_streams
./zig-out/bin/open_u16_streams
./zig-out/bin/open_i32_streams
./zig-out/bin/open_u32_streams
./zig-out/bin/print_rich_capabilities
./zig-out/bin/hotplug_snapshot
./zig-out/bin/stream_diagnostics
```
