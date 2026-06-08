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
- The public API exposes both explicit typed stream builders and Zig comptime
  generic builders that map sample types such as `f32` or `f64` to supported
  sample formats at compile time.
- The first stream formats wired through ALSA are `f32`, `i8`, `u8`, `i16`,
  `u16`, `i24`, `u24`, `i32`, `u32`, and `f64` interleaved audio. Zig 0.16
  stores `i24`/`u24` callback elements as 4-byte-stride values, so those map to
  ALSA's 24-bit-in-32-bit `SND_PCM_FORMAT_S24_LE`/`SND_PCM_FORMAT_U24_LE`
  formats rather than packed 3-byte samples. Additional sample formats are
  modeled in the public API but intentionally stay unbuildable until the
  backend has exact native mappings or explicit conversion code.

Current ALSA behavior:

- ALSA output and input stream configuration enumeration probe
  `snd_pcm_hw_params` for interleaved playback/capture support and report
  `f32`/`i8`/`u8`/`i16`/`u16`/`i24`/`u24`/`i32`/`u32`/`f64` ranges only when
  ALSA accepts those formats.
- Rich capability queries expose the real ALSA channel min/max range, sample
  rate range, period-size range, and total buffer-size range for buildable
  `f32`, `i8`, `u8`, `i16`, `u16`, `i24`, `u24`, `i32`, `u32`, and `f64`
  formats. `ChannelRange` also provides
  allocation-free preferred channel candidates for common mono/stereo/surround
  counts within the probed range. The older supported-config API remains
  available and still
  collapses channels to a representative count for compatibility.
- Default output and input devices are represented by the ALSA `default` PCM.
- Streams open ALSA PCMs with `SND_PCM_NONBLOCK`, wait through ALSA poll
  descriptors, and then use `snd_pcm_writei` for output or `snd_pcm_readi` for
  input. Stream setup now uses explicit `snd_pcm_hw_params` and
  `snd_pcm_sw_params` instead of `snd_pcm_set_params`, so the backend can
  negotiate access, format, channels, sample rate, callback period, total buffer
  size, `avail_min`, and playback start threshold directly.
- `f32`, `i8`, `u8`, `i16`, `u16`, `i24`, `u24`, `i32`, `u32`, and `f64` typed stream
  builders are implemented for playback and capture. `i8`/`u8` map directly to
  `SND_PCM_FORMAT_S8`/`SND_PCM_FORMAT_U8`; unsigned 8-bit silence is midpoint
  `128`. `u16` maps directly to `SND_PCM_FORMAT_U16_LE`; unsigned 16-bit
  silence is midpoint `32768`; `i24`/`u24` map to ALSA's 24-bit-in-32-bit
  little-endian formats with unsigned 24-bit midpoint silence `0x800000`;
  `u32` maps directly to `SND_PCM_FORMAT_U32_LE`
  with midpoint silence `0x80000000`; `f64` maps directly to
  `SND_PCM_FORMAT_FLOAT64_LE`.
- Public config negotiation helpers can choose a supported format, channel
  count, sample rate, requested/default period size, and requested/default total
  buffer size from rich capabilities while preserving optional channel-range and
  total-buffer range metadata on supported configs. `StreamConfig.total_buffer_size`
  is optional and defaults to backend policy, so older callers that only set
  `buffer_size` remain source-compatible. `negotiateSharedStreamCapability()`
  can also choose one format/channel/rate/buffer request supported by both an
  input and output capability set, which is useful for duplex examples that
  should not resample or convert.
- ALSA default input/output config selection now follows the same shared sample
  format preference order as public negotiation (`f32`, `i16`, `i32`, then
  other direct PCM formats including `i24`/`u24`) instead of falling back to raw
  probe order when `f32` is absent.
- Host device snapshots, a reusable snapshot tracker, bounded polling monitor,
  ALSA control-event wakeups, metadata fingerprints, and snapshot diffs are
  available as a lightweight hotplug foundation. They compare refreshed ALSA
  hint plus physical-card PCM snapshots and report added, removed,
  metadata-changed, and
  availability-changed devices. Changed entries include both the current item
  and previous metadata/availability so applications can inspect what changed.
  `DeviceSnapshotChange` also exposes helper predicates for availability, name,
  description, direction, and aggregate fingerprint changes. Snapshot diffing
  uses one-to-one matching and prefers same-direction matches when ALSA exposes
  separate input/output entries with the same PCM id, avoiding false
  direction-change reports for duplicated ids such as `default`.
  `DeviceSnapshotEntry.sameEndpoint()` is available for callers that need the
  stricter host/id/direction identity used for directional endpoints, while
  `sameIdentity()` remains host/id-only for stable backend device identity.
- Snapshot monitors use native host device-change waits when available and use
  bounded sleeping only for hosts without native signal support, so ALSA control
  polling timeouts are not followed by a second redundant sleep.
