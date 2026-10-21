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
- `tools/build_shards.py` — shard build script (workflow entry point).
- `tests/test_modules.nim` — compile check for every module.

## Building shards

Shards are built at workflow level (no nimble task). The build needs a
dfkup checkout for the host sources (`lang/transformers`,
`lang/parser`):

```sh
python3 tools/build_shards.py --dfkup-src ../dfkup --out ../dfkup/bin/stdlib
```

`--lock` points at a `clue.lock` with resolved dependency paths
(dfkup's lock when run from dfkup CI, the package's own lock here).

## Notes

- Plain `import stdkups/lib<name>` needs no host sources, except
  `libllm` (via `compileutils`, which uses the host's `lang/parser`).
  `tests/test_modules.nim` therefore covers the 29 host-independent
  modules; `libllm` is compile-verified by the shard build itself.
- Heap contract: shards and host share `--threads:on --mm:arc`
  (see `tools/build_shards.py`); exceptions never cross the dylib
  boundary (in-image guard re-raises through the host sink).

## License

MIT license. Made by Humans from OpenPeeps.
