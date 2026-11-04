# Step 11 — rebuild everything with itself

**Files to write:** `lfs-final/<package>/default.nix` for each package, and
`lfs-final/default.nix`. Import it in `flake.nix` as `final`.

**Goal:** a stdenv in which no package was built by a host compiler, and in
which no program is static.

## Why build everything again

The packages of steps 7 and 8 work, but each one has a mark of the host:

- gcc stage 2 built them, and the host gcc built gcc stage 2.
- They are static, or they use `lfs-temp-glibc`. That glibc reads the
  `/etc/ld.so.cache` of the host (step 10).
- The wrappers of `lfsStdenv` use the nixpkgs coreutils, grep and bash
  (steps 9 and 10).

In this step, your own tools build every package again. Do it in stages, as
nixpkgs does. Each stage uses only the results of the stage before it.

| Stage | Built with | Builds |
|---|---|---|
| 1 | `lfsStdenv` | `lfs-final-glibc` |
| 2 | `lfsStdenv1`: `lfsStdenv` with `libc = final.glibc` in both wrappers | `lfs-final-binutils`, `lfs-final-gcc` |
| 3 | `lfsStdenv2`: the wrappers around `final.binutils` and `final.gcc`, with `final.glibc` | The 14 tools of step 7, as `lfs-final-*` |
| 4 | `lfsStdenvFinal`: only `lfs-final-*` packages | `lfs-final-hello` (`helloFinal`) |

Stage 3 uses the final gcc, not the temporary gcc. `patchelf` is C++, and it
links `libstdc++` from the gcc that builds it. With the temporary gcc, the
runtime closure gets `lfs-temp-gcc`.

## The packages

| # | Stage | Attribute | Version | Start from | What to change |
|---|---|---|---|---|---|
| 1 | 1 | `final.glibc` | 2.40 | `lfs-temp/glibc` | See "Stage 1" below. This page shows the full file. |
| 2 | 2 | `final.binutils` | 2.43 | `lfs-temp/binutils` | Remove `preBuild` and `LDFLAGS=-all-static`. Give `--build`, `--host` and `--target`, all `${triple}`. |
| 3 | 2 | `final.gcc` | 14.2.0 | `lfs-temp/gcc` | Give `--build`, `--host` and `--target`, all `${triple}`. Use `final.glibc` in `--with-native-system-header-dir` and `--with-glibc-version`. Remove `CXX_FOR_BUILD` and `LDFLAGS_FOR_BUILD`. Keep the patch and the gmp, mpfr and mpc sources. |
| 4 | 3 | `final.gnumake` | 4.4.1 | `lfs-temp/gnumake` | No change. |
| 5 | 3 | `final.coreutils` | 9.5 | `lfs-temp/coreutils` | Remove `stdbuf` from the `no-install` list, and remove `gl_cv_func_working_mktime`. |
| 6 | 3 | `final.bash` | 5.2.32 | `lfs-temp/bash` | Remove `CC_FOR_BUILD` and `bash_cv_strtold_broken`. Keep `-fpermissive` and the `sh` link. |
| 7 | 3 | `final.gnused` | 4.9 | `lfs-temp/gnused` | No change. |
| 8 | 3 | `final.gnugrep` | 3.11 | `lfs-temp/gnugrep` | No change. |
| 9 | 3 | `final.gawk` | 5.3.0 | `lfs-temp/gawk` | No change. |
| 10 | 3 | `final.findutils` | 4.10.0 | `lfs-temp/findutils` | Remove `gl_cv_func_working_mktime`. |
| 11 | 3 | `final.diffutils` | 3.10 | `lfs-temp/diffutils` | Remove `gl_cv_func_working_mktime`. |
| 12 | 3 | `final.gnupatch` | 2.7.6 | `lfs-temp/gnupatch` | Remove `gl_cv_func_working_mktime`. |
| 13 | 3 | `final.gnutar` | 1.35 | `lfs-temp/gnutar` | Remove `gl_cv_func_working_mktime`. |
| 14 | 3 | `final.gzip` | 1.13 | `lfs-temp/gzip` | No change. |
| 15 | 3 | `final.xz` | 5.6.2 | `lfs-temp/xz` | Remove `--disable-shared` and `LDFLAGS=-all-static`. |
| 16 | 3 | `final.bzip2` | 1.0.8 | `lfs-temp/bzip2` | Keep only `PREFIX=$(out)` in `makeFlags`. |
| 17 | 3 | `final.patchelf` | 0.18.0 | `lfs-temp/patchelf` | No change. Keep the `setupHook`. |
| 18 | 4 | `helloFinal` | 2.12.3 | `lfs-stdenv/hello` | Only the `pname`: `lfs-final-hello`. |

