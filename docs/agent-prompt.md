# Coding Agent Prompt — Flutter Desktop Photo Workflow App

## Mission

Build a Flutter desktop app (primary targets: **Windows + macOS**) with two core modules:

1. **SFTP Transfer Module** — Recursively scan a local folder for JPEGs, filter by **EXIF-only** star rating, preview and select images, then upload selected files to a user-chosen SFTP directory using a safe `.partial` upload + atomic rename pattern.
2. **Burst Detection & Editor Module** — Recursively scan JPEGs, detect burst sequences from **EXIF timestamps** and a configurable interval threshold, provide a full burst editor (exclude frames, keyframes, fixed-aspect cropping per keyframe), and export bursts to **MP4** via **bundled FFmpeg** with interpolated crops between keyframes. Persist edits as **sidecar JSON**.

---

## Confirmed Constraints / Decisions

| Topic | Decision |
|---|---|
| Local folder scanning | **Recursive** |
| Rating metadata source | **EXIF only** (ignore XMP / maker notes for now) |
| Video export backend | **Bundle FFmpeg** with the app (per OS) |
| Remote filename collisions | User-configurable in Settings; **default = Skip** |
| Burst edit persistence | **Sidecar JSON** at `<root>/.photo_workflow.json` |
| `.partial` cleanup on failure/cancel | **Yes** — attempt cleanup; report to user if cleanup itself fails |
| UI approach | **Light adaptive** (Material as baseline, platform-aware shortcuts/dialogs, thin design-system wrapper layer for later native switch) |
| SFTP authentication | **Password only** |

---

## Feature 1 — Recursive JPEG Transfer to SFTP

### 1.1 Source Selection & Preview

- User selects a **local source directory**; app scans it **recursively** for JPEG files.
- Display a **thumbnail grid** of discovered images.
- Each thumbnail shows:
  - filename
  - EXIF star rating (if present)
- Selection tools:
  - individual multi-select (mouse/keyboard)
  - "Select all filtered"
  - "Clear selection"

### 1.2 Rating Filter (EXIF Only)

- Filter by **EXIF star rating** (read EXIF only; ignore XMP/maker notes).
- Filter mode: **minimum rating** (`>= N stars`; user picks N).
- Images missing a rating: **excluded by default**.

### 1.3 SFTP Connection Settings

- UI fields: **Host**, **Port** (default `22`), **Username**, **Password** (secure/masked input).
- **"Test connection"** action — shows success or failure with error detail.
- Store credentials using **OS secure storage** (macOS Keychain / Windows Credential Manager via Flutter secure storage).

### 1.4 Remote Directory Selection

- Provide a **remote folder browser** over SFTP and/or a validated path text field.
- User selects the target directory before uploading.

### 1.5 Upload Protocol (Safe Upload with Rename)

For each selected JPEG:

1. Upload to remote as `filename.jpg.partial`.
2. On **success**: rename remote file to `filename.jpg`.
3. On **failure or cancel**:
   - Attempt to delete the `.partial` remote file.
   - If cleanup fails, report the leftover `.partial` clearly to the user.

### 1.6 Collision Handling

- Setting (in app Settings): **Skip / Overwrite / Auto-rename**.
- **Default: Skip**.
- Policy applies consistently to both `.partial` staging name and the final `filename.jpg`.

### 1.7 Upload UX & Reliability

- Upload queue with:
  - per-file progress + overall progress
  - cancel button (graceful stop)
  - retry for failed items
- Clear error messages for: auth failure, host unreachable, permission denied, disk full, etc.

---

## Feature 2 — Burst Detection, Editor & MP4 Export

### 2.1 Recursive Scan & EXIF Timestamps

- User selects a **local directory**; app scans **recursively** for JPEGs.
- Timestamp extraction priority:
  1. `DateTimeOriginal` (preferred)
  2. `DateTimeDigitized` / `CreateDate` (EXIF fallback)
  3. If no EXIF timestamp: exclude from burst detection and show as "missing timestamp".

### 2.2 Burst Detection Rule