- Public `DeviceInfo` includes host, stable id, display name, optional
  description, direction, and a derived metadata fingerprint. The newer
  `Device.description()` API returns a CPAL-like structured
  `DeviceDescription` with name, stable id/address, driver, device type,
  interface type, direction, support helpers, extended backend text, and a
  fingerprint. ALSA preserves PCM hint `NAME` as the id/name and `DESC` as
  optional description/extended text instead of collapsing them into one string.
  Enumeration also probes physical cards through `snd_ctl_*` and
  `snd_pcm_info_*`, adding deduped `hw:CARD=...,DEV=...` and
  `plughw:CARD=...,DEV=...` aliases with derived playback/capture direction and
  ALSA-style physical-card descriptions. ALSA hint enumeration is now
  best-effort: non-allocation failures from `snd_device_name_hint` no longer
  abort `Host.devices()` before physical-card probing or the synthetic default
  fallback can run. Hint strings, control handles, card-info structs, and
  per-direction PCM-info structs are scoped to each hint/card/device during
  enumeration so large ALSA configurations do not retain those native resources
  until the whole enumeration call exits.
- `Device.isAvailable()` probes whether a backend device still appears present.
  ALSA opens the relevant PCM direction in nonblocking mode and treats
  unavailable or invalidated errors as disappearance while leaving temporary busy
  states as present. Declared output-only and input-only devices probe only that
  direction, declared duplex devices require both playback and capture to open,
  and unknown-direction devices remain available if either side opens.
  Availability and capability probes suppress expected ALSA library error logs
  and skip known noisy external plugins such as ALSA `jack` and `oss`; actual
  stream opens remain unsuppressed so real application failures are visible.
- Stream callbacks carry callback and playback/capture timestamps. ALSA
  callbacks use monotonic callback instants, estimate output playback time from
  `snd_pcm_delay`, and estimate input capture time from the delivered buffer
  duration plus remaining positive capture delay. Stream setup now requests ALSA
  timestamping with `MONOTONIC_RAW` first and falls back to `MONOTONIC`,
  matching CPAL's preference for the raw monotonic clock when ALSA accepts it.
  Diagnostics only treat `snd_pcm_htimestamp` as measured when the active PCM
  timestamp type is monotonic or monotonic-raw and ALSA returns a non-zero
  timestamp; otherwise diagnostics fall back to an estimated monotonic instant.
  The zero-timestamp guard matches CPAL's handling for ALSA plugins that expose
  timestamp APIs but do not provide real hardware timestamps.
- Stream error callbacks are supported. ALSA `EPIPE` is surfaced as
  `AudioError.Xrun`; busy/EAGAIN and zero-frame read/write states quietly back
  off without firing stream error callbacks; unavailable devices and fatal
  stream errors are mapped to `DeviceNotAvailable` or `StreamInvalidated`, and
  failed recovery stops the worker thread. ALSA poll error events are now
  interpreted with the current PCM state: `SND_PCM_STATE_XRUN` is recovered via
  `-EPIPE`, `SND_PCM_STATE_SUSPENDED` is surfaced as `AudioError.StreamSuspended`
  and recovered via `-ESTRPIPE`, disconnected poll errors become
  `DeviceNotAvailable`, and unknown fatal poll errors still become stream
  invalidation. Diagnostics-observed terminal PCM states also
  trigger the stream error callback once per observed terminal episode, so
  polling applications can receive `Xrun`, `StreamSuspended`, or
  `DeviceNotAvailable`/`StreamInvalidated` even when the worker did not see the
  transition first.
- `Stream.bufferSize()` returns the ALSA period size when it can be queried.
- For default ALSA stream configs, the backend now follows CPAL's two-pass
  period/buffer policy: first commit base hardware params so ALSA chooses a
  period, then reinitialize params and request a two-period total buffer around
  that chosen period. Fixed
  `StreamConfig.buffer_size` requests are treated as callback period requests,
  and fixed `StreamConfig.total_buffer_size` requests are applied to the ALSA
  ring buffer when supplied. If ALSA's nearest-parameter APIs round a fixed
  period or total-buffer request, stream creation now rejects the config as
  `UnsupportedConfig` instead of silently opening a different fixed size. The
  check is performed again after `snd_pcm_hw_params` commits, and stream setup
  also reads back committed access, format, channels, and sample rate. Any
  mismatch becomes `UnsupportedConfig`, and failure to query committed
  parameters is propagated instead of silently skipping verification.
- `Stream.diagnostics()` reports an ALSA timestamp, `snd_pcm_avail`,
  `snd_pcm_delay`, `snd_pcm_status`, total buffer and period frames from
  `snd_pcm_get_params`, derived frame-duration estimates in nanoseconds, a
  direct non-negative latency duration derived from ALSA delay when available,
  and separate status fields for timestamp quality and latency measurement
  availability.
  Measured timestamps are guarded by ALSA software-parameter timestamp mode/type
  checks so wall-clock `GETTIMEOFDAY` timestamps are not exposed as stream
  monotonic instants. Latency status is measured when ALSA delay or availability
  data is available, even if timestamp status falls back to estimated. It also
  reports stream run status, backend PCM state,
  worker scheduling status,
  callback count, stream error count, xrun count, successful recovery count,
  ALSA available-max/overrange status counters, expected callback interval,
  last callback interval, last callback interval drift versus the requested
  callback period, plus peak callback interval and peak absolute callback drift
  since the latest `play()`.
  Diagnostics also
  synchronize terminal ALSA backend states into the public run status:
  `xrun`, `suspended`, and `disconnected` become `xrun`, `stream_suspended`,
  and `device_not_available`. Diagnostics also reconcile later non-terminal PCM
  states back to `running` or `stopped` based on the stream's actual running
  flag, so a recovered/prepared/running ALSA handle does not keep reporting a
  stale terminal status. Failed ALSA diagnostics calls are now folded back into
  the same status/error observation path: transient `EAGAIN`/`EINTR` conditions
  do not surface as stream errors, while diagnostic-time XRUN, suspend, and
  invalidation returns update counters/status and use the same de-duplicated
  stream-error callback latch as worker-observed backend transitions.