The sources and hashes are the same as in steps 7, 8 and 10.

**The rules behind the table.** Use them when a package fails:

- **Remove each setting for a static build:** `LDFLAGS=-static`,
  `-all-static`, `--disable-shared`, and the `stdbuf` exclusion (step 7,
  reasons 1 and 7).
- **Remove each setting for a cross build:** `--host` and `--build` from
  `mkTemp`, the `PATH` and `unset` lines, the cache variables such as
  `gl_cv_func_working_mktime=yes`, and `CC_FOR_BUILD`. Now configure can run
  its test programs.
- **Keep each setting that stops a stored path.** `SHELL=/bin/sh` and the
  `ac_cv_path_*` variables (step 7, reasons 5 and 6) are still necessary. If
  you remove them, the scripts store a path into `lfs-temp-*`. Item 5 of
  "Stages 2 to 4" finds this.
- **Keep the LFS settings.**

Do not use `mkTemp`. Write a smaller helper, or use `stdenv.mkDerivation`
directly. Set `pname = "lfs-final-<name>"`.

The first package, glibc, is built and checked. The other rows of the table
follow from steps 7, 8 and 10, but they are not built yet.

## Stage 1 — `lfs-final-glibc`

**File to write:** `lfs-final/glibc/default.nix`, attribute `final.glibc`

**Goal:** a glibc built by your gcc, that does not read the loader cache of
the host, and that has no reference to `lfs-temp-glibc`.

**Do:**

1. Write `lfs-final/glibc/default.nix`:

   ```nix
   { stdenv, fetchurl, bison, python3, perl, headers }:

   stdenv.mkDerivation rec {
     pname = "lfs-final-glibc";
     version = "2.40";

     src = fetchurl {
       url = "mirror://gnu/glibc/glibc-${version}.tar.xz";
       hash = "sha256-GaiQF16SY9dI9ieZPeb0sa+c0h4D8IDkv7Oh+sECBaI=";
     };

     patches = [
       (fetchurl {
         url = "https://raw.githubusercontent.com/NixOS/nixpkgs/acdcb8566ae560752a8a1ce3aacc617a3da6cdd5/pkgs/development/libraries/glibc/dont-use-system-ld-so-cache.patch";
         hash = "sha256-tsJKNF7QB3q+RvPlCWh7GKb2nECEESd4gwNjCjkespE=";
       })
     ];

     nativeBuildInputs = [ bison python3 perl ];

     hardeningDisable = [ "fortify" "stackprotector" "strictflexarrays3" ];
     env = {
       NIX_NO_SELF_RPATH = true;
       BASH_SHELL = "/bin/sh";
     };

     preConfigure = "mkdir -p build && cd build";
     configureScript = "../configure";
     configureFlags = [
       "--enable-kernel=4.19"
       "--with-headers=${headers}/usr/include"
       "--disable-nscd"
       "--enable-stack-protector=strong"
     ];

     postConfigure = "export NIX_DONT_SET_RPATH=1";
     makeFlags = [ "BUILD_LDFLAGS=-Wl,-rpath,${stdenv.cc.libc}/lib" ];

     postInstall = ''
       rm -f $out/etc/ld.so.cache
       for d in ${headers}/usr/include/*; do
         [ "$(basename $d)" = scsi ] || cp -r $d $out/include/
       done
     '';
   }
   ```

   Compare it with `lfs-temp/glibc/default.nix` (step 8a):

   | Temp file | Final file | Why |
   |---|---|---|
   | `--host`, `--build`, the `PATH` and `unset` lines | removed | `lfsStdenv` gives `gcc`, `ld` and the other tools. This build is native. |
   | `CFLAGS` with `-fdebug-prefix-map`, `dontStrip`, `dontPatchELF` | removed | The strip of `lfsStdenv` removes the debug information, so no store path stays in it. |
   | — | `patches` | See "The loader cache" below. |
   | — | `hardeningDisable` | The cc-wrapper adds `-D_FORTIFY_SOURCE` and `-fstack-protector-strong` to every compile. glibc cannot compile its own loader with them. glibc sets them for each file itself. nixpkgs disables the same three flags. |
   | — | `--enable-stack-protector=strong` | glibc adds the stack protector to each file that can have it. This replaces the flag that `hardeningDisable` removes. nixpkgs uses the same flag. |
   | — | `NIX_NO_SELF_RPATH` | The ld-wrapper adds `-rpath $out/lib` to each link. glibc does not need it. |
   | — | `BASH_SHELL = "/bin/sh"` | configure finds `bash` on `PATH`, and writes its path into scripts. That path is `lfs-temp-bash`. |
   | — | `postConfigure`, `makeFlags` | See "The rpath" below. |
   | `postInstall`: copy the headers | the same, plus `rm -f $out/etc/ld.so.cache` | `make install` runs `ldconfig`, which writes a cache. The patched loader reads `$out/etc/ld.so.cache`. Remove the file, as nixpkgs does. |

   `bison`, `python3` and `perl` come from nixpkgs. They run only during the
   build, and the result has no reference to them. Part 4 uses the same rule.

