# Soniq iOS

iPhone version of [Soniq](https://github.com/don12335/Soniq). This repo is only the Capacitor iOS shell and the build workflow; the app itself (React UI, player, mobile layout) lives in the Soniq repo and is built with `pnpm build:ios`.

## Install

Download `Soniq-<version>.ipa` from [Releases](https://github.com/don12335/Soniq-iOS/releases) and sideload it. The IPA is unsigned (ad-hoc signed), so use one of:

- **Sideloadly** or **AltStore / AltServer** (Windows or Mac) with your Apple ID. With a free Apple ID the app expires after 7 days and has to be re-signed.
- **TrollStore** installs it permanently on supported iOS versions.

Requires **iOS 16.4 or later**.

## Build

GitHub Actions builds the IPA on macOS (`.github/workflows/build-ipa.yml`):

- Every push to `main` builds the Soniq branch/tag named in `SONIQ_REF` (empty file: newest `v*` tag).
- **Run workflow** manually, optionally with a Soniq branch or tag.
- Push a tag `vX.Y.Z` to build Soniq `vX.Y.Z` and attach the IPA to a release. iOS revision tags such as `vX.Y.Z-ios.N` build the branch or tag in `SONIQ_REF`.

The app version is Soniq's `package.json` version; the build number is the workflow run number.

## Transfer personal data

On either device, open Settings → Storage → Move data between devices. Export a JSON backup, send it through Files, AirDrop or another file transfer method, then import it on the other device. Likes, collections, playlists, listening history, recommendations and search history merge without deleting either device's existing data. Music files and temporary caches are not included.

Local steps (the Xcode part needs a Mac):

```sh
npm install
SONIQ_DIR=../../desktop-merged npm run build:web   # pnpm build:ios in Soniq, copy dist-mobile -> web/
npx cap sync ios
```

## Notes

- Keep `appId` and the default `capacitor://localhost` origin unchanged: the library, history and audio cache live in that origin's storage.
- `CapacitorHttp` is disabled in `capacitor.config.ts` on purpose. Soniq installs its own fetch wrapper (`src/shared/platform/native/nativeFetch.ts`) that calls CapacitorHttp with the per-host headers YouTube needs.
- `AppDelegate.swift` sets the audio session to `.playback` and `Info.plist` enables the `audio` background mode, for lock-screen and background playback.
