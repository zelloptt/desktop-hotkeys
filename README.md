## desktop-hotkeys

Press/release callbacks for system-wide hotkeys on Windows and macOS.

## Installation

```
npm install --save @zelloptt/desktop-hotkeys
```

`npm install` runs `node-pre-gyp install --fallback-to-build`, which downloads
a prebuilt binary from the S3 host configured under `binary.host` in
`package.json`. If no matching prebuilt is found, the package builds from
source against the active Node runtime headers.

## Usage

A minimal working sample lives in `sample/`.

## Building prebuilts

The published prebuilts must be ABI-compatible with the runtime that loads
them. A binary built against Node headers and loaded inside Electron — even
when both share the same N-API version — can register hotkeys without error
yet silently drop key events on the JS callback path. Always rebuild and
republish prebuilts whenever the consumer's Electron major version changes.

To rebuild and publish prebuilts targeted at a specific Electron version,
set `ELECTRON_TARGET` and run the matching `make-electron*` script:

```
ELECTRON_TARGET=37.10.3 npm run make-electronM1   # darwin arm64
ELECTRON_TARGET=37.10.3 npm run make-electron64   # darwin / win32 x64
```

The `make` / `make64` / `makeM1` scripts retain their original Node-runtime
behaviour for any consumer still loading the module under plain Node.

Each release should re-publish prebuilts for every (platform, arch, runtime)
the consumer ships against. A consumer that downloads a prebuilt built for a
different runtime will load it without an error and may then hit the silent-
event-loss mode described above.
