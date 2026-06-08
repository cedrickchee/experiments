# cpal-zig

An idiomatic Zig audio I/O library inspired by [RustAudio CPAL](https://github.com/RustAudio/cpal).

This is not a line-by-line translation. The public API keeps CPAL's core ideas:
hosts, devices, stream configs, sample formats, typed errors, and callback-driven
input/output streams. The first implementation target is ALSA on Linux.

## Status

- ALSA host boundary: implemented for Linux
- ALSA device enumeration: PCM hint enumeration for virtual/plugin devices plus
  physical card probing that adds `hw:CARD=...,DEV=...` and
  `plughw:CARD=...,DEV=...` aliases with input/output/duplex labels and ALSA
  description metadata; hint enumeration failures fall back to physical probing
  and the default PCM when possible
- Device metadata: simple `DeviceInfo` plus CPAL-like structured
  `DeviceDescription` fields for name, driver, device type, interface type,
  direction, address, and extended backend text where available
- ALSA config probing: interleaved `f32`, `i8`, `u8`, `i16`, `u16`, `i24`, `u24`, `i32`, `u32`, and `f64`
  playback/capture ranges when accepted by ALSA, including optional channel
  ranges on compatibility config ranges
- ALSA rich capability probing: channel min/max, preferred channel candidates,
  sample-rate ranges, period-size ranges, and total buffer-size ranges for
  buildable formats
- ALSA output streams: `f32`, `i8`, `u8`, `i16`, `u16`, `i24`, `u24`, `i32`, `u32`, and `f64` callback streams using ALSA poll descriptors plus `snd_pcm_writei`
- ALSA input streams: `f32`, `i8`, `u8`, `i16`, `u16`, `i24`, `u24`, `i32`, `u32`, and `f64` callback streams using ALSA poll descriptors plus `snd_pcm_readi`
- Config negotiation: helper APIs for choosing format, channel count, sample
  rate, callback period size, and total buffer size from probed ranges or rich
  capabilities while preserving channel and total-buffer ranges on supported
  configs; shared input/output negotiation can choose one format/channel/rate
  config supported by both devices
- Hotplug foundation: host device snapshots, snapshot tracking, snapshot
  diffing with previous metadata and availability for changed devices, metadata
  fingerprints, endpoint-aware availability lookup with canonical ALSA hardware
  PCM id matching, ALSA control-event wakeups when available, and bounded
  polling fallback
- Device lookup: `Host.deviceById()` rehydrates a directional device by backend
  id, using the same canonical ALSA hardware PCM id matching as snapshots
- Device availability probes: `Device.isAvailable()` checks whether a backend
  device still appears present/openable for its declared direction
- Stream lifecycle: `play`, `pause`, `drain`, `isRunning`, `status`, `deinit`,
  buffer-size query, xrun recovery, stream error callbacks, and ALSA-backed
  timestamps
- ALSA stream setup: post-commit verification of access, sample format,
  channel count, sample rate, period size, and total buffer size
- Stream builders: explicit typed builders such as `buildOutputStreamF32` plus
  Zig comptime generic builders such as `buildOutputStream(f32, ...)`
- Device invalidation: unavailable/disconnected PCM errors map to
  `DeviceNotAvailable` or `StreamInvalidated` and stop stream workers cleanly;
  ALSA suspend events surface as `StreamSuspended` and use ALSA recovery before
  invalidation
- Stream diagnostics: separate timestamp and latency status, total buffer and
  period frames, ALSA software thresholds, available/available-max frames,
  signed delay frames/durations, direct non-negative latency duration, capture
  overrange, expected callback interval, callback cadence/drift, peak callback
  interval and absolute drift observations, stream error/xrun/recovery counters,
  run status, backend PCM state, and worker scheduling status
- ALSA stream setup: explicit `snd_pcm_hw_params`/`snd_pcm_sw_params`
  negotiation with CPAL-style default two-pass period/buffer setup and optional
  fixed total-buffer requests
- CoreAudio, WASAPI, JACK, PulseAudio: extension stubs

## Remaining CPAL-grade ALSA gaps

The remaining real gaps are mostly "CPAL-grade robustness" gaps, not missing
basic ALSA functionality. The Codex `/goal` stays active because the ALSA
backend is functionally broad now, but not yet "battle-hardened CPAL-grade"
across hardware, plugins, timing, and disconnect behavior.

The ALSA backend is functional and broad, but these gaps are still real before
calling it CPAL-grade across hardware and plugin environments:

- Virtual/plugin PCM behavior: capability ranges come directly from
  `snd_pcm_hw_params`, so PulseAudio/ALSA plugins can report broad ranges and
  later service them through conversion or backend-specific quirks.
- Realtime behavior: streams use poll-driven worker threads with best-effort
  `SCHED_FIFO`, but this is permission- and PCM-type-dependent and not a fully
  tuned low-latency callback integration.
- Format edge cases: native interleaved
  `f32/i8/u8/i16/u16/i24/u24/i32/u32/f64` are implemented. Packed 3-byte
  24-bit conversion/wrappers, signed/unsigned 64-bit integer PCM, and DSD are
  not implemented.
- Duplex conversion: shared input/output negotiation exists, but automatic
  resampling, channel remixing, and sample-format conversion remain
  application-level work.
- Latency/drift correction: diagnostics expose timestamp and latency status,
  delay, availability, callback cadence, and drift observations, but deeper
  backend-specific latency correction and active drift compensation are not
  implemented.
- Hotplug limits: snapshot diffing, bounded monitoring, and ALSA control-event
  wakeups exist, but virtual/plugin PCMs may still only be detected by polling
  and device-specific quirks remain incomplete.
- Live invalidation validation: fatal I/O and poll errors map to
  `DeviceNotAvailable` or `StreamInvalidated`, but real hardware unplug/replug
  validation is still incomplete.
- Metadata completeness: `DeviceDescription` exposes available ALSA
  description, driver, type, interface, and address data, but manufacturer/model
  fields are not reliably exposed or synthesized for every endpoint.
- Compatibility API shape: `SupportedStreamConfigRange.channels` still exposes
  a representative channel count for older callers; rich capabilities should be
  preferred when channel ranges/candidates and direction metadata matter.
- Hardware matrix: current tests and local smokes do not replace broader real
  hardware coverage across direct `hw:` devices, USB cards, capture-only and
  playback-only devices, suspend/resume, unplug while streaming, and real ALSA
  control hotplug events.

See [IMPLEMENTATION_LOG.md](./IMPLEMENTATION_LOG.md) for design notes and gaps.

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
./zig-out/bin/open_i8_streams
./zig-out/bin/open_u8_streams
./zig-out/bin/open_i16_streams
./zig-out/bin/open_u16_streams
./zig-out/bin/open_i24_streams
./zig-out/bin/open_u24_streams
./zig-out/bin/open_i32_streams
./zig-out/bin/open_u32_streams
./zig-out/bin/open_f64_streams
./zig-out/bin/print_rich_capabilities
./zig-out/bin/hotplug_snapshot
./zig-out/bin/stream_diagnostics
```
