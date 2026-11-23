# Phone2PC

Send text, links, photos, videos and any file from your phone to your PC over the **local Wi-Fi**. No cloud, no accounts, no analytics, no external servers.

```
apps/mobile      Flutter app – Android + iOS (the client)
apps/desktop     Flutter app – Windows + macOS + Linux (tray app + HTTP receiver)
packages/shared  Pure-Dart models, constants, token helpers, file-name sanitiser, streaming multipart parser
```

Requires **Flutter ≥ 3.50** (Dart 3.x). Both apps use Riverpod (`Notifier`), go_router and a feature-first layout (`lib/features/<feature>/…`).

## How it works

* The desktop app runs a `shelf` HTTP server on port **53317**, bound to all IPv4 interfaces, and advertises itself over mDNS as `_phone2pc._tcp`.
* The phone talks to it with plain `dart:io` HTTP. **Every** request needs `Authorization: Bearer <token>`; anything else gets `401`. The token is compared in constant time and read per request, so revoking takes effect immediately.
* Uploads are `multipart/form-data`, streamed on both ends (a small custom parser in `packages/shared` – memory use is one chunk, so 1 GB+ files are fine). A dropped connection deletes the partial file.

| Method | Path | Body | Result |
|---|---|---|---|
| GET | `/ping` | – | `{app, deviceName, version}` |
| POST | `/text` | `{content, type: "text"\|"link"}` | `{ok, id}` |
| POST | `/file` | multipart, one or more `file` parts | `{ok, items:[{id,name,size}]}` |
| GET | `/history?limit=50` | – | `{items:[…]}` (no server paths) |

Received files go to `~/Downloads/Phone2PC/<yyyy-MM-dd>/`. Names are sanitised (path components, control and Windows-illegal characters, reserved names, length) and clashes become `name (1).ext`, `name (2).ext`, … (files are created exclusively, so concurrent uploads can't collide).

## Setup

```bash
flutter --version                       # must be >= 3.50
cd packages/shared && dart pub get && dart test   # 14 tests
cd ../../apps/desktop && flutter pub get
cd ../mobile && flutter pub get
```

Linux desktop build needs: `sudo apt install libgtk-3-dev libxi-dev libayatana-appindicator3-dev libnotify-dev clang cmake ninja-build pkg-config` (GNOME also needs the AppIndicator shell extension for the tray icon).

## Run

```bash
# Desktop (pick one)
cd apps/desktop && flutter run -d windows
cd apps/desktop && flutter run -d macos
cd apps/desktop && flutter run -d linux

# Phone (device must be on the same Wi-Fi as the PC)
cd apps/mobile && flutter run -d <android-or-ios-device>
```

The desktop starts minimised to the tray (the first run opens the window). Close = hide to tray; **Quit** is in the tray menu. Pass `--show` to force the window open.

## Pairing (first time only)

1. Desktop → tray/window → **Pair phone** (QR icon). The QR holds `{ip, port, deviceName, pairingToken}`.
2. Phone → **Scan QR code**. The token is stored in the Keychain / Android Keystore (`flutter_secure_storage`).
3. If the QR can't be scanned: phone → *Enter manually* → *Search nearby* (mDNS) or type IP / port / token (shown under *Manual details* on the desktop).
4. **Revoke / re-pair** (desktop, same screen or Settings) generates a new token; the old phone gets `401` and shows *Pairing expired*.

If the PC's IP changes (DHCP), the phone finds it again via mDNS by device name and updates the saved address.

## Platform notes and permissions

**Android** (`apps/mobile/android/.../AndroidManifest.xml`, already set): `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE` (mDNS), `CAMERA` (QR), `usesCleartextTraffic="true"` (the LAN API is plain HTTP), `launchMode="singleTask"` and the `SEND` / `SEND_MULTIPLE` intent filters for **Share → Phone2PC**. `minSdk` is 23.

**iOS** (`apps/mobile/ios/Runner/Info.plist`, already set): `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSLocalNetworkUsageDescription`, `NSBonjourServices = [_phone2pc._tcp]`, `NSAllowsLocalNetworking`. Accept the *Local Network* prompt on first launch.
*Share extension (manual, needs Xcode and a Mac):* receiving from other apps on iOS requires a Share Extension target – follow the "iOS" section of the [`receive_sharing_intent`](https://pub.dev/packages/receive_sharing_intent) README (new *Share Extension* target, shared App Group, `RSIShareViewController` subclass, Podfile entry). Android needs nothing more.

**macOS** (`apps/desktop/macos/Runner/*.entitlements`, already set): `network.server` + `network.client`; the App Sandbox is **off** so the app can write to `~/Downloads` and any folder you choose without security-scoped bookmarks (fine for personal use; not App-Store-ready). `Info.plist` has `NSLocalNetworkUsageDescription` and `NSBonjourServices`. Allow *incoming connections* when macOS asks.

**Windows**: on first run a dialog offers to add the inbound firewall rule (UAC prompt), or shows the command to run yourself:
```
netsh advfirewall firewall add rule name="Phone2PC" dir=in action=allow protocol=TCP localport=53317 profile=private,domain
```
Your Wi-Fi must be a *Private* network profile.

**Linux**: if you use `ufw`: `sudo ufw allow 53317/tcp` and `sudo ufw allow 5353/udp`.

## Build

```bash
# Android APK (set up signing first for a release you intend to keep: https://docs.flutter.dev/deployment/android)
cd apps/mobile && flutter build apk --release --split-per-abi
#   → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Windows (run on Windows)
cd apps/desktop && flutter build windows --release
#   → build\windows\x64\runner\Release\phone2pc_desktop.exe  (ship the whole Release folder)

# macOS (run on a Mac)
cd apps/desktop && flutter build macos --release
#   → build/macos/Build/Products/Release/Phone2PC.app   (drag to /Applications)

# Linux
cd apps/desktop && flutter build linux --release
#   → build/linux/x64/release/bundle/
```
*MSIX* is optional and needs the `msix` package, which is not in your dependency list – tell me if you want it and I'll add it.

## Tests

```bash
cd packages/shared && dart test          # sanitiser, tokens, multipart parser (split at every chunk size)
cd apps/desktop && flutter test          # real HTTP server on a socket: auth, streaming upload, duplicates,
                                         # traversal, truncated upload; real mobile ApiClient ↔ real server
                                         # (20 MB upload with progress, cancel, 401, unreachable)
```

## Notes / decisions

* **Dependencies**: only those you listed, plus `qr_flutter` (approved) for drawing the QR. `bonsoir` is used for mDNS on both sides. Flutter 3.50 moved Material into `material_ui`, which `flutter create` adds automatically.
* **History storage on mobile** uses `flutter_secure_storage` (capped at 200 entries) instead of Hive/Isar: Hive needs `path_provider`, which wasn't approved. Desktop keeps `settings.json` / `history.json` in the per-user app-data folder.
* **Arabic / RTL**: all UI strings exist in English and Arabic; layout direction and text direction of received content are handled (`directionFor`). Material's built-in widget strings (tooltips of framework widgets, date pickers) stay English because `flutter_localizations` wasn't approved.
* **Not implemented**: dragging items out of the desktop app (needs a drag-and-drop package), MSIX packaging, iOS share extension target (manual, above), single-instance lock on desktop.
* `tray_manager` / `window_manager` are used through their `legacy.dart` API (the 0.5.x-style API) because the newest releases moved the main API to nativeapi.
