# mc-config

<img width="256" height="256" alt="file_00000000b26071fab32f25a19aacd79b" src="https://github.com/user-attachments/assets/be8b8656-897c-4f98-957c-9c0f26a510b6" />

![GitHub License](https://img.shields.io/github/license/ruzen42/mc-config?style=plastic&color=red)
![GitHub Release](https://img.shields.io/github/v/release/ruzen42/mc-config?style=for-the-badge&color=red)

![GitHub watchers](https://img.shields.io/github/watchers/ruzen42/mc-config?style=for-the-badge&color=green)
![GitHub contributors](https://img.shields.io/github/contributors/ruzen42/mc-config?style=for-the-badge&color=red)

A lightweight CLI tool written in Haskell for managing and launching a [Purpur](https://purpurmc.org/) Minecraft server. It handles server configuration via a JSON file and can download any Purpur build directly 

## Features

- Launch a Minecraft server from a JSON config file (in future maybe replaced by a TOML/YAML/Dhall config)
- Auto-create a default config if none exists
- Interactively download any Purpur version from the official API
- CLI interface powered by `optparse-applicative`

## Usage

```

mc-config [-d|--download] [CONFIG]
```

| Flag / Argument     | Description                                              |
|---------------------|----------------------------------------------------------|
| `-g`, `--get-purpur`  | Fetch available Purpur versions and download one         |
| `CONFIG`            | Path to the config file (default: `./mine.cfg`)          |
| `-h`, `--help`      | Show help                                                |

### Run the server

```bash
# Use the default config (./mine.cfg)
mc-config --start

# Use a custom config path
mc-config --start /path/to/server.cfg
```

If the config file does not exist, you will be prompted to create one with sensible defaults.

### Download Purpur

```bash
mc-config --get-purpur
# or
mc-config -g
```

You will see a numbered list of all available versions:

```
Fetching version list...
1) 1.19.4
2) 1.20.1
3) 1.21.11
4) 26.1.2
...

Select version [1-N]: 3
Downloading purpur-1.21.11.jar...
Done: purpur-1.21.11.jar
```

The downloaded file is saved as `purpur-<version>.jar` in the current directory.

## Configuration

The config file is a JSON document. A default one is created automatically if missing.

```json
{
  "tmuxSession": "mc",
  "javaPath": "/usr/bin/java",
  "startRam": 2,
  "maxRam":   2,
  "jarPath":  "purpur-1.21.11.jar",
  "guiMode":  false,
  "options":  []
}
```

| Field       | Type       | Description                                      |
|-------------|------------|--------------------------------------------------|
| `javaPath`  | `string`   | Path to the Java executable                      |
| `startRam`  | `int`      | Initial heap size in GB (`-Xms`)                 |
| `maxRam`    | `int`      | Maximum heap size in GB (`-Xmx`)                 |
| `jarPath`   | `string`   | Path to the server `.jar` file                   |
| `guiMode`   | `bool`     | Start with server GUI (`false` adds `nogui`)     |
| `options`   | `[string]` | Extra JVM flags passed as `-XX:<flag>`           |

The resolved launch command looks like this:

```
/usr/bin/java -Xms2G -Xmx2G -jar purpur-1.21.11.jar nogui
```

## Building

Requires [GHC](https://www.haskell.org/ghc/) and [Cabal](https://www.haskell.org/cabal/) (or [Stack](https://docs.haskellstack.org/)).

```bash
cabal build
cabal install
```

### Dependencies

```
base, aeson, aeson-pretty, bytestring,
wreq, lens, directory, process, optparse-applicative
```

## Project Structure

```
mc-config/
├── Main.hs      — Entry point, CLI argument parsing
├── Config.hs    — Config type, JSON serialization, server launch
├── Install.hs   — Purpur API client, version download
└── mine.cfg     — Server config (auto-generated on first run)
```

## License

MIT
