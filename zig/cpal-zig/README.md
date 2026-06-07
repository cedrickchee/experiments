# cpal-zig

An idiomatic Zig audio I/O library inspired by RustAudio CPAL.

This is not a line-by-line translation. The public API keeps CPAL's core ideas:
hosts, devices, stream configs, sample formats, typed errors, and callback-driven
input/output streams. The first implementation target is ALSA on Linux.

## Status

- ALSA host boundary: initial implementation
- ALSA device enumeration: initial PCM hint enumeration
- ALSA output stream: initial `f32` callback stream through `snd_pcm_writei`
- Input streams: not implemented yet
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
```