- `play()` prepares the ALSA PCM before starting the worker thread, and output
  streams now handle short `snd_pcm_writei` results by continuing until the
  requested period has been written or an error occurs.
- `pause()` stops the worker and drops the PCM immediately. `drain()` stops the
  worker and drains output streams with `snd_pcm_drain`; because ALSA PCMs are
  opened nonblocking, drain now waits through ALSA poll descriptors and retries
  `-EAGAIN` instead of surfacing a spurious busy error while buffered playback
  drains. Capture and ambiguous directions use `snd_pcm_drop`. Cleanup paths do
  not overwrite terminal run statuses such as `xrun`, `stream_suspended`, or
  `stream_invalidated` with `stopped`.
- `Stream.isRunning()` exposes stream running state, while `Stream.status()` and
  diagnostics expose richer stopped/running/terminal-error state for application
  invalidation handling. ALSA joins a finished worker before restart, clears
  `running` when any worker exits, and reports allocation failures through the
  stream error callback instead of silently leaving ambiguous state.
- ALSA stream workers attempt best-effort `SCHED_FIFO` promotion only for
  CPAL-safe PCM types (`hw`, simple linear/ALaw/MuLaw/ADPCM/float conversion,
  and IEC958). Plugin/server-backed types such as null, ioplug, extplug, hooks,
  softvol, plug, rate, route, and copy are reported as scheduling
  `unsupported` to avoid priority inversions or spinning realtime threads.
  Diagnostics expose whether scheduling was applied, denied by permissions,
  unsupported, or failed.
- Input stream workers accumulate short `snd_pcm_readi` results until the
  requested callback period is full. Partial capture buffers are reset after
  read errors or recoverable busy states.
- ALSA callback worker buffers now use a shared guarded sample-count helper.
  Pathological period/channel products that overflow `usize` stop the worker
  with `ResourceExhausted`, while allocation failures still report
  `OutOfMemory`, instead of relying on unchecked `frames * channels`
  arithmetic in each sample-format loop.
- ALSA input delivery and output write loops now reuse the same guarded
  frame-to-sample arithmetic for read offsets, callback slices, and short-write
  offsets, so pathological channel/period combinations terminate through the
  stream error path instead of panicking in worker-thread arithmetic.

Unsupported or incomplete:

Summary of remaining real CPAL-grade ALSA gaps:

- Virtual/plugin PCM quirks can still make probed ranges broader than what a
  direct hardware device would expose.
- Worker-thread scheduling is poll-driven and best-effort realtime, not a fully
  tuned low-latency callback integration.
- Packed 3-byte 24-bit formats, signed/unsigned 64-bit integer PCM, and DSD are
  not implemented.
- Shared duplex negotiation does not perform automatic resampling, channel
  remixing, or sample-format conversion.
- Diagnostics expose timestamp/latency status and drift observations, but do not
  perform deeper latency correction or active drift compensation.
- Hotplug support still falls back to polling for virtual/plugin PCMs and needs
  broader device-specific validation.
- Live hardware unplug/replug behavior is not fully validated across real
  devices.
- Manufacturer/model metadata is incomplete for many ALSA endpoints.
- The compatibility config-range API still has a representative `channels`
  field; rich capabilities are preferred for full channel-range metadata.
- Broader real-device coverage is still needed for direct `hw:`, USB,
  capture-only/playback-only, suspend/resume, and ALSA control hotplug events.

- The compatibility `SupportedStreamConfigRange` API now preserves optional
  channel ranges and honors requested channel counts inside that range, while
  still exposing `channels` as a representative count for older callers. New
  code should still prefer rich capability queries when preferred channel
  candidates or direction metadata matter.
- ALSA sample-rate and period-size ranges are direct `snd_pcm_hw_params` ranges;
  they may still be broad for virtual devices such as PulseAudio/ALSA plugins.
  Stream opening now applies latency-oriented default period/total-buffer
  targets and rejects committed access/format/channel/rate/period/buffer
  mismatches. Broad virtual-device ranges may still accept configs that a plugin
  later services through conversion.
- ALSA streams still use ordinary worker threads. They now attempt best-effort
  real-time priority promotion, but this remains permission-dependent and is not
  yet equivalent to a fully tuned low-latency callback integration.
- The input-output feedback example now negotiates one shared f32 config from
  the default input and output devices' rich capabilities instead of choosing
  output first and force-copying its channel count/sample rate into input.
  Automatic resampling, channel remixing, and sample-format conversion remain
  application-level future work.
- `f32`, `i8`, `u8`, `i16`, `u16`, `i24`, `u24`, `i32`, `u32`, and `f64`
  stream creation are implemented for ALSA's interleaved native formats.
  Packed 3-byte 24-bit ALSA formats still need explicit conversion/wrapper
  support, local ALSA headers do not expose direct signed/unsigned 64-bit
  integer PCM constants, and DSD formats are not implemented.
- CoreAudio, WASAPI, JACK, and PulseAudio are extension stubs only.
- Device metadata now has a CPAL-like structured `DeviceDescription` surface and
  carries ALSA description strings plus physical-card descriptions for
  `hw:`/`plughw:` aliases. ALSA still does not expose or synthesize rich
  manufacturer/model fields for every endpoint.
