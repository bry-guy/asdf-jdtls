# asdf-jdtls

[Eclipse JDTLS](https://github.com/eclipse-jdtls/eclipse.jdt.ls) plugin for [asdf](https://asdf-vm.com) and [mise](https://mise.jdx.dev).

## Status

This plugin installs published JDTLS milestone releases directly from Eclipse downloads and works with both asdf and mise.

It supports:
- exact JDTLS versions, e.g. `1.40.0`
- `latest`
- compatibility aliases:
  - `latest-java17`
  - `latest-java21`
  - `latest-compatible`

## Install

### asdf

```bash
asdf plugin add jdtls https://github.com/bry-guy/asdf-jdtls.git
```

### mise

```bash
mise plugin install jdtls https://github.com/bry-guy/asdf-jdtls.git
```

## Usage

### Install an exact version

```bash
asdf install jdtls 1.40.0
mise install jdtls@1.40.0
```

### Install the newest published version

```bash
asdf install jdtls latest
mise install jdtls@latest
```

### Install the newest compatible version for a Java runtime

```bash
asdf install jdtls latest-java17
asdf install jdtls latest-java21
asdf install jdtls latest-compatible

mise install jdtls@latest-java17
mise install jdtls@latest-java21
mise install jdtls@latest-compatible
```

### Activate it

```bash
asdf global jdtls 1.40.0
mise use -g jdtls@1.40.0
```

Then run:

```bash
jdtls
```

## Java compatibility

JDTLS has its own launcher runtime requirements, and they change over time.

This plugin currently uses the following compatibility rules:

- `0.x` releases: Java 11+
- `1.0.0` through `1.54.x`: Java 17+
- `1.55.0+`: Java 21+

Notes:
- `latest` always means the newest published JDTLS release.
- `latest-compatible` detects the current `java` / `JAVA_HOME` runtime and installs the newest compatible JDTLS version.
- exact version installs are still allowed even if your current Java is too old; the plugin warns, but the install completes.
- compatibility aliases fail fast if the detected Java runtime is too old.

## Download verification

When Eclipse publishes a `.sha256` file next to a release archive, the plugin verifies it automatically.

## Development

Run the local tests with:

```bash
bash test/utils.bash
```

## Repository structure

```text
.
├── bin
│   ├── download
│   ├── install
│   ├── jdtls
│   └── list-all
├── lib
│   └── utils.bash
└── test
    └── utils.bash
```

## License

See [LICENSE.md](LICENSE.md).
