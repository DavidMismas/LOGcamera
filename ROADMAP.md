# Rawlight Roadmap

This file records ideas for future Rawlight releases. Items are not commitments and should be implemented only after the current App Store version is approved and stable.

## Planned features

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

For the first update after App Store approval, prioritize processed HEIC/JPEG-only photos, standard Rec.709 SDR video, and the horizon level. Next, add histogram or waveform and capture presets. Treat variable aperture as a hardware-dependent feature for iOS 27 devices, and add JPEG-XL only after device-level compatibility and file-readback testing.

