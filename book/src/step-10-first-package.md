# Step 10 — the first package built by your stdenv

**File to write:** `lfs-stdenv/hello/default.nix`, attribute `hello`

**Do:** build GNU hello with `lfsStdenv.mkDerivation`. Use `lfsStdenv.fetchurlBoot`
or `pkgs.fetchurl` for the source (a fixed-output derivation; both are fine).

**Verify:**

```console
$ nix build .#hello -o result-hello -L
$ result-hello/bin/hello                           # Hello, world!
$ $B/$T-readelf -l result-hello/bin/hello | grep interpreter
                                                   # /nix/store/...-lfs-temp-glibc-2.40/lib/ld-linux-aarch64.so.1
$ $B/$T-readelf -d result-hello/bin/hello | grep RUNPATH
                                                   # the lfs-temp-glibc lib directory
$ $B/$T-readelf -p .comment result-hello/bin/hello # GCC: (GCC) 14.2.0  (lfs-temp-gcc)
$ nix path-info -r ./result-hello                  # hello + lfs-temp-glibc, nothing else
$ nix-store -q --references $(nix eval --raw .#hello.drvPath)
                                                   # lfs-stdenv, lfs-temp-bash, the source, setup hooks:
                                                   # no nixpkgs gcc and no nixpkgs glibc
$ LD_DEBUG=libs result-hello/bin/hello 2>&1 | grep -E 'search cache|trying file'
                                                   # see the note below
```

The `LD_DEBUG` check can show `search cache=/etc/ld.so.cache`. Your glibc reads
the cache of the Ubuntu VM at run time. That is a runtime leak. nixpkgs fixes it
with `dont-use-system-ld-so-cache.patch` in
`pkgs/development/libraries/glibc/`. Apply it to the glibc in step 11.

**Nix concepts:** [build-time and runtime closure](appendix-nix-concepts.md#references-and-closures),
[`.drv` files](appendix-nix-concepts.md#evaluation-and-build).