- Sort images by EXIF timestamp.
- Configurable **burst interval threshold** (milliseconds).
- If `Δt` between consecutive shots **≤ threshold** → same burst; otherwise → new burst starts.
- UI: threshold slider/input + "Detect bursts" action (and/or auto-detect on folder change).

### 2.3 Burst Overview UI

- Show all detected bursts in a **grid**:
  - representative thumbnail
  - frame count
  - time range
- Selecting a burst opens a detail view:
  - frame strip/grid with inclusion toggles
  - preview player (animated frames; FPS configurable, default 15–30)

### 2.4 Burst Editor

Per burst:

- **Include/exclude** individual frames.
- **Define keyframes** — mark specific frames as keyframes.
- **Fixed aspect ratio** per burst (set once; cannot change without clearing crop data):
  - Presets (landscape + portrait): `1:1`, `4:5`, `9:16`, `16:9`, `3:2`, `2:3`
- **Crop per keyframe** — resizable crop box constrained to the chosen aspect ratio.
- Keyframe management: add, remove, jump to keyframe; visual indication of which frames are keyframes.

### 2.5 Crop Interpolation (Export-Time)

- Interpolate crop rectangle `(x, y, w, h)` between keyframes linearly across frames.
- **Before the first keyframe**: use the first keyframe's crop rectangle (constant).
- **After the last keyframe**: use the last keyframe's crop rectangle (constant).
- Aspect ratio remains constant across the entire burst.

### 2.6 MP4 Export (Bundled FFmpeg)

- Bundle **FFmpeg** per OS (Windows + macOS); implement runtime discovery + permission handling.
- Export options per burst:
  - **FPS** (configurable; default 30)
  - **Target resolution** — presets constrained to chosen aspect ratio (e.g., `1080×1920` for `9:16`, `1920×1080` for `16:9`)
- Rendering model: for each frame, apply interpolated crop → scale to target resolution → encode to MP4.
- Output filename: based on burst start timestamp or burst index (configurable).
- Export **progress reporting + cancel** (stop FFmpeg process, clean temp files on cancel).

---

## Sidecar JSON Specification

### Location

`<selectedRootFolder>/.photo_workflow.json`

One file per scanned root folder, covering all bursts and edits for images under that folder.

### Recommended Minimal Schema

```json
{
  "schema_version": 1,
  "generated_by": "photo_workflow_app",
  "detection_threshold_ms": 500,
  "bursts": [
    {
      "id": "burst-<sha256_first8_of_first_frame_path_plus_timestamp>",
      "aspect_ratio": "16:9",
      "default_fps": 30,
      "default_resolution": [1920, 1080],
      "frames": [
        {
          "relative_path": "subdir/IMG_001.jpg",
          "file_size": 4823210,
          "exif_timestamp": "2024-06-15T10:23:45.123Z",
          "included": true,
          "is_keyframe": true,
          "crop": { "x": 0.1, "y": 0.05, "w": 0.8, "h": 0.45 }
        },
        {
          "relative_path": "subdir/IMG_002.jpg",
          "file_size": 4901023,
          "exif_timestamp": "2024-06-15T10:23:45.623Z",
          "included": true,
          "is_keyframe": false,
          "crop": null
        }
      ]
    }
  ]
}
```

**Notes:**
- `id` is a `burst-` prefix followed by the first 8 hex characters of the SHA-256 hash of `<first_frame_relative_path>|<first_frame_exif_timestamp>`, ensuring stable, collision-resistant burst identifiers.
- Frame identity uses `relative_path + exif_timestamp` as a stable composite key; `file_size` is stored as supplementary metadata only (not part of the identity key) so that legitimate file modifications (e.g., lossless re-export) do not silently discard crop data. Files not found at load time are flagged as missing rather than causing errors.
- `schema_version` enables forward-compatible migration.

---

## Engineering Requirements

### Architecture Layers

```
domain/        — pure Dart entities + algorithms (no Flutter imports)
services/      — EXIF, filesystem scan, SFTP client, FFmpeg wrapper
persistence/   — sidecar JSON, app settings, secure credential storage
presentation/  — Flutter UI + state management (e.g., Riverpod / Bloc)
```

