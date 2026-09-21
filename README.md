# CovaMac — Pro System Maintenance & Diagnostic Suite for macOS

**CovaMac** is a native, high-performance system maintenance, pro uninstaller, duplicate finder, hardware/software diagnostic, and battery health telemetry suite built with **Swift 6 & SwiftUI** for macOS 13+ (Ventura, Sonoma, Sequoia).

---

## Features

### 1. Battery Health & Live Charger Telemetry
- **Apple Smart Battery Diagnostics**: Reads live IOKit telemetry including State of Charge %, Maximum Capacity vs Factory Design Capacity (Health %), Cycle Count vs 1,000 rating, live Temperature (°C/°F), Voltage, and Amperage draw.
- **AC Power Adapter Specifications**:
  - Live negotiated Wattage (e.g. 96W, 67W, 140W).
  - Adapter Model & Name (e.g. "96W USB-C Power Adapter").
  - Manufacturer ("Apple Inc.").
  - Hardware & Firmware revisions.
  - Power adapter serial number.
  - Charging state (Fast Charging, Normal Charging, Optimized Battery Charging / Connected Not Charging).

### 2. Pro Uninstaller & Leftover Cleaner
- **Full App Discovery**: Scans `/Applications`, `/System/Applications`, and `~/Applications`.
- **Deep Residual Scanner**: Finds hidden caches, application support, preferences, containers, group containers, saved application states, WebKit, and HTTP storages across `~/Library`.
- **Orphan Leftovers Hunter**: Scans for abandoned files belonging to applications that have already been deleted from your Mac, allowing you to reclaim gigabytes of forgotten space.
- **Safe Trashing**: Uses macOS Trash so all cleaned files can be restored if desired.

### 3. Cryptographic Duplicate File Finder
- Multi-threaded scanning for any target folder (Downloads, Documents, Pictures, or custom).
- 3-Stage fast matching:
  1. Exact file size grouping.
  2. 4KB header prefix hash filter.
  3. Full SHA-256 cryptographic verification for collision-proof duplicate detection.
- **Smart Auto-Select**: Automatically selects duplicates while keeping the oldest or newest original copy.

### 4. Hardware & Software Testers
- **CPU Benchmark & Stress Test**: Multi-threaded mathematical workloads across all cores, calculating real GFLOPS and tracking thermal throttling.
- **RAM Integrity & Bandwidth**: Allocates a 256MB memory buffer and writes/verifies alternating bit patterns to check for memory corruptions and measure throughput (MB/s).
- **Disk Speed Benchmark**: Tests real sequential read and write throughput in MB/s using temporary benchmark payloads.
- **Audio & Microphone Tester**: Generates left/right stereophonic test frequencies to verify speaker balance and channel separation, accompanied by a live microphone decibel VU meter.
- **Display Quality & Dead Pixel Inspector**: Inspects native screen resolution, backing scale factor, refresh rate (60Hz / 120Hz ProMotion), and full-screen color cycle mode.
- **System Health & Security**: Checks System Integrity Protection (SIP), FileVault encryption, memory swap, and counts recent application crash reports in `DiagnosticReports`.

### 5. Top Bar Status Monitor (Menu Bar Extra)
- Persistent status item in the macOS menu bar showing live battery % and CPU load.
- Clickable dropdown popover providing instant metrics, quick memory/junk cleanup, and 1-click launcher to open the main window.

### 6. Non-Annoying Monetization & Optional "Remove Ads"
- **Fair & Non-Intrusive**: No full-screen popups, no countdown timers, and no blocking of user actions. Styled as clean, native "Featured Partner / Recommended Tool" cards.
- **Simple 1-File Link Management**: All sponsor and affiliate links are configured in a single file: `Sources/MonetizationConfig.swift`. Paste your affiliate links there anytime!
- **Remove Ads / Go Pro**: Includes an optional "Remove Ads / Support" button in the sidebar and Settings. Entering a license key (or promo code `COVAPRO`) or toggling Ad-Free Mode instantly hides all sponsor banners across the entire application.

---

## Build & Launch

### Quick Build & Run
To compile and assemble the macOS application bundle:
```bash
./build_app.sh
```

To launch CovaMac:
```bash
open ./CovaMac.app
```

Or run via Swift CLI:
```bash
swift run
```
