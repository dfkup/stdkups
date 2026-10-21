# stdkups

dfkup's standard library as a nimble package. Every `std/<name>` module
(except `system`, which stays statically linked in the dfkup host binary)
lives here as `stdkups/lib<name>` and ships to users as a
`libdfkup_<name>` dylib shard loaded on first `import "std/<name>"`.

## Layout

- `src/stdkups/` — the 30 shard modules plus `compileutils.nim`
  (shared `compileCode` helper, re-exported by dfkup's `libsystem`).
- `src/stdkups.nim` — package root (documentation only).
- `tools/stdlib_plugin.tmpl` — dylib wrapper template.
- `tools/build_shards.nim` — dylib shard builder (workflow entry point).
- `tests/test_modules.nim` — compile check for every module.

## Build Standard Library

Shards are built at workflow level (no nimble task). The build needs the
dfkup sources (`lang/transformers`, `lang/parser`); `build_shards`
finds them via `--dfkup-src`, a nearby checkout, or the dfkup package
itself (`clue install dfkup --build`). Plain `nim c -r`, std-only
imports:

```sh
nim c -r tools/build_shards.nim --dfkup-src ../dfkup --out ../dfkup/bin/stdlib
```

`--lock` points at a `clue.lock` with resolved dependency paths
(dfkup's lock when run from dfkup CI, the package's own lock here).

## Notes

- Plain `import stdkups/lib<name>` needs no host sources, except
  `libllm` (via `compileutils`, which uses the host's `lang/parser`).
  `tests/test_modules.nim` therefore covers the 29 host-independent
  modules; `libllm` is compile-verified by the shard build itself.
- Heap contract: shards and host share `--threads:on --mm:arc`
  (see `tools/build_shards.nim`); exceptions never cross the dylib
  boundary (in-image guard re-raises through the host sink).

## License

MIT license. Made by Humans from OpenPeeps.
