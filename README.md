# setup-ebitengine

[![GitHub Marketplace](https://img.shields.io/badge/GitHub%20Marketplace-setup--ebitengine-blue?logo=github)](https://github.com/marketplace/actions/setup-ebitengine) [![Test](https://github.com/nao1215/setup-ebitengine/actions/workflows/test.yml/badge.svg)](https://github.com/nao1215/setup-ebitengine/actions/workflows/test.yml)

GitHub Action to install the system packages [Ebitengine](https://ebitengine.org/) needs to build and run games.

On Linux it installs the OpenGL, X11 and ALSA development packages listed in the [Ebitengine install guide](https://ebitengine.org/en/documents/install.html) (apt on Ubuntu / Debian, dnf on Fedora containers), and optionally Xvfb so games and tests can run headless. macOS and Windows runners already have everything Ebitengine needs, so the action succeeds there without installing anything — you can use the same workflow on every OS.

## Quick start

```yaml
- uses: nao1215/setup-ebitengine@v0
- uses: actions/setup-go@v6
  with:
    go-version: stable
- run: go build ./...
```

## Run tests headless

Tests that open a window (or call `ebiten.RunGame`) need a display. On Linux, install Xvfb and wrap the command with `xvfb-run`:

```yaml
- uses: nao1215/setup-ebitengine@v0
  with:
    xvfb: true
- run: xvfb-run --auto-servernum go test ./...
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
      - uses: nao1215/setup-ebitengine@v0
      - uses: actions/setup-go@v6
        with:
          go-version: stable
      - run: go test ./...
```

## Inputs

| Name             | Default | Description                                                                  |
| ---------------- | ------- | ---------------------------------------------------------------------------- |
| `xvfb`           | `false` | Also install Xvfb on Linux, for `xvfb-run`.                                   |
| `extra-packages` | `""`    | Additional space-separated system packages to install on Linux.              |
| `apt-update`     | `true`  | Run `apt-get update` first on Debian / Ubuntu. Set `false` to skip it.       |

## Outputs

| Name              | Description                                                          |
| ----------------- | -------------------------------------------------------------------- |
| `packages`        | Space-separated list of installed packages (empty on macOS/Windows). |
| `package-manager` | `apt`, `dnf`, or `none` when nothing was needed.                     |

## Supported platforms

| Runner                                   | What the action does                         |
| ---------------------------------------- | -------------------------------------------- |
| Ubuntu / Debian (amd64, arm64)           | Installs the packages with `apt-get`.        |
| Fedora containers                        | Installs the packages with `dnf`.            |
| macOS (Apple silicon, Intel)             | Nothing to install.                          |
| Windows                                  | Nothing to install.                          |

The action uses `sudo` when it is not running as root, so it works both on GitHub-hosted runners and inside `container:` jobs.

## Migrating from actions-ebitengine

This repository used to be called `nao1215/actions-ebitengine`. The old name keeps working through GitHub's redirect, but new workflows should use `nao1215/setup-ebitengine`:

```diff
-      - uses: nao1215/actions-ebitengine@v0
+      - uses: nao1215/setup-ebitengine@v0
```

## Maintainer release flow

When you want to cut a new Marketplace release:

1. Run the `PrepareRelease` workflow from the Actions tab with `vX.Y.Z` (or `X.Y.Z`).
1. Open the draft GitHub release it creates, tick `Publish this Action to the GitHub Marketplace`, then publish it.
1. After publish, `SyncReleaseTags` automatically moves the floating `vX` and `vX.Y` tags (for example `v0` and `v0.1`) to that release.

That keeps the Marketplace listing current while preserving the immutable full release tag (`v0.1.1`, `v0.1.2`, ...).

## License

[MIT](./LICENSE) © CHIKAMATSU Naohiro