### Design-System Wrapper Layer

Create a thin set of wrapper widgets from the start to allow later native UI swap:

- `AppScaffold`, `AppButton`, `AppDialog`, `AppTextField`
- `AppMenu`, `AppSplitView`, `AppProgress`, `AppNav`

In light-adaptive mode these forward to Material widgets; in a future native pass they can be re-implemented without touching screen logic.

### Isolates / Background Tasks

Run all heavy work off the main thread:

- recursive filesystem scan
- EXIF extraction
- thumbnail generation
- burst detection
- FFmpeg export pipeline

### Testing

- **Unit tests** (required):
  - Burst detection: edge cases, threshold boundaries, single-image and empty-folder cases
  - Crop interpolation math: linear interpolation across keyframes, boundary behavior
  - Sidecar JSON: serialization roundtrip, schema version handling, missing-file resilience
- **Integration / manual checklist** (acceptable for SFTP + FFmpeg initially):
  - SFTP upload: `.partial` → rename, cleanup on cancel, collision policies
  - FFmpeg export: correct aspect ratio, frame crop applied, progress/cancel

### Logging

- In-app debug log view + persistent log file.
- Log level: at minimum `info` and `error`; `debug` behind a flag.

---

## Milestones / Deliverables

| Milestone | Focus | Key Deliverables |
|---|---|---|
| **M0** | Project foundation | Flutter desktop project, folder structure, state management choice, design-system wrappers, CI skeleton |
| **M1** | Core scanning & EXIF | Recursive JPEG scan, EXIF rating + timestamp extraction, thumbnail generation + caching, unit tests for timestamp/burst logic |
| **M2** | SFTP Transfer MVP | Transfer screen, rating filter, SFTP settings + secure storage, test connection, remote dir browser, upload queue, `.partial` + rename, collision policy |
| **M3** | Burst Detection UI | Burst screen, threshold control, burst detection, bursts grid + detail view, frame preview animation |
| **M4** | Burst Editor + Sidecar JSON | Include/exclude frames, keyframe UI, aspect ratio + crop UI, sidecar JSON save/load, interpolation unit tests |
| **M5** | FFmpeg Bundling + MP4 Export | Bundle FFmpeg (Win/macOS), export pipeline (crop → scale → encode), FPS/resolution options, progress + cancel |
| **M6** | Polish + Light-Adaptive UX | Cmd/Ctrl shortcuts, error dialogs, retry flows, thumbnail perf, basic packaging (Windows installer / macOS bundle) |

---

## Assumptions

- **JPEG only** — no RAW format support in this scope.
- **Password-only SFTP** — no SSH key auth at this stage.
- **EXIF-only rating** — XMP sidecar ratings are ignored unless explicitly added later.
- **FFmpeg is bundled** — users do not need to install FFmpeg separately.
- **No cloud sync** — all transfers are SFTP; no Dropbox/Google Drive integration.
- **No mobile** — Windows and macOS desktop only; Linux is a nice-to-have with no hard requirement.
- **Light adaptive UI** — Material 3 as baseline with platform-aware shortcuts and file dialogs; architecture allows later switch to fully native widgets.
- For frames before the first keyframe / after the last keyframe, the nearest keyframe's crop rectangle is held constant (no extrapolation).
- Aspect ratio for a burst cannot be changed once crop data exists; resetting aspect ratio clears all crop data for that burst.

---

## Proceed By

1. **M0** — Set up the Flutter desktop project with the defined folder structure, choose a state management solution (Riverpod recommended), create design-system wrapper stubs, and establish a CI pipeline.
2. **M1** — Implement recursive JPEG scan + EXIF extraction (rating + timestamps) + thumbnail caching, and write unit tests for timestamp selection and burst grouping logic.
3. **M2 → M6** — Implement features in milestone order, writing tests as specified, and updating this document if constraints change.

If any assumption proves incorrect during implementation, document the change here and adjust the affected milestones accordingly.