- Latency diagnostics now include frame-to-duration estimates, ALSA status
  counters, callback playback/capture timestamp estimates, and callback
  cadence/drift observations plus peak callback interval/drift counters and
  ALSA PCM state reporting. The public diagnostics surface exposes separate
  `timestamp_status` and `latency_status` fields, keeps signed
  `delay_duration_ns` for backend detail, and adds optional unsigned
  `latency_duration_ns` for applications that want a direct latency estimate
  without interpreting negative delay values. Deeper backend-specific latency
  correction and active drift compensation are not implemented.
- Hotplug snapshot refresh/diff/tracking and bounded monitors exist. On ALSA
  hardware-card systems the monitor subscribes to `snd_ctl` control events and
  uses those poll descriptors as an early wakeup before refreshing PCM hints.
  ALSA control-event waits now report a signal only for actionable `POLLIN`,
  `POLLERR`, `POLLHUP`, or `POLLNVAL` revents, drain pending
  `snd_ctl_read` events from the nonblocking control handle before returning a
  signal, and timeout without a signal does not add an extra fallback sleep.
  If native signal support was detected but no control subscriptions or poll
  descriptors can be collected for a particular wait, ALSA now honors the
  requested wait interval with a fallback sleep instead of letting the generic
  monitor spin until timeout. The
  monitor still falls back to bounded polling when control devices are
  unavailable or virtual/plugin PCMs do not produce card-level events.
  Device-specific quirks and advanced plugin behavior remain incomplete.
- Device invalidation propagation is improved for fatal ALSA I/O and poll
  events. `Device.isAvailable()` can probe stale handles, metadata fingerprints
  let applications compare refreshed snapshots cheaply, snapshot diffs now
  include present-but-unopenable availability changes, and streams now expose a
  queryable terminal run status. Poll-level xruns and suspend states are
  recovered before declaring invalidation, with suspend events distinguishable
  as `StreamRunStatus.stream_suspended`. ALSA default input/output device
  lookup now follows CPAL's optional default-device shape more closely by
  returning `null` when the directional `default` PCM is absent or invalidated
  while still treating busy or permission-denied defaults as present. Live
  hardware-disconnect validation remains incomplete.
- Deeper latency correction/drift handling remains future work.

Validation performed:

- `zig build` passes with Zig 0.16.0.
- `zig build test` passes.
- `./zig-out/bin/list_hosts_devices` enumerates ALSA PCM hints and the null
  fallback on the local Linux environment, including ALSA description metadata
  such as PulseAudio/JACK/plugin descriptions and quiet availability status for
  each device. Latest local run reported 38 ALSA hint devices plus two null
  backend devices, with duplex entries such as `default`, `pulse`,
  `hw:CARD=PCH,DEV=0`, `plughw:CARD=PCH,DEV=0`, `sysdefault:CARD=PCH`,
  `front:CARD=PCH,DEV=0`, and `usbstream:CARD=PCH` available only when both
  playback and capture probes succeeded. Known noisy `jack` and `oss` entries
  remained unavailable without ALSA/JACK stderr noise.
- `./zig-out/bin/print_stream_configs` prints ALSA-probed output and input
  config ranges for the default devices, including period-size and total-buffer
  frame ranges. Latest local run reported default output/input `f32` and `i32`
  period `1-349526` with total buffer `3-1048576`, `u8` period `4-1398102`
  with total buffer `12-4194304`, and `i16` period `2-699051` with total buffer
  `6-2097152`.
- `./zig-out/bin/open_output_stream` successfully opens a silent ALSA output
  stream on the local default device.
- `./zig-out/bin/open_fixed_buffer_stream` successfully opens a silent local
  ALSA `f32` output stream with explicit fixed period and total-buffer requests.
  Latest local run requested 480 period frames and 1920 total buffer frames, and
  diagnostics reported exactly `period=480` and `total_buffer=1920`.
- `./zig-out/bin/deinit_running_stream` successfully starts a silent local ALSA
  `f32` output stream, verifies that it reaches the running state, and then
  deinitializes it without an explicit pause first. Latest local run reported
  clean deinitialization on the default ALSA output device.
- `./zig-out/bin/stream_lifecycle` exercises ALSA output `play`, `pause`,
  restart, nonblocking `drain`, stopped/running status checks, and input-stream
  deinitialization while running. Latest local run on the default ALSA devices
  reported `first_output_calls=16`, `resumed_output_calls=33`,
  `input_deinit_running=true`, and zero callback errors.
- `./zig-out/bin/record_input` successfully opens a local ALSA input stream and
  records callback meter data for two seconds. Latest local run used 2 channels
  at 48 kHz with a 1200-frame buffer and reported zero callback errors.
- `./zig-out/bin/open_f32_streams` successfully opens local ALSA `f32` playback
  and capture streams using one negotiated channel count and sample rate across
  the default devices. Latest local run used 2 channels at 48 kHz and reported
  `output_calls=22`, `input_calls=18`, `input_samples=18432`, and zero callback
  errors.
- `./zig-out/bin/open_i8_streams` is built as a negotiated-duplex smoke for
  ALSA signed 8-bit streams. On the current local default devices the latest
  local run exited cleanly with "Default output device does not support
  negotiated i8", matching the probed capability output.
