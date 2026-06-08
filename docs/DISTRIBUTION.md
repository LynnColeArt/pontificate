# Linux Distribution

Pontificate is Linux-first. Packaging should make the editor easy to install without hiding native media, GPU, font, and filesystem realities from users.

No installable release package is produced by the current foundation mission. The repository can be built locally with Zig, CMake, and Qt 5, but Flatpak, Snap, distro packages, and portable release artifacts remain future packaging work.

## Targets

- Flatpak for mainstream desktop distribution and sandboxed installs.
- Snap for users and distributions where Snap is the easiest supported path.
- Direct executable or portable tarball for users who want a simple download without a store.
- Distro packages later where maintainers or community contributors can support them well.

## Future Packaging Requirements

- predictable access to project files, media folders, cache folders, and local fonts
- GPU acceleration support where available, with a clean software fallback
- FFmpeg/GStreamer codec availability that is explicit and diagnosable
- local Whisper model storage and cache controls
- font discovery through fontconfig plus app-managed font installation for project portability
- crash logs and autosave recovery data stored somewhere users can actually find

## Release Shape

Future packaging missions should prioritize:

- a signed direct build for quick testing
- a Flatpak manifest once media and filesystem permissions are clear
- a Snap package after the direct build and Flatpak have settled

The current build validation is local only:

```sh
zig build test
zig build run
cmake -S . -B build
cmake --build build
```

Actual packaging work should be tested with real edit projects, not just app launch smoke tests. Video editors fail at the edges: filesystem permissions, codec discovery, GPU drivers, font rendering, render-cache paths, and export destinations.
