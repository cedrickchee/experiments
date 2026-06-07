# cpal-zig

An idiomatic Zig audio I/O library inspired by RustAudio CPAL.

This is not a line-by-line translation. The public API keeps CPAL's core ideas:
hosts, devices, stream configs, sample formats, typed errors, and callback-driven
input/output streams. The first implementation target is ALSA on Linux.

## Status

- ALSA host boundary: implemented for Linux
- ALSA device enumeration: PCM hint enumeration with input/output/duplex labels
- ALSA config probing: interleaved `f32` and `i16` playback/capture ranges
- ALSA output streams: `f32` and `i16` callback streams through worker-threaded `snd_pcm_writei`
- ALSA input streams: `f32` and `i16` callback streams through worker-threaded `snd_pcm_readi`
- Config negotiation: helper APIs for choosing format, channel count, sample
  rate, and buffer size from probed ranges
- Stream lifecycle: `play`, `pause`, `deinit`, buffer-size query, xrun recovery,
  stream error callbacks, and ALSA-backed timestamps
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
./zig-out/bin/sine_wave
./zig-out/bin/record_input
./zig-out/bin/input_output_feedback
./zig-out/bin/open_i16_streams
```
