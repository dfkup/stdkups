# StdKups - dfkup standard library shards
#
# (c) 2026 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://dfkup.dev

## dfkup's standard library as an importable nimble package.
##
## Most `std/<name>` modules live here as `stdkups/lib<name>` and ship to
## users as `libdfkup_<name>` dylib shards built with
## `tools/build_shards.nim` (invoked from the GitHub workflows, which
## also supply `--dfkup-src` for the host sources the wrappers need).
## Five modules are owned by dfkup itself and always linked into the
## host binary instead (`system`, `json`, `strings`, `sequtils` and
## `regex`, under dfkup's `lang/lowlibs`): they are not shards and are
## not listed here.
##
## Import submodules directly, e.g. `import stdkups/libyaml`.
## Plain submodule imports need no host sources, with one exception:
## `libllm` pulls in `compileutils`, which uses the host's
## `lang/parser` (dfkup checkout on `--path`).