2. Write `lfs-final/default.nix`:

   ```nix
   { pkgs, toolchain, lfsStdenv }:

   rec {
     # Stage 1: built by lfsStdenv.
     glibc = pkgs.callPackage ./glibc { stdenv = lfsStdenv; inherit (toolchain) headers; };
   }
   ```

   Add the next stages to the same `rec` set. Stage 2 needs `lfsStdenv1`,
   which uses `glibc`.

3. Import it in `flake.nix`, next to `hello`:

   ```nix
   final = import ./lfs-final { inherit pkgs toolchain lfsStdenv; };
   ```

   Use the name `final`. If you merge the set at the top, `final.glibc`
   replaces the `glibc` of step 4. Later steps use `.#lfsStdenvFinal` and
   `.#helloFinal`. When you write them, add
   `inherit (final) lfsStdenvFinal helloFinal;` to `flake.nix`.

4. Make git track the new files:

   ```console
   $ git add lfs-final
   ```

### The loader cache

Step 10 showed that `lfs-temp-glibc` reads `/etc/ld.so.cache`. That file
belongs to the host. The patch changes the path to `$out/etc/ld.so.cache`.

The file `dont-use-system-ld-so-cache.patch` in your pinned nixpkgs is for
glibc 2.44. One hunk does not apply to glibc 2.40:

```
patching file elf/ldconfig.c
Hunk #1 FAILED at 48.
```