- `./zig-out/bin/open_i16_streams` successfully opens local ALSA `i16` playback
  and capture streams. Latest local run used 2 channels at 48 kHz and reported
  `output_calls=12`, `input_calls=9`, `input_samples=18432`, and zero callback
  errors.
- `./zig-out/bin/open_u16_streams` builds and negotiates against the local
  default ALSA devices. Latest local run exited cleanly with "Default output
  device does not support negotiated u16", matching the probed rich capability
  output.
- `./zig-out/bin/open_i24_streams` is built as a negotiated-duplex smoke for
  ALSA 24-bit-in-32-bit signed streams. Latest local run used 2 channels at
  48 kHz and reported `output_calls=22`, `input_calls=18`,
  `input_samples=18432`, and zero callback errors.
- `./zig-out/bin/open_u24_streams` is built as a negotiated-duplex smoke for
  ALSA 24-bit-in-32-bit unsigned streams. On the current local default devices
  the latest local run exited cleanly with "Default output device does not
  support negotiated u24", matching the probed capability output.
- `./zig-out/bin/open_u8_streams` successfully opens local ALSA `u8` playback
  and capture streams. Latest local run used 2 channels at 48 kHz and reported
  `output_calls=26`, `input_calls=21`, `input_samples=20160`, and zero callback
  errors.
- `./zig-out/bin/open_i32_streams` successfully opens local ALSA `i32` playback
  and capture streams. Latest local run used 2 channels at 48 kHz and reported
  `output_calls=22`, `input_calls=18`, `input_samples=18432`, and zero callback
  errors.
- `./zig-out/bin/open_u32_streams` builds and negotiates against the local
  default ALSA devices. Latest local run exited cleanly with "Default output
  device does not support negotiated u32", matching the probed rich capability
  output.
- `./zig-out/bin/open_f64_streams` is built as a negotiated-duplex smoke for
  ALSA 64-bit float streams. On the current local default devices the latest
  local run exited cleanly with "Default output device does not support
  negotiated f64", matching the probed capability output.
- `./zig-out/bin/open_output_stream`, `./zig-out/bin/open_i16_streams`, and
  `./zig-out/bin/open_i32_streams` were rerun after the ALSA lifecycle hardening
  changes and passed locally.
- `./zig-out/bin/list_hosts_devices` passed after hybrid ALSA enumeration was
  added. The current local environment exposes no ALSA control cards, so the
  physical `hw:`/`plughw:` path is covered by compile-time C binding checks and
  hardware-independent helper tests but does not add local physical aliases in
  this environment; the smoke still reports the 9 ALSA hint devices plus the
  null fallback host. The example now also prints structured device-description
  metadata including driver, device type, interface type, and address.
- ALSA unit tests cover the hint-enumeration fallback policy: allocation and
  resource-exhaustion errors remain fatal, while backend, permission, or
  unavailable hint errors allow physical/default enumeration to continue.
- Public API tests cover `Device.description()` on the null backend, including
  CPAL-like support helpers and metadata fingerprint generation. ALSA unit tests
  cover physical/virtual alias metadata classification.
- `./zig-out/bin/print_rich_capabilities` reports local default ALSA output and
  input capabilities. The local default devices report `f32`/`u8`/`i16`/`i24`/`i32`,
  1-32 channels, preferred channel candidates
  `2/1/4/6/8/10/12/16/24/32`, 1-384000 Hz, ALSA period-size ranges, and total
  ALSA buffer-size ranges. Latest local capability run reported `f32`/`i24`/`i32`
  period `1-349526` and buffer `3-1048576`, `u8` period `4-1398102` and buffer
  `12-4194304`, and `i16` period `2-699051` and buffer `6-2097152`.
  `i8`/`u16`/`u24`/`u32` and `f64` are omitted because ALSA does not accept
  them on this local default PCM, matching ALSA's probed result instead of
  exposing unbuildable formats.
- `./zig-out/bin/print_stream_configs` now shows compatibility config ranges
  with preserved channel ranges. Latest local run reported both default ALSA
  directions as `channels=1-32 representative=2` for `f32`, `u8`, `i16`,
  `i24`, and `i32`, matching the richer capability probe while keeping the
  representative `channels` field available.
- `./zig-out/bin/stream_diagnostics` opens silent output and read-only input
  streams and reports measured ALSA diagnostics from `snd_pcm_htimestamp`,
  `snd_pcm_avail`, `snd_pcm_delay`, and `snd_pcm_status`, including derived
  availability/delay durations, separate timestamp and latency status,
  available-max frames, capture overrange frames, run status, ALSA buffer/period
  frames, backend PCM state, stream error count, xrun count, successful recovery
  count, expected callback interval, last callback interval/drift, and peak
  callback interval/absolute drift. The
  example fails if callbacks do not run, if stream errors or xruns are observed,
  if period/total-buffer sizes are missing, or if timestamp or latency status is
  unavailable.
  Latest local output run
  reported `run=running`, `backend=running`, `timestamp=measured`,
  `latency=measured`, buffer size 1536 frames, period size 512 frames,
  expected callback interval `10666666 ns`, delay values around 32.7-40.9 ms,
  matching `latency_duration_ns`, `avail_max=1536`,
  `overrange=0`, `errors=0`, `xruns=0`, `recoveries=0`, and an explicit worker
  scheduling status. On the local PulseAudio-backed default PCM this now reports
  `scheduling=unsupported` because the PCM type is not realtime-eligible; on
  direct hardware PCMs the worker still attempts best-effort `SCHED_FIFO`
  promotion and reports permission or platform failures explicitly. After
  adding peak jitter diagnostics, the latest local
  output run reported peak callback intervals around 13.4 ms and peak absolute
  callback drift around 10.6 ms during startup. Latest local input run reported
  `timestamp=measured`, `latency=measured`, buffer size 1536 frames, period size
  512 frames, expected callback interval `10666666 ns`, available frames ranging
  roughly 208-472, direct latency values around 7.7-15.9 ms, `avail_max=736`,
  `overrange=0`, `errors=0`, `xruns=0`, `recoveries=0`, peak callback intervals
  around 15.4 ms, and peak absolute callback drift around 4.7 ms.
