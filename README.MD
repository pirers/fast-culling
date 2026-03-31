# fast-culling

A Flutter desktop photo workflow app for Windows and macOS.  
It provides two core modules:

- **SFTP Transfer** — scan a local folder for JPEGs, filter by EXIF star rating, preview/select images, and upload to a remote directory via SFTP with safe `.partial`-upload + atomic-rename.
- **Burst Detection & Editor** — detect burst sequences from EXIF timestamps, edit frames (include/exclude, keyframes, fixed-aspect crops), and export to MP4 via bundled FFmpeg with interpolated crops.

---

## Prerequisites

| Tool | Minimum version | Notes |
|---|---|---|
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | **3.22.0** | Must include Dart ≥ 3.3.0 |
| **Windows** build target | Windows 10 (64-bit) | Visual Studio 2022 with "Desktop development with C++" workload |
| **macOS** build target | macOS 12 Monterey | Xcode 14+ and CocoaPods |

> **Tip:** run `flutter doctor` after installation to check that all required toolchain components are present.

---

## Getting started

```bash
# 1. Clone the repository
git clone https://github.com/pirers/fast-culling.git
cd fast-culling

# 2. Fetch all Dart/Flutter dependencies
flutter pub get
```

---

## Running the app

```bash
# macOS
flutter run -d macos

# Windows
flutter run -d windows

# List available devices / simulators
flutter devices
```

---

## Building a release

```bash
# macOS — produces fast_culling.app inside build/macos/Build/Products/Release/
flutter build macos --release

# Windows — produces a self-contained folder inside build/windows/x64/runner/Release/
flutter build windows --release
```

---

## Static analysis (linting)

```bash
flutter analyze
```

The project follows the rule-set from `package:flutter_lints`. Generated files
(`*.g.dart`, `*.freezed.dart`) are excluded from analysis via `analysis_options.yaml`.

---

## Running the tests

```bash
# Run all unit tests
flutter test

# Run a single test file
flutter test test/domain/algorithms/burst_detector_test.dart

# Run with verbose output
flutter test --reporter expanded
```

### Test coverage

```bash
flutter test --coverage
# HTML report (requires lcov)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html   # macOS
start coverage/html/index.html  # Windows
```

### Test suite layout

```
test/
  domain/
    algorithms/
      burst_detector_test.dart     # Burst grouping, ID stability, threshold edge cases
      crop_interpolator_test.dart  # Linear interpolation, boundary clamping
  persistence/
    sidecar_json_test.dart         # Sidecar JSON roundtrip, schema version, missing files
```

---

## Continuous integration

The CI pipeline runs automatically on every push/PR (see [`.github/workflows/ci.yml`](.github/workflows/ci.yml)):

1. `flutter pub get` — install dependencies
2. `flutter analyze` — static analysis
3. `flutter test` — unit tests

---

## Project structure

```
lib/
  domain/          # Pure Dart entities + algorithms (no Flutter imports)
    entities/      # Photo, Burst, BurstFrame, CropRect, AspectRatio, SftpConfig
    algorithms/    # burst_detector.dart, crop_interpolator.dart
  services/        # Abstract interfaces: ExifService, FilesystemService,
                   #   SftpService, FfmpegService, ThumbnailService
  persistence/     # Sidecar JSON, app settings, secure credential storage
  presentation/    # Flutter UI (Riverpod state, design-system wrappers, screens)
test/              # Unit tests mirroring lib/ structure
docs/              # Design documents and milestone plan
```

---

## Documentation

- [Coding Agent Prompt](docs/agent-prompt.md) — Consolidated feature specification and milestone plan.
