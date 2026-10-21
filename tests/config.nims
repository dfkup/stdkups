switch("path", "$projectDir/../src")
# Heap contract with the dfkup host (see src/dfkup.nims in dfkup and
# `tools/build_shards.nim`): shard code is built `--threads:on --mm:arc`,
# so the test binaries linking it statically use the same flags.
switch("threads", "on")
switch("mm", "arc")
# `libhttp` passes its onRequest callback as a closure; supranim only
# accepts that when compiled with this define.
switch("define", "supranimUseGlobalOnRequest")
