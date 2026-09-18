# Rawlight Roadmap

This file records ideas for future Rawlight releases. Items are not commitments and should be implemented only after the current App Store version is approved and stable.

## Planned features

### 4K 120 fps recording reliability

Treat smooth 4K 120 fps recording as a priority correctness fix after version 1.0.0 is approved. It currently exhibits frequent skipped frames on an iPhone 17 Pro even though the selected camera format advertises 4K 120 fps support.

Instrument the capture pipeline before changing behavior. Count and classify frames reported through the dropped-frame delegate, record gaps in source presentation timestamps, measure `AVAssetWriterInput.isReadyForMoreMediaData` backpressure, and log thermal state, selected lens and format, stabilization, codec, bitrate, pixel format, and storage conditions.

The current design sends full-resolution video and audio callbacks to the same serial writer queue. That video callback appends to `AVAssetWriter`, creates normalized timing copies, dispatches preview frames, and performs camera-state readback. Because `alwaysDiscardsLateVideoFrames` is enabled, blocking this queue can immediately drop incoming 120 fps frames. Separate the minimal capture-and-write path from preview and UI work, throttle monitoring independently, and avoid silently discarding frames when the writer reports backpressure.

Review the synthetic sequential video timestamps. Preserve source timing or account explicitly for dropped frames so video duration and audio timing cannot diverge. Prefer AVFoundation's recommended writer settings and media timescale for the active output, then apply only the overrides Rawlight actually needs.

Validate at minimum HEVC and every exposed ProRes option separately, with stabilization off and on where supported. Test cold and warm-device runs of at least 1, 5, and 10 minutes. Acceptance requires stable cadence and audio sync, no unexplained timestamp discontinuities, no silent writer drops, and a clear warning or unavailable state for combinations the device cannot sustain.

### Horizon level

Add a clear visual level for roll and, where useful, pitch. It should use Core Motion, match the existing dark/red interface, settle smoothly, and provide subtle haptic feedback when the camera reaches level. It must work in both Photo and Video modes and be optional in Settings.

### Variable physical aperture

Add manual aperture control to Photo and Video modes on supported future devices. Use capability detection rather than checking for a specific iPhone model.

The iOS 27 AVFoundation API already provides `recommendedLensApertureStops`, `supportsExposureModeCustom(lensAperture:duration:iso:)`, and `setExposureModeCustom(lensAperture:duration:iso:completionHandler:)`. The control should appear only when the active format exposes more than one recommended aperture stop. It must integrate cleanly with the existing shutter, ISO, auto-exposure, and manual-exposure modes.

### Processed photo capture without RAW

Add HEIC Only and JPEG Only capture options. These modes should create no DNG or RAW companion file. Keep the existing image-quality control where the selected codec supports it, and clearly show the resulting resolution and estimated file-size tradeoff.

### Standard SDR video

Add a normal Rec.709 SDR recording mode without Apple Log and without applying the Apple Log preview LUT or another baked-in creative look. Keep codec, resolution, frame rate, exposure, focus, zebras, peaking, audio, and stabilization controls available where supported.

### JPEG-XL and ProRAW compression

Add supported JPEG-XL output and ProRAW compression choices after testing the actual combinations exposed by each device and active capture format.

For Apple ProRAW, present the user-facing choices accurately as JPEG Lossless, JPEG-XL Lossless, and JPEG-XL Lossy when the capture pipeline exposes them. Do not describe JPEG-XL as uncompressed. If a separate uncompressed processed-image workflow is added later, present it as a distinct format because uncompressed processed pixels are not RAW data and are not JPEG-XL compression.

Use runtime checks such as the photo output's available codec and file types. Never assume that every iPhone or lens supports every combination.

## Recommended additions

### Customizable quick controls

After version 1.0.0 is approved and stable, redesign the main capture screen so a small set of frequently used functions is available without opening Settings. Use NoFusion only as a reference for information hierarchy and speed of access; keep Rawlight's own dark/crimson visual language, control shapes, typography, and interaction patterns.

Provide separate customizable quick-control layouts for Photo and Video modes. Start with a curated default layout, then let the user choose and reorder a limited number of slots. A long press on the quick-control strip can enter edit mode; normal taps should either toggle a setting immediately or open a compact picker without leaving the camera.

Good Photo candidates include RAW or processed format, resolution, image quality, companion file, aspect-ratio guides, flash, grid, horizon level, zebras, focus peaking, metering behavior, and lens selection. Good Video candidates include color profile, codec, resolution, frame rate, monitoring look, stabilization, audio mode, torch, grid, horizon level, zebras, focus peaking, and white-balance or exposure lock.

Keep ISO, shutter, white balance, focus, shutter/record, lens switching, and exposure compensation in their established primary locations rather than duplicating every control. Limit the customizable strip to roughly four or five visible items so the live preview remains dominant. Active controls should use Rawlight red, neutral controls white or gray, and warnings amber. Unsupported options should be omitted or replaced instead of remaining as misleading disabled shortcuts.

The control layout must adapt to orientation, Dynamic Island and safe-area insets, and different screen sizes without moving the shutter button or core manual controls. Persist Photo and Video layouts separately and include a Restore Defaults action.

### Histogram and waveform

Add a compact luminance histogram for Photo mode and an optional luma waveform for Video mode. These would complement zebras and make Rawlight's manual exposure workflow more complete without changing the core interface.

### Capture presets

Allow users to save a small number of named setups containing format, resolution, frame rate, codec, shutter, ISO, white balance, focus tools, zebras, and peaking. Photo and Video presets should remain separate.

### Storage, duration, and thermal status

Show available storage and estimated remaining recording time for the selected video settings. Add unobtrusive warnings when thermal pressure or storage limits may interrupt a recording.

### Capture review and metadata

Add a lightweight last-capture review with essential metadata such as format, resolution, lens, shutter, ISO, white balance, aperture when available, codec, frame rate, and file size. Avoid building a full photo-library replacement.

### Bracketing and interval capture

Consider exposure bracketing and an intervalometer after the basic processed-only photo formats are stable. Both features fit the manual-camera audience and can reuse existing exposure controls.

### External recording destination

Investigate recording large video files directly to supported external storage, with clear speed validation and fallback behavior before recording begins.

## Suggested priority

For the first update after App Store approval, fix and validate 4K 120 fps recording before adding features. Then prioritize processed HEIC/JPEG-only photos, standard Rec.709 SDR video, the horizon level, and a carefully limited customizable quick-control strip. Next, add histogram or waveform and capture presets. Treat variable aperture as a hardware-dependent feature for iOS 27 devices, and add JPEG-XL only after device-level compatibility and file-readback testing.
