## Compile check: every shard module that needs no host sources must
## compile standalone against the dependencies in stdkups.nimble.
## (`libllm` is excluded: it uses the host's `lang/parser` via
## `compileutils`, so it only compiles with a dfkup checkout on `--path`.
## It is compile-verified by the shard build in the test workflow.)
import unittest

import stdkups/libalgos
import stdkups/libbench
import stdkups/libbrowser
import stdkups/libbson
import stdkups/libcli
import stdkups/libcolors
import stdkups/libconfig
import stdkups/libcss
import stdkups/libcsv
import stdkups/libdotenv
import stdkups/libfeed
import stdkups/libfswatch
import stdkups/libhttp
import stdkups/libhttpclient
import stdkups/libical
import stdkups/libjson
import stdkups/libmarkdown
import stdkups/libnanoid
import stdkups/libqr
import stdkups/libregex
import stdkups/libsequtils
import stdkups/libstrings
import stdkups/libstrongpwd
import stdkups/libsvg
import stdkups/libtoml
import stdkups/libtwofa
import stdkups/libuuid
import stdkups/libxml
import stdkups/libyaml

suite "shard modules":
  test "all host-independent modules compile":
    check true
