## nao1215/actions-ebitengine

This action sets up [ebitengine dependencies package](https://ebitengine.org/en/documents/install.html).
It's only for linux (ubuntu). If you use windows or mac, this action will be skipped.

### Example usage

```yaml
name: MultiPlatformUnitTest

on:
  workflow_dispatch:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  unit_test:
    name: Unit test (linux)

    strategy:
      matrix:
        os:
          - "ubuntu-latest"
          - "windows-latest"
          - "macos-latest"
        go:
          - "1"
          - "1.23"
      fail-fast: false
    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      - uses: nao1215/actions-ebitengine@v0

      - uses: actions/setup-go@v5
        with:
          go-version: ${{ matrix.go }}

      - name: Run tests with coverage report output
        run: go test -cover -coverpkg=./... -coverprofile=coverage.out ./...
```

### LICENSE

MIT LICENSE
