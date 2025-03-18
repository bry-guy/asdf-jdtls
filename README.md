# asdf-jdtls

[Eclipse JDTLS](https://github.com/eclipse/eclipse.jdt.ls) plugin for asdf version manager (and mise)


# asdf-jdtls

[![Build](https://github.com/yourusername/asdf-jdtls/actions/workflows/build.yml/badge.svg)](https://github.com/yourusername/asdf-jdtls/actions/workflows/build.yml)

[Eclipse JDTLS](https://github.com/eclipse/eclipse.jdt.ls) plugin for the [asdf version manager](https://asdf-vm.com) and [mise](https://github.com/jdx/mise).

## Install

### asdf

```bash
asdf plugin add jdtls https://github.com/yourusername/asdf-jdtls.git
```

### mise

```bash
mise plugin install jdtls https://github.com/yourusername/asdf-jdtls.git
# Or in .mise.toml
# [plugins.jdtls]
# plugin_url = "https://github.com/yourusername/asdf-jdtls.git"
```

## Usage

### asdf

```bash
# Install latest version
asdf install jdtls latest

# Set global version
asdf global jdtls latest

# Run JDTLS
jdtls
```

### mise

```bash
# Install latest version 
mise install jdtls@latest

# Set global version
mise global jdtls@latest

# Run JDTLS
jdtls
```

## Configuration

The JDTLS wrapper supports the following environment variables:

- `JDTLS_CONFIG_DIR`: Custom configuration directory
- `JDTLS_DATA_DIR`: Custom data directory
- `JDTLS_JAVA_OPTS`: Additional Java options

## Structure

```
.
├── bin
│   ├── download
│   ├── install
│   ├── list-all
│   └── jdtls (wrapper script)
└── lib
    └── utils.bash
```

## License

See [LICENSE](LICENSE) © [Your Name](https://github.com/yourusername/)
