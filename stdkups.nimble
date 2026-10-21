# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "dfkup standard library shards (nimble package)"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.2.0"
requires "vancode >= 0.2.14"
requires "openparser >= 0.3.10"
# Build-only: shard wrappers import dfkup's lang/transformers first
# (voodoo NodeKind extension), so voodoo must resolve wherever shards
# are compiled. No shard module imports it directly.
requires "voodoo >= 0.2.3"
requires "marvdown >= 0.2.4"
requires "supranim >= 0.1.11"
requires "blackpaper >= 0.2.0"
requires "nimcypher >= 0.2.5"
requires "twofa >= 0.1.0"
requires "powpow >= 0.2.2"
requires "chopchop >= 0.1.0"
requires "chachachat >= 0.1.0"
requires "bigints >= 1.0.0"
