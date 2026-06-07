# CPAL Audio Examples

This directory is a local sandbox for trying the examples from
[RustAudio/cpal](https://github.com/RustAudio/cpal) on Linux.

## Ubuntu Packages

CPAL requires ALSA development files on Linux, even when optional JACK,
PipeWire, or PulseAudio backends are enabled.

Required package:

```bash
sudo apt-get install libasound2-dev
```

Local status when this sandbox was created:

- `libasound2-dev` is installed.
- `libpulse-dev` is installed.
- `libjack-jackd2-dev` is not installed.
- `libpipewire-0.3-dev` is not installed.

Optional packages for later backend experiments:

```bash
sudo apt-get install libjack-jackd2-dev
sudo apt-get install libpipewire-0.3-dev
sudo apt-get install libpulse-dev
sudo apt-get install libdbus-1-dev
```

`libdbus-1-dev` is only needed for CPAL's `realtime-dbus` feature.

## Run Examples

Use the default ALSA backend first:

```bash
cargo run --example enumerate
cargo run --example beep
cargo run --example synth_tones
cargo run --example record_wav -- --help
```

`record_wav` writes `recorded.wav` in this directory when an input device is
available:

```bash
cargo run --example record_wav -- --duration 3
```

The feedback example opens both input and output devices for 10 seconds:

```bash
cargo run --example feedback
```

## Optional Backend Features

These require matching system development packages:

```bash
cargo run --example beep --features pulseaudio -- --pulseaudio
cargo run --example beep --features pipewire -- --pipewire
cargo run --example beep --features jack -- --jack
```

## Troubleshooting

If no default input or output device is available, check that your desktop
audio service is running:

```bash
pw-cli info
pulseaudio --check
```

If ALSA reports `DeviceBusy`, PipeWire or PulseAudio may already hold the ALSA
`default` device. Use the bridge device exposed by your audio server, or enable
CPAL's native `pipewire` or `pulseaudio` feature once the matching development
package is installed.

If `beep` prints `Unknown PCM default` or cannot find ALSA card `0`, the current
environment does not expose a default hardware output device. Run `enumerate` to
see available device IDs, then pass a usable output device with `--device`.

For systems without a desktop sound server, use direct ALSA devices such as
`hw:` or `plughw:` and ensure the user has audio device permissions.
