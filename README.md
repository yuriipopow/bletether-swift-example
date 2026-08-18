# SimBle · Swift BLE example

A native SwiftUI app that scans for Bluetooth devices, connects, and reads a
characteristic — **passing on a GitHub-hosted runner with no Bluetooth hardware.**

[![bluetooth test](../../actions/workflows/test.yml/badge.svg)](../../actions/workflows/test.yml)

## What it shows

The app ([`Sources/BLEScannerApp.swift`](Sources/BLEScannerApp.swift)) talks to
`CoreBluetooth` directly — `CBCentralManager`, `CBPeripheral`, no wrapper library. It
has no idea SimBle exists.

When it sees the recorded **SimBle Demo Sensor** it connects, reads the Battery Level
(0x2A19), and shows it. A native XCUITest
([`UITests/BLEScannerUITests.swift`](UITests/BLEScannerUITests.swift)) drives the app
and asserts that it read `Battery: 100%`. That is what CI runs — a plain
`xcodebuild test`: a green run means a real CoreBluetooth session, scan → connect →
discover → read, completed on a hosted runner with no radio and no device in the room.

Those values come from [`fixtures/demo.json`](fixtures/demo.json), a recording of a
synthetic sensor.

Native Swift connects the peripheral it discovered — the straightforward path SimBle
has supported from the start (`react-native-ble-plx` takes a different route; see that
example).

## How the CI works

[`.github/workflows/test.yml`](.github/workflows/test.yml): generate the project with
`xcodegen`, boot a simulator, serve the fixture with the SimBle action, then run
`xcodebuild test`.

```yaml
- uses: yuriipopow/simble@v1       # serve the recorded device to the simulator
  with:
    fixture: fixtures/demo.json
    device: ${{ steps.sim.outputs.udid }}
```

The test reads the shim and fixture paths the action set up and injects them into the
app under test through its `launchEnvironment` (passed in with the `TEST_RUNNER_`
prefix, which is how `xcodebuild` forwards environment to a UI test runner).

## Run it locally

Needs [`xcodegen`](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) and
the built `libsimble_virtual.dylib` (from the SimBle repo).

```bash
xcodegen generate
UDID=$(xcrun simctl create test "iPhone 17"); xcrun simctl boot "$UDID"

TEST_RUNNER_SIMBLE_DYLIB=/path/to/build/libsimble_virtual.dylib \
TEST_RUNNER_SIMBLE_FIXTURE_PATH="$PWD/fixtures/demo.json" \
  xcodebuild test -project BLEScanner.xcodeproj -scheme BLEScanner \
    -destination "id=$UDID"
```

Or record your own device with `simble record` and point the fixture at it.

The app lists the served device and reads its battery. Or record your own device with
`simble record` and point the fixture at it.

Built with SwiftUI and CoreBluetooth; the Xcode project is generated from
[`project.yml`](project.yml).
