# earmac

An unofficial macOS menu bar app for controlling Nothing and CMF earbuds over Bluetooth Low Energy.

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-blue" alt="Platform">
  <img src="https://img.shields.io/badge/license-GPL--3.0-green" alt="License">
  <img src="https://img.shields.io/badge/Swift-5.0-orange" alt="Swift">
</p>

## Features

- **Menu bar app** — lives in your menu bar, no Dock icon
- **Battery monitoring** — left bud, right bud, and case battery levels with charging indicators
- **ANC control** — Off, Transparency, and ANC modes (Low / Mid / High / Adaptive) with an intuitive intensity selector
- **Device info** — automatic model detection, serial number, and firmware version
- **Auto-connect** — automatically connects to earbuds already paired with your Mac
- **Battery polling** — refreshes battery levels every 30 seconds

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
- Xcode 16+ (for building from source)
- Earbuds paired with your Mac via System Settings → Bluetooth

## Installation

### From source

1. Clone the repository:
   ```bash
   git clone https://github.com/gaganr/earmac.git
   cd earmac
   ```

2. Open in Xcode:
   ```bash
   open earmac.xcodeproj
   ```

3. Build and run (⌘R)

The app will appear in your menu bar with an AirPods Pro icon.

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
- Commands include battery query, serial number, firmware version, ANC mode read/write, and more
- CMF Buds Pro 2 may compute CRC over payload-only (header+payload CRC is tried first, payload-only as fallback)

## Project Structure

```
earmac/
  earmacApp.swift              — MenuBarExtra scene entry point
  ContentView.swift            — Popover UI (battery, ANC, device info)
  Protocol/
    CRC16.swift                — Modbus CRC-16 implementation
    EarFrame.swift             — Frame encoder
    EarCommand.swift           — Command code constants
    EarRequest.swift           — Request builders
    EarResponse.swift          — Response decoder + parsers
  Domain/
    ANCMode.swift              — ANC modes and groups
    BatteryInfo.swift          — Battery level data models
    DeviceModel.swift          — Device model detection (SKU-based)
  Bluetooth/
    BluetoothManager.swift     — CoreBluetooth manager (@Observable)
    BluetoothDelegate.swift    — CBCentralManager/CBPeripheral delegate
earmacTests/
    CRC16Tests.swift           — CRC golden-vector tests
    EarFrameTests.swift        — Frame encode/decode tests
    EarResponseTests.swift     — Response parser tests
```

## Roadmap

- [ ] EQ presets and custom EQ
- [ ] Enhanced bass control
- [ ] Spatial audio modes
- [ ] In-ear detection toggle
- [ ] Low latency mode
- [ ] Gesture customization
- [ ] Find my earbuds
- [ ] Personalized ANC
- [ ] Auto-reconnect on disconnect
- [ ] Settings window

## Acknowledgements

The BLE protocol used by Nothing/CMF earbuds was reverse-engineered by the open-source community. The following projects served as protocol references (protocol facts such as UUIDs, command codes, and CRC algorithms are not copyrightable):

- [radiance-project/ear-web](https://github.com/radiance-project/ear-web) — Web Bluetooth client (AGPL-3.0)
- [bestK1ngArthur/swift-nothing-ear](https://github.com/bestK1ngArthur/swift-nothing-ear) — Swift CoreBluetooth package (GPL-3.0)
- [marlon-yepes/cmf-macos](https://github.com/marlon-yepes/cmf-macos) — SwiftUI macOS app (GPL-3.0)
- [dest4590/ear-native](https://github.com/dest4590/ear-native) — Rust native client (AGPL-3.0)

All code in earmac is an original, clean-room implementation written from scratch.

## Legal

This application is published under the [GNU General Public License v3.0](LICENSE).

This app is not affiliated with, sponsored by, or endorsed by Nothing Technology Limited. "Nothing", "CMF", and device names are trademarks of Nothing Technology Limited. The developer of this app take no responsibility for the accuracy or completeness of the content provided. All trademarks and registered trademarks are the property of their respective owners.