- `./zig-out/bin/hotplug_snapshot` creates a bounded monitor, reports whether
  native device-change signals are available, and prints the first observed
  snapshot diff, including changed-entry fingerprints and field-level change
  flags when changes are present. It also rehydrates one current snapshot
  endpoint through `Host.deviceById()` to smoke the
  stale-snapshot-to-fresh-device lookup path.
  Latest local run reported native device-change signal support as false in the
  current environment, 9 devices before refresh, a rehydrated `null` duplex
  endpoint with `available=true`, 9 devices after refresh, and zero changes.
- `./zig-out/bin/sine_wave` is built but was not run automatically because it
  produces audible output.
- `./zig-out/bin/input_output_feedback` is built but was not run automatically
  because it monitors live input to output and can create audible feedback.

Runtime fixes found during smoke testing:

- ALSA hint values are nullable C pointers, not Zig optionals; hint parsing now
  checks for null before converting to slices.
- ALSA device metadata now keeps PCM hint `NAME` as the stable id/display name
  and preserves `DESC` as optional public description metadata.
- Backend device ownership now moves into the public `DeviceList` exactly once.
  The first version deinitialized moved device strings too early.
- ALSA device IDs are stored as sentinel-terminated slices before passing them
  to `snd_pcm_open`.
- ALSA output config probing replaced the initial fixed placeholder ranges.
  The local default device reports `f32`, `u8`, `i16`, `i24`, and `i32` interleaved
  playback support.
- ALSA input config probing now uses the same hardware-parameter path for
  capture devices.
- ALSA `i16` stream creation uses `SND_PCM_FORMAT_S16_LE`; `u16` uses
  `SND_PCM_FORMAT_U16_LE`; `i32` uses `SND_PCM_FORMAT_S32_LE`; `f32` uses
  `SND_PCM_FORMAT_FLOAT_LE`.
- ALSA buildable-format probing and PCM opening now share one direct-format
  table, with unit tests proving
  `f32`/`i8`/`u8`/`i16`/`u16`/`i24`/`u24`/`i32`/`u32`/`f64` map to the same
  ALSA formats for probing and opening while packed 3-byte 24-bit, integer
  64-bit, and DSD formats stay unexposed until exact native mappings or
  explicit conversion support exists.
- The `open_f32_streams`, `open_i8_streams`, `open_u8_streams`,
  `open_i16_streams`, `open_u16_streams`, `open_i24_streams`,
  `open_u24_streams`, `open_i32_streams`, `open_u32_streams`, and
  `open_f64_streams` examples now
  share a generic negotiated-duplex smoke helper. The helper exercises the
  public `buildOutputStream(Sample, ...)` and `buildInputStream(Sample, ...)`
  APIs for each sample type, keeping probed formats, negotiated configs, typed
  builders, and example smokes aligned. These smokes now fail if the stream
  error callback runs or if either input/output callbacks do not fire.
- The input-output feedback example now uses shared rich-capability negotiation
  across the default input and output devices rather than force-copying output
  channel count and sample rate into the input stream.
- ALSA `play()` now resets the running flag if prepare or thread spawn fails,
  avoiding a stuck running state after startup errors.
- ALSA `play()` now joins any previously finished worker before restart, and
  worker exit always clears the public running state.
- ALSA stream workers now attempt `pthread_setschedparam(..., SCHED_FIFO, ...)`
  on startup and expose the result through diagnostics instead of failing stream
  startup when real-time priority is unavailable.
- ALSA stream PCMs now pass `SND_PCM_NONBLOCK` at `snd_pcm_open` time instead of
  opening blocking handles and switching them to nonblocking after hardware
  configuration.
- ALSA output streams now handle partial writes rather than treating any
  non-negative `snd_pcm_writei` return as a full period.
- Public `Stream.drain()` now gives callers an explicit output-drain lifecycle
  operation separate from immediate `pause()`/drop behavior.
- ALSA output `drain()` now handles nonblocking `snd_pcm_drain` returning
  `-EAGAIN` by polling for PCM progress and retrying. It also attempts ALSA
  recovery for drain-time xrun/suspend states before reporting failure.
- ALSA `pause()`, `drain()`, and deinit cleanup preserve terminal run statuses
  instead of replacing the last fatal/suspend/xrun state with `stopped`.
- ALSA diagnostics now clear stale terminal run statuses when ALSA has returned
  to a known non-terminal state, while preserving terminal status for
  disconnected/suspended/xrun and unknown/private backend states.
- ALSA input streams now accumulate partial reads to a full requested callback
  period before calling the input callback.
- ALSA callback buffer allocation is guarded against period/channel sample-count
  overflow for all buildable sample formats.
