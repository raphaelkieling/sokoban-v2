# Sokoban v2

A fantasy Sokoban puzzle where heroes use unique abilities to move blocks and reach each level's goals.

![Gameplay screenshot](docs/Screenshot%202026-10-18%20at%2005.20.01.png)

## Game

With [LÖVE](https://love2d.org/) installed:

```sh
love .
```

## Testing

With `lua` installed:

```sh
lua tests/run.lua
```

## Desktop builds

On macOS, with `curl`, `zip`, and `ditto` available:

```sh
./scripts/build-desktop.sh
```

This creates a Windows x64 folder/ZIP and a macOS `.app`/ZIP under `dist/desktop/`. To create only one platform, pass `windows` or `macos`.
