# `libhttp` passes its onRequest callback as a closure; supranim only
# accepts that when compiled with this define (dfkup sets it globally
# in src/dfkup.nims; the shard build passes it as -d: as well).
--define:supranimUseGlobalOnRequest