- ALSA streams now use `snd_pcm_poll_descriptors_count`,
  `snd_pcm_poll_descriptors`, `poll`, and
  `snd_pcm_poll_descriptors_revents` before read/write attempts to avoid
  aggressive busy loops around nonblocking PCM handles.
- ALSA diagnostics now map `snd_pcm_state()` to a public backend-state enum so
  applications can distinguish setup, prepared, running, xrun, draining, paused,
  suspended, and disconnected backend states alongside the higher-level run
  status. Terminal backend states now also refresh the public run status during
  diagnostics so polling applications can observe `xrun`, `stream_suspended`,
  or `stream_invalidated` even when the transition was not first observed by the
  worker loop. The same terminal-state observation path now emits the stream
  error callback with de-duplication, and the latch clears after ALSA recovery
  or after diagnostics sees a non-terminal PCM state.
- ALSA diagnostics now also record an XRUN when `snd_pcm_state()` reports the
  backend is already in XRUN, not only when a worker read/write call returns
  `EPIPE`. XRUN counting is de-duplicated with a latch that clears after ALSA
  recovery or after diagnostics sees the PCM return to a non-XRUN stream state.
- ALSA diagnostics now also read `snd_pcm_status` to report available-max frames
  and capture overrange frames, while still falling back to direct
  `snd_pcm_avail`/`snd_pcm_delay` calls if status is unavailable.
- ALSA diagnostics now read back committed software parameters with
  `snd_pcm_sw_params_current`, including `avail_min` and `start_threshold`, so
  callers can inspect the backend wakeup threshold and playback start threshold
  that ALSA actually accepted.
- ALSA software-parameter setup now mirrors CPAL's startup policy more closely:
  `avail_min` remains one callback period, playback `start_threshold` is two
  periods clamped to the committed total buffer size, and capture
  `start_threshold` is explicitly set to one frame.
- ALSA default total-buffer requests now use two periods instead of four,
  matching CPAL's `DEFAULT_PERIODS = 2` startup/buffering policy. Explicit fixed
  `StreamConfig.total_buffer_size` requests are still applied exactly and
  rejected if ALSA rounds them.
- ALSA default hardware-parameter setup now uses a CPAL-style second pass: fully
  default stream configs first let ALSA select the period for the format,
  channel count, and sample rate, then reapply the chosen period with a
  two-period total buffer. Explicit fixed period or total-buffer requests keep
  the one-pass exact-request path.
- ALSA PCM opens are now serialized through a backend mutex for both configured
  streams and probe opens, matching CPAL's guard for ALSA plugins and drivers
  that are not reentrant during `snd_pcm_open`.
- ALSA host, device, and stream objects now retain a process-global backend
  context. The first live ALSA object calls `snd_config_update`, and the last
  deinit calls `snd_config_update_free_global`. Devices and streams retain their
  own context references, so ALSA config remains alive even if an application
  drops a host before its devices or a device before its streams. The count
  transitions are serialized separately from PCM opens and covered by
  hardware-independent unit tests, matching CPAL's explicit ALSA config lifetime
  management more closely.
- ALSA output callback timestamps now keep the callback instant separate from
  the estimated playback instant by adding the current `snd_pcm_delay` frame
  duration. ALSA input callback timestamps now estimate the capture instant for
  the delivered buffer by subtracting the delivered buffer duration and any
  remaining positive capture delay from the callback instant. These estimates
  are still simpler than CPAL's most precise backend timestamp handling, but no
  longer collapse callback and audio timeline timestamps to the same value.
- ALSA stream I/O error classification now explicitly separates recoverable busy
  states from fatal invalidation/unavailable/permission/invalid-input states;
  unit tests guard that classification.
- ALSA stream workers treat poll error, hangup, and invalid-descriptor events as
  terminal stream errors. `POLLERR` still recovers XRUN and suspend states
  first, but `POLLHUP`, `POLLNVAL`, and timeout-observed
  `SND_PCM_STATE_DISCONNECTED` now follow CPAL's device-removal behavior and
  surface `DeviceNotAvailable` instead of collapsing every disconnect path into
  `StreamInvalidated`.
- ALSA diagnostics now report `SND_PCM_STATE_DISCONNECTED` as
  `DeviceNotAvailable` too, and callback error coalescing keeps
  `DeviceNotAvailable` separate from true `StreamInvalidated` failures.
- ALSA error mapping now distinguishes unavailable devices (`ENODEV`, `ENOENT`,
  `ENXIO`) from invalidated streams (`EIO`), and fatal errors stop the worker
  instead of repeatedly trying to recover. The mapper now follows CPAL's ALSA
  policy more closely for configuration errors as well: `EINVAL` is treated as
  `UnsupportedConfig`, `ENOSYS` as `UnsupportedOperation`, and both are terminal
  for live stream I/O rather than recoverable worker states. `snd_pcm_open`
  gets an additional CPAL-style pass that promotes open-time
  `UnsupportedConfig` to `UnsupportedOperation`, so wrong-direction PCM opens
  are reported as unsupported input/output operations while later hardware-param
  negotiation failures remain unsupported configs.
- ALSA device availability probing now checks whether the relevant playback or
  capture PCM can still be opened without treating temporary busy states as
  device removal. Duplex hints now require both playback and capture to open,
  while unknown-direction hints still accept either side. Expected ALSA open
  failures during availability and capability probing are quieted, and known
  noisy external plugin endpoints such as `jack` and `oss` are treated as
  unavailable without launching their backing clients. Stream creation still
  uses the normal ALSA error handler.
