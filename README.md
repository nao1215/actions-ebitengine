# setup-ebitengine

[![GitHub Marketplace](https://img.shields.io/badge/GitHub%20Marketplace-setup--ebitengine-blue?logo=github)](https://github.com/marketplace/actions/setup-ebitengine) [![Test](https://github.com/nao1215/setup-ebitengine/actions/workflows/test.yml/badge.svg)](https://github.com/nao1215/setup-ebitengine/actions/workflows/test.yml)

GitHub Action to install the system packages [Ebitengine](https://ebitengine.org/) needs.

On Linux it installs the runtime libraries listed in the [Ebitengine install guide](https://ebitengine.org/en/documents/install.html). On macOS and Windows there is nothing to install.

## Quick start

```yaml
- uses: nao1215/setup-ebitengine@v1
- uses: actions/setup-go@v6
  with:
    go-version: stable
- run: go build ./...
```

## Run tests headless

Tests that open a window (or call `ebiten.RunGame`) need a display. On Linux, install Xvfb and wrap the command with `xvfb-run`:

```yaml
- uses: nao1215/setup-ebitengine@v1
  with:
    xvfb: true
- run: xvfb-run --auto-servernum go test ./...
```

## Build with cgo

For cgo builds or Ebitengine before v2.10:

```yaml
- uses: nao1215/setup-ebitengine@v1
  with:
    dev: true
```

## Cross-platform matrix

```yaml
jobs:
  test:
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v6
      - uses: nao1215/setup-ebitengine@v1
      - uses: actions/setup-go@v6
        with:
          go-version: stable
      - run: go test ./...
```

## Inputs

| Name             | Default | Description                                                                  |
| ---------------- | ------- | ---------------------------------------------------------------------------- |
| `dev`            | `false` | Also install a C compiler and the headers on Linux (cgo builds).             |
| `xvfb`           | `false` | Also install Xvfb on Linux, for `xvfb-run`.                                   |
| `extra-packages` | `""`    | Additional space-separated system packages to install on Linux.              |
| `apt-update`     | `true`  | Run `apt-get update` first on Debian / Ubuntu. Set `false` to skip it.       |

## Outputs

| Name              | Description                                                          |
| ----------------- | -------------------------------------------------------------------- |
| `packages`        | Space-separated list of installed packages (empty on macOS/Windows). |
| `package-manager` | `apt`, `dnf`, `pacman`, `apk`, `xbps`, `eopkg`, or `none` when nothing was needed. |

## Supported platforms

| Runner                                   | What the action does                         |
| ---------------------------------------- | -------------------------------------------- |
| Ubuntu / Debian (amd64, arm64)           | Installs the packages with `apt-get`.        |
| Fedora containers                        | Installs the packages with `dnf`.            |
| Arch containers                          | Installs the packages with `pacman`.         |
| Alpine containers                        | Installs the packages with `apk`.            |
| Void containers                          | Installs the packages with `xbps-install`.   |
| Solus                                    | Installs the packages with `eopkg` (no `dev`, no `xvfb`). |
| macOS (Apple silicon, Intel)             | Nothing to install.                          |
| Windows                                  | Nothing to install.                          |

The action uses `sudo` when it is not running as root, so it works both on GitHub-hosted runners and inside `container:` jobs.

## Migrating from actions-ebitengine

This repository used to be `nao1215/actions-ebitengine`. The `v0` tag keeps the old behavior. Use `v1`, and add `dev: true` if you build with cgo:

```diff
-      - uses: nao1215/actions-ebitengine@v0
+      - uses: nao1215/setup-ebitengine@v1
```

## Maintainer release flow

When you want to cut a new Marketplace release:

1. Run the `PrepareRelease` workflow from the Actions tab with `vX.Y.Z` (or `X.Y.Z`).
1. Open the draft GitHub release it creates, tick `Publish this Action to the GitHub Marketplace`, then publish it.
1. After publish, `SyncReleaseTags` automatically moves the floating `vX` and `vX.Y` tags (for example `v1` and `v1.0`) to that release.

That keeps the Marketplace listing current while preserving the immutable full release tag (`v1.0.0`, `v1.0.1`, ...).

## License

[MIT](./LICENSE) © CHIKAMATSU Naohiro
