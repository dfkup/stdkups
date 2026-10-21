# StdKups - dfkup standard library shards
#
# (c) 2026 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://dfkup.dev

## dfkup's standard library as an importable nimble package.
##
## Every `std/<name>` module (except `system`, which stays statically
## linked in the dfkup host binary) lives here as `stdkups/lib<name>`
## and ships to users as a `libdfkup_<name>` dylib shard built with
## `tools/build_shards.py` (invoked from the GitHub workflows, which
## also supply `--dfkup-src` for the host sources the wrappers need).
##
## Import submodules directly, e.g. `import stdkups/libjson`.
## Plain submodule imports need no host sources, with one exception:
## `libllm` pulls in `compileutils`, which uses the host's
## `lang/parser` (dfkup checkout on `--path`).
