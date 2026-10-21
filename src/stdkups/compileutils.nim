# StdKups - dfkup standard library shards
#
# (c) 2026 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://dfkup.dev

## Shared helpers for stdkups shard modules.
##
## `compileCode` parses and compiles inline dfkup source at init time for
## the `llm` shard's coroutine helpers. dfkup carries its own independent
## copy (`src/lang/compileutils.nim`, used by `libsystem`); the two are
## deliberately duplicated so neither package depends on the other.

import std/options
import pkg/vancode/interpreter/[ast, codegen, chunk, sym, value]

# `parseScript` lives in the host package (dfkup `lang/parser`). Shard
# builds always pass `--path` to the dfkup checkout (see
# `tools/build_shards.sh --dfkup-src`), so this import resolves there.
# Plain `import stdkups/<lib>` use of the other 29 modules needs no
# host sources at all; only modules pulling in `compileutils`
# (currently just `libllm`) do.
import lang/parser

proc compileCode*(script: Script, module: Module, code: string) =
  ## Parse and compile inline dfkup source into the given script and module.
  var astProgram: Ast
  try:
    parseScript(astProgram, code)
  except DfkupParserError:
    return
  var gen = initCodeGen(script, module, script.mainChunk)
  gen.genScript(astProgram, none(string), emitHalt = false)