The new hunk changes `TUNABLES_CONF`, which glibc 2.40 does not have. Use the
older version of the patch. It has not changed since nixpkgs commit
[acdcb85](https://github.com/NixOS/nixpkgs/commit/acdcb8566ae560752a8a1ce3aacc617a3da6cdd5).
NixOS 24.11 used it with glibc 2.40. A URL with a commit hash does not change.
Use a branch name only to find the file, because a branch moves.

Test the patch before the build, as in step 8c:

```console
$ P=$(nix store prefetch-file --json https://raw.githubusercontent.com/NixOS/nixpkgs/acdcb8566ae560752a8a1ce3aacc617a3da6cdd5/pkgs/development/libraries/glibc/dont-use-system-ld-so-cache.patch | sed 's/.*"storePath":"\([^"]*\)".*/\1/')
$ cd $(mktemp -d) && tar xf $(nix eval --raw /work#temp.glibc.src.outPath) && cd glibc-2.40
$ nix shell /work#temp.gnupatch -c patch -p1 --dry-run < $P
checking file elf/Makefile
Hunk #1 succeeded at 1463 with fuzz 2 (offset 794 lines).
checking file elf/dl-diagnostics.c
checking file elf/ldconfig.c
Hunk #1 succeeded at 48 with fuzz 1 (offset -9 lines).
checking file sysdeps/generic/dl-cache.h
```

`prefetch-file` also prints the `hash` for the `fetchurl`. Fuzz is correct
here: `patch` ignored one or two lines of context that changed. The
`--list-diagnostics` check in "Verify" shows that the patch worked.

### The rpath

The ld-wrapper adds `-rpath <dir>` for each directory that contains a library
of the link. The wrapper of `lfsStdenv` links with `lfs-temp-glibc`, so each
library of the new glibc gets `RUNPATH: ...-lfs-temp-glibc-2.40/lib`. The
patchelf hook does not remove it: that directory contains `libc.so.6`, and the
libraries need `libc.so.6`. Then the closure has `lfs-temp-glibc`.

nixpkgs does two things, and this file does the same:

- `export NIX_DONT_SET_RPATH=1` after configure. The ld-wrapper then adds no
  rpath. The configure tests run before it and link as usual.
- `BUILD_LDFLAGS=-Wl,-rpath,${stdenv.cc.libc}/lib`. Some programs of the glibc
  build run during the build. They use `lfs-temp-glibc`, and they need the
  rpath. They are not installed.

A glibc does not need an rpath. Its loader finds its own libraries in
`$out/lib`, the system search path.

## Verify

```console
$ nix build .#final.glibc -o result-final-glibc -L      # about 4 minutes
$ nix path-info -r ./result-final-glibc                 # ONE line: lfs-final-glibc
$ $B/$T-readelf -d result-final-glibc/lib/gconv/ISO8859-1.so | grep -E 'NEEDED|R(UN)?PATH'
                                                        # NEEDED libc.so.6 and ld-linux-aarch64.so.1, no RUNPATH
$ $B/$T-readelf -l result-final-glibc/bin/iconv | grep interpreter
                                                        # ...-lfs-final-glibc-2.40/lib/ld-linux-aarch64.so.1
$ $B/$T-readelf -p .comment result-final-glibc/lib/libc.so.6    # GCC: (GNU) 14.2.0
$ result-final-glibc/lib/libc.so.6 | head -1            # GNU C Library (GNU libc) stable release version 2.40.
$ result-final-glibc/lib/ld-linux-aarch64.so.1 --list-diagnostics | grep -E 'path\.(prefix|sysconfdir)'
                                                        # both in ...-lfs-final-glibc-2.40, not /etc
$ ls result-final-glibc/etc                             # rpc (no ld.so.cache)
$ echo hello | result-final-glibc/bin/iconv -f UTF-8 -t ISO-8859-1    # hello
$ LD_DEBUG=libs result-final-glibc/bin/iconv -l 2>&1 | grep -E 'search|trying' | head -4
                                                        # search cache=...-lfs-final-glibc-2.40/etc/ld.so.cache
                                                        # search path=...-lfs-final-glibc-2.40/lib (system search path)
```

| Check | It proves |
|---|---|
| `nix path-info -r` | No file stores a path of `lfs-temp-glibc`, `lfs-temp-bash` or the kernel headers. |
| `RUNPATH` | `NIX_DONT_SET_RPATH` worked. |
| `interpreter` | The programs of the new glibc use the new loader. |
| `--list-diagnostics` | The patch worked: the configuration directory is `$out/etc`. |
| `LD_DEBUG` | `iconv` has no `RUNPATH`, so the loader tries its cache first. The cache path is in the store, and the file does not exist. Then the loader uses its own `lib`. The cache of the host is not read. |

**If it fails:**

- `Hunk #1 FAILED at 48` in `elf/ldconfig.c`: the patch is the version of the
  pinned nixpkgs. Use the URL with the commit hash.
- `_FORTIFY_SOURCE` or `stack protector` errors when the loader compiles: the
  `hardeningDisable` line is missing.
- `nix path-info -r` shows `lfs-temp-glibc`: find the file with
  `grep -rl <hash> result-final-glibc`. If it is a library with a
  `RUNPATH`, check the `postConfigure` line.
- `nix path-info -r` shows `lfs-temp-bash`: check `BASH_SHELL`.

## Stages 2 to 4

**Do:**

1. `lfsStdenv1`: the same as `lfsStdenv`, but with `libc = final.glibc` in
   both wrappers. Build `final.binutils` and `final.gcc` with it.
2. `lfsStdenv2`: the same as `lfsStdenv1`, but the wrappers wrap
   `final.binutils` and `final.gcc`. Build the 14 tools with it.
3. `lfsStdenvFinal`: like step 9, but call `pkgs/build-support/cc-wrapper` and
   `bintools-wrapper` directly, as `stageFun` does. Pass `coreutils`,
   `gnugrep` and `runtimeShell` from the `lfs-final-*` set. That removes the
   wrapper leak from step 9. Use only `lfs-final-*` packages in
   `initialPath` and `extraNativeBuildInputs`.
4. `helloFinal`: `lfs-stdenv/hello` with `stdenv = lfsStdenvFinal`.
5. Set `disallowedRequisites` on `lfsStdenvFinal` to every `lfs-` and
   `lfs-temp-` package. The build then fails if one of them leaks in.

**Verify:**

```console
$ nix build .#lfsStdenvFinal -o result-final-stdenv -L
$ nix build .#helloFinal -o result-final-hello -L
$ result-final-hello/bin/hello                     # Hello, world!
$ $B/$T-readelf -l result-final-hello/bin/hello | grep interpreter    # ...-lfs-final-glibc-2.40/...
$ LD_DEBUG=libs result-final-hello/bin/hello 2>&1 | grep 'search cache'
                                                   # no output, or only ...-lfs-final-glibc-2.40/etc/ld.so.cache
```

**Nix concepts:** [stdenv stages](appendix-nix-concepts.md#stdenv-internals-setupsh-initialpath-cc-wrapper),
[`disallowedRequisites`](appendix-nix-concepts.md#references-and-closures),
[patches](appendix-nix-concepts.md#patches),
[fixed-output derivations](appendix-nix-concepts.md#fixed-output-derivations).
