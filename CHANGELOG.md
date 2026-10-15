# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2026-10-16

The version is now the same everywhere. The `0.0.1` release tag carried
`keydeck_0.2.0_amd64.deb` and `keydeck_0.2.0.apk`, while `desktop/pubspec.yaml`
and `mobile/pubspec.yaml` said `0.1.0`. Both pubspecs now say `0.2.1`, the tag is
`0.2.1`, and the desktop packages are named `0.2.1`.

### Added
- Linux arm64 and Windows arm64 builds of the desktop host, next to the x64 ones.
  Releases carry `keydeck_<version>_amd64.deb`, `keydeck_<version>_arm64.deb`,
  `KeyDeck-<version>-linux-x64.tar.gz`, `KeyDeck-<version>-linux-arm64.tar.gz`,
  `KeyDeck-<version>-windows-x64.zip` and `KeyDeck-<version>-windows-arm64.zip`.
  Every package is built, tested and started on a runner of its own
  architecture.
- Tarball and Windows zip packages (x64 and arm64) of the desktop host.
- Releases are completed by CI: publishing a release attaches the desktop
  packages, leaving alone any file name already on the release. The Android
  APK is still attached by hand.

### Changed
- `jni` is updated to 1.0.3 in the desktop app, which compiles on Linux arm64.
- The phone app (`mobile/`) is unchanged.

## [0.0.1] - 2026-07-13

- Initial debug release: the phone pad (Android) and the desktop host for
  Ubuntu, shipped as `keydeck_0.2.0.apk` and `keydeck_0.2.0_amd64.deb`.
