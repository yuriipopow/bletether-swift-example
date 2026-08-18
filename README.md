# SimBle · Swift BLE example

A native SwiftUI app that scans for Bluetooth devices, connects, and reads a
characteristic — **passing on a GitHub-hosted runner with no Bluetooth hardware.**

[![bluetooth test](../../actions/workflows/test.yml/badge.svg)](../../actions/workflows/test.yml)

## What it shows

The app ([`Sources/BLEScannerApp.swift`](Sources/BLEScannerApp.swift)) talks to
`CoreBluetooth` directly — `CBCentralManager`, `CBPeripheral`, no wrapper library. It
has no idea SimBle exists.

When it sees the recorded **SimBle Demo Sensor** it connects, reads the Battery Level
(0x2A19), and logs a `SIMBLE_SELFTEST` marker. That is what CI checks: a green run
means a real CoreBluetooth session — scan → connect → discover → read — completed on a
hosted runner with no radio and no device in the room.

Those values come from [`fixtures/demo.json`](fixtures/demo.json), a recording of a
synthetic sensor.

Native Swift connects the peripheral it discovered — the straightforward path SimBle
has supported from the start (`react-native-ble-plx` takes a different route; see that
example).

## How the CI works

[`.github/workflows/test.yml`](.github/workflows/test.yml): generate the project with
`xcodegen`, boot a simulator, serve the fixture with the SimBle action, build, launch,
and wait for the self-test marker.

```yaml
- uses: yuriipopow/simble@v1       # serve the recorded device to the simulator
  with:
    fixture: fixtures/demo.json
    device: ${{ steps.sim.outputs.udid }}
```

## Run it locally

Needs [`xcodegen`](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) and
[SimBle.app](https://github.com/yuriipopow/simble) with `simble` on your PATH.

```bash
xcodegen generate
UDID=$(xcrun simctl create test "iPhone 17"); xcrun simctl boot "$UDID"
simble ci fixtures/demo.json "$UDID"
open -a Simulator
xcodebuild -project BLEScanner.xcodeproj -scheme BLEScanner \
  -sdk iphonesimulator -derivedDataPath build build
xcrun simctl install "$UDID" \
  "$(find build -name BLEScanner.app -path '*iphonesimulator*' | head -1)"
xcrun simctl launch "$UDID" dev.simble.example.BLEScanner
```

The app lists the served device and reads its battery. Or record your own device with
`simble record` and point the fixture at it.

Built with SwiftUI and CoreBluetooth; the Xcode project is generated from
[`project.yml`](project.yml).
