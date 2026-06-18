# Changelog

## v1.1.3

### Fixed

- **Device detection on macOS 15+ (Sequoia / Tahoe)**: replaced the
  `heimdall detect` subprocess-only poll with a two-stage approach.
  Stage 1 uses IOKit directly from Swift (`IOServiceGetMatchingServices`
  on `IOUSBHostDevice`/`IOUSBDevice`, matching Samsung VID 0x04E8) to
  check whether any Samsung device is visible on the USB bus — no
  interface claim needed, no subprocess, works even when the accessory
  hasn't been approved yet. Stage 2 only runs `heimdall detect` when
  stage 1 finds something, confirming the device is in Download Mode.
- Added a `usbBusPresent` signal so the log shows
  "Samsung device detected on USB bus — waiting for Download Mode
  response" when the device is on USB but not yet responding to the
  Odin handshake.
- **Setup view now shows USB Accessories row** on macOS 15+, explaining
  the "Allow Accessory to Connect?" approval dialog and providing an
  "Open Settings" button that navigates directly to Privacy & Security.
- Added `-framework IOKit` to `build.sh` linker flags.

## v1.1.2

### Fixed

- USB pipe stall errors (`pipe is stalled`, `bulk transfer failed`) and
  `Failed to begin session` failures now correctly trigger the
  "disconnect, re-enter Download Mode, reconnect" guidance instead of
  showing a raw Heimdall error. Previously only `Setting up interface failed`
  and `Claiming interface failed` were caught.
- Flash errors now run the same reconnect-required check as PIT download
  errors, so the helpful reconnect message appears on the **first** failure
  instead of only on a subsequent retry.

## Unreleased

### Added

- `.pkg` installer (`scripts/build-pkg.sh`, wired into `scripts/release.sh`)
  that installs OdinMac to `/Applications`, clears the quarantine flag, and
  opens the app automatically when installation finishes.
- Setup & Requirements dialog now checks for Homebrew, Gatekeeper quarantine
  state, and admin account status, with one-click buttons to install
  Homebrew (handling its root-vs-admin-password requirements automatically)
  or clear the quarantine flag, then re-verifies each fix.
- Footer credit: "by Harith Dilshan | h4rithd".

## v1.1.1

First public GitHub release.

### Highlights

- Native Apple Silicon Samsung firmware flashing interface.
- BL, AP, CP, CSC, HOME_CSC, and USERDATA firmware support.
- Firmware archive inspection and PIT-based partition mapping.
- Bundled kext-free Heimdall engine with static libusb.
- Live connection status, flash progress, and compact logs.
- Guarded Re-partition and NAND Erase All options.
- ADB device information support.
- Fixed-size compact interface with a full partition guide.

### Notes

- Requires macOS 13 or later on Apple Silicon.
- The app is ad-hoc signed and not notarized.
- The Root/Magisk interface is planned for a future release.
