# earmac

An unofficial macOS menu bar app for controlling Nothing and CMF earbuds over Bluetooth Low Energy.

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-blue" alt="Platform">
  <img src="https://img.shields.io/badge/license-GPL--3.0-green" alt="License">
  <img src="https://img.shields.io/badge/Swift-5.0-orange" alt="Swift">
</p>

## Features

### Menu Bar
- **Battery monitoring** — left bud, right bud, and case battery levels with charging indicators and color-coded levels
- **ANC control** — Off, Transparency, and ANC modes (Low / Mid / High / Adaptive) with an expandable intensity selector
- **Spatial audio** — Off / Fixed toggle (device-dependent modes)
- **Device info** — automatic model detection, serial number, and firmware version
- **Auto-connect** — automatically connects to earbuds already paired with your Mac
- **Battery polling** — refreshes battery levels every 30 seconds

### Settings Window (⌘,)
- **EQ presets** — Balanced, Voice, More Treble, More Bass, Custom, Advanced
- **Custom EQ** — 3-band slider (bass / mid / treble, -6 to +6) with live values and Apply button
- **Advanced EQ** — toggle for multi-band parametric EQ
- **In-ear detection** — toggle to pause playback when earbuds are removed
- **Auto-reconnect** — automatically attempts to reconnect up to 3 times when the connection drops
- **Low battery notifications** — macOS notification when any bud drops below a configurable threshold (10–30%)

## Supported Devices

| Device | Model Code |
|---|---|
| Nothing Ear (1) | B181 |
| Nothing Ear (stick) | B157 |
| Nothing Ear (2) | B155 |
| Nothing Ear (3) | B173 |
| Nothing Ear | B171 |
| Nothing Ear (a) | B162 |
| Nothing Ear (open) | B174 |
| CMF Buds Pro | B163 |
| CMF Buds | B168 |
| **CMF Buds Pro 2** | **B172** |
| CMF Buds 2 | B179 |
| CMF Buds 2 Plus | B184 |
| CMF Buds 2a | B185 |
| CMF Neckband Pro | B164 |
| Nothing Headphone (1) | B170 |
| Nothing Headphone (a) | B186 |
| CMF Headphone Pro | B175 |

## Requirements

- macOS 26.0+
- Earbuds paired with your Mac via System Settings → Bluetooth

## Installation

### Download the DMG (easiest)

1. Download `earmac.dmg` from the [latest release](https://github.com/Gaganrdev/EarMac/releases)
2. Open the DMG file
3. Drag **earmac** to your **Applications** folder
4. Launch earmac — it will appear in your menu bar
5. Make sure your earbuds are paired via System Settings → Bluetooth
6. Click the earmac icon in the menu bar → Connect

### Build from source

1. Clone the repository:
   ```bash
   git clone https://github.com/Gaganrdev/EarMac.git
   cd EarMac
   ```

2. Open in Xcode:
   ```bash
   open earmac.xcodeproj
   ```

3. Build and run (⌘R)

The app will appear in your menu bar. No Dock icon is shown.

## How It Works

earmac communicates with Nothing/CMF earbuds over Bluetooth Low Energy (BLE) using CoreBluetooth:

1. **Discovery** — scans for devices advertising the Google Fast Pair service (`0xFE2C`)
2. **Connection** — connects to the device and discovers GATT services
3. **Service selection** — identifies the proprietary Nothing/CMF control service (`0xFD90`)
4. **Communication** — sends framed command packets over a write characteristic and receives responses via notify

### Protocol

The earbuds use a custom binary protocol with the following frame structure:

```
[0x55, 0x60, 0x01, CMD_LO, CMD_HI, LEN, 0x00, OP_ID, PAYLOAD..., CRC_LO, CRC_HI]
```

- **CRC-16/MODBUS** (polynomial `0xA001`, initial value `0xFFFF`)
- Commands include battery query, serial number, firmware version, ANC mode, EQ presets, custom EQ, spatial audio, in-ear detection, and more
- CMF Buds Pro 2 may compute CRC over payload-only (header+payload CRC is tried first, payload-only as fallback)
- Commands are sent sequentially (one at a time) to avoid disconnecting the device

## Project Structure

```
earmac/
  earmacApp.swift              — MenuBarExtra + Settings scene entry point
  ContentView.swift            — Popover UI (battery, ANC, spatial audio, device info)
  Protocol/
    CRC16.swift                — Modbus CRC-16 implementation
    EarFrame.swift             — Frame encoder
    EarCommand.swift           — Command code constants
    EarRequest.swift           — Request builders
    EarResponse.swift          — Response decoder + parsers
  Domain/
    ANCMode.swift              — ANC modes and groups
    BatteryInfo.swift          — Battery level data models
    DeviceModel.swift          — Device model detection (SKU-based) + capabilities
    EQPreset.swift             — EQ preset enum
    EQPresetCustom.swift       — Custom EQ struct + 53-byte payload encoder
    SpatialAudioMode.swift     — Spatial audio modes
  Bluetooth/
    BluetoothManager.swift     — CoreBluetooth manager (@Observable)
    BluetoothDelegate.swift    — CBCentralManager/CBPeripheral delegate
  Settings/
    SettingsScene.swift        — Settings window with 3-tab TabView
    AudioSettingsView.swift    — EQ presets, custom EQ sliders, advanced EQ
    FeaturesSettingsView.swift — In-ear detection toggle
    GeneralSettingsView.swift  — Auto-reconnect, notifications, about
  Notifications/
    NotificationManager.swift  — Low battery UNUserNotificationCenter wrapper
earmacTests/
    CRC16Tests.swift           — CRC golden-vector tests
    EarFrameTests.swift        — Frame encode/decode tests
    EarResponseTests.swift     — Response parser tests
    EQPresetTests.swift        — EQ preset wire value tests
    CustomEQTests.swift        — Custom EQ payload + round-trip tests
    SpatialAudioTests.swift    — Spatial audio parsing tests
    InEarDetectionTests.swift  — In-ear detection parsing tests
```

## Roadmap

- [ ] Enhanced bass control
- [ ] Low latency mode
- [ ] Gesture customization
- [ ] Find my earbuds
- [ ] Personalized ANC
- [ ] Ear tip fit test

## Acknowledgements

The BLE protocol used by Nothing/CMF earbuds was reverse-engineered by the open-source community. The following projects served as protocol references (protocol facts such as UUIDs, command codes, and CRC algorithms are not copyrightable):

- [radiance-project/ear-web](https://github.com/radiance-project/ear-web) — Web Bluetooth client (AGPL-3.0)
- [bestK1ngArthur/swift-nothing-ear](https://github.com/bestK1ngArthur/swift-nothing-ear) — Swift CoreBluetooth package (GPL-3.0)
- [marlon-yepes/cmf-macos](https://github.com/marlon-yepes/cmf-macos) — SwiftUI macOS app (GPL-3.0)
- [dest4590/ear-native](https://github.com/dest4590/ear-native) — Rust native client (AGPL-3.0)

All code in earmac is an original, clean-room implementation written from scratch.

## Legal

This application is published under the [GNU General Public License v3.0](LICENSE).

This app is not affiliated with, sponsored by, or endorsed by Nothing Technology Limited. "Nothing", "CMF", and device names are trademarks of Nothing Technology Limited. The developer of this app takes no responsibility for the accuracy or completeness of the content provided. All trademarks and registered trademarks are the property of their respective owners.