- Rich capability probing now keeps ALSA's channel min/max range instead of only
  the representative channel count used by the compatibility config API.
- Supported config ranges and negotiated supported configs now preserve ALSA's
  total-buffer range in addition to the period-size range, so applications can
  inspect both after negotiation without retaining the original rich capability
  slice.
- Device snapshot diffing and snapshot tracker refresh are tested without
  requiring real hardware changes, including availability-only changes for
  devices that remain enumerated but become unopenable. Tests now also cover
  change helper predicates for name, description, direction, availability, and
  aggregate metadata changes, host/id identity versus host/id/direction endpoint
  identity, plus duplicate same-id input/output entries so ALSA-style
  directional devices do not get conflated during hotplug diffs.
- ALSA snapshot identity now canonicalizes simple hardware PCM ids for matching
  and metadata fingerprints, so forms like `hw:0`, `hw:0,0`, `hw:CARD=0`, and
  `hw:CARD=0,DEV=0` are treated as the same hotplug endpoint without changing
  the backend-native id text returned by `Device.info()`.
- Device snapshots, trackers, and monitors now expose endpoint-aware lookup and
  availability helpers keyed by host, id, and direction. This avoids stale-device
  checks accidentally matching the wrong directional endpoint when ALSA exposes
  duplicated ids such as `default` input and output entries.
- `Host.deviceById()` now rehydrates a directional device from a backend id by
  enumerating the current host devices and moving out the matching endpoint.
  It uses the same canonical ALSA PCM id matching as snapshots, giving
  applications a CPAL-like path from a stale snapshot entry back to a fresh
  device handle without guessing between duplicated input/output ids.
- ALSA control-event revent filtering, empty nonblocking control-event queue
  handling, native-signal poll timeout rounding, and no-control-descriptor
  fallback wait policy are unit tested without requiring hardware changes.
- ALSA stream and control-event revent paths now treat `-EINTR` as a transient
  retry condition. Interrupted PCM readiness, read/write, and drain-progress
  revent checks keep the stream in the running state instead of surfacing a
  backend error, and interrupted control revent checks no longer synthesize a
  device-change signal.
- ALSA worker polling now mirrors CPAL's spurious-wakeup guard more closely.
  Poll timeouts re-check PCM state for missed XRUN, suspend, or disconnect
  transitions, and readiness events are followed by `snd_pcm_avail_delay`; the
  worker only invokes user callbacks when at least one full callback period is
  actually available.
- ALSA streams now create a nonblocking close-on-exec wakeup pipe and poll it
  alongside ALSA descriptors. `pause()`, `drain()`, and `deinit()` signal the
  pipe before joining the worker, so lifecycle shutdown no longer waits for the
  ALSA poll timeout to expire.
- ALSA capture streams now call `snd_pcm_start` after prepare and again after
  successful recovery, matching the CPAL worker expectation that capture must be
  explicitly started before period availability can advance.
- ALSA suspend recovery now attempts `snd_pcm_resume` for `ESTRPIPE` before
  falling back to `snd_pcm_recover`, matching CPAL's soft-resume path more
  closely. `EAGAIN` from resume is treated as a transient pending resume,
  `ENOSYS` falls back to prepare/recover, and other resume failures terminate
  through the mapped stream error path.
- ALSA read/write loops now distinguish zero-progress `EAGAIN` from
  partial-period `EAGAIN`. Zero-progress busy states remain transient, while
  `EAGAIN` after some frames have already transferred is treated as an XRUN and
  sent through the recovery path, matching CPAL's handling of incomplete period
  transfers.
- ALSA hosts now expose native device-change signal support by probing card
  control devices. Snapshot monitors use `snd_ctl_subscribe_events`,
  `snd_ctl_poll_descriptors`, and `snd_ctl_poll_descriptors_revents` to wake
  before the next bounded snapshot refresh when card-level events are available.
- The null backend now exposes separate input and output devices so input stream
  and `i8`/`u8`/`i16`/`u16`/`i32`/`u32`/`f64` stream tests can run without
  hardware.
- Public comptime generic stream builders are tested through the null backend,
  including sample-type-to-format mapping for `f32` and `f64`.
- Local smoke coverage now includes deinitializing an actively running ALSA
  output stream, exercising the worker-stop and PCM-close lifecycle path used by
  callers that drop streams without a prior `pause`.
- Local smoke coverage now also includes ALSA output pause/restart/drain status
  transitions and deinitializing an actively running ALSA input stream.

Differences from Rust CPAL:

- `Host`, `Device`, and `Stream` are Zig tagged unions instead of Rust enums
  generated through macros.
- The Zig API separates `buildOutputStreamF32`/`buildOutputStreamI16`/
  `buildOutputStreamU16`/`buildOutputStreamI32` from future typed/comptime
  stream builders.
- The Zig API has matching `buildInputStreamF32`/`buildInputStreamI16`/
  `buildInputStreamU16`/`buildInputStreamI32` rather than CPAL's generic typed
  builder surface.
- Callers explicitly deinitialize devices, device lists, hosts, and streams that
  own memory or native handles.
- Unsupported backends are present as named extension points rather than hidden
  behind feature flags in this first milestone.
