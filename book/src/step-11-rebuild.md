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

Each stage has its own stdenv. The name of the stdenv tells which parts are
final:

| Stage | Built with | glibc | binutils, gcc | Other tools | Builds |
|---|---|---|---|---|---|
| 1 | `lfsStdenv` (step 9) | temp | temp | temp | `lfs-final-glibc` |
| 2 | `lfsStdenvFinalGlibc` | **final** | temp | temp | `lfs-final-binutils`, `lfs-final-gcc` |
| 3 | `lfsStdenvFinalToolchain` | **final** | **final** | temp | The 14 tools of step 7, as `lfs-final-*` |
| 4 | `lfsStdenvFinal` | **final** | **final** | **final** | `lfs-final-hello` (`helloFinal`) |

Stage 3 uses the final gcc, not the temporary gcc. `patchelf` is C++, and it
links `libstdc++` from the gcc that builds it. With the temporary gcc, the
runtime closure gets `lfs-temp-gcc`.

## The packages

| # | Stage | Attribute | Version | Start from | What to change |
|---|---|---|---|---|---|
| 1 | 1 | `final.glibc` | 2.40 | `lfs-temp/glibc` | See "Stage 1" below. This page shows the full file. |
| 2 | 2 | `final.binutils` | 2.43 | `lfs-temp/binutils` | See "Stage 2" below. This page shows the full file. |
| 3 | 2 | `final.gcc` | 14.2.0 | `lfs-temp/gcc` | See "Stage 2" below. This page shows the full file. |
| 4 | 3 | `final.gnumake` | 4.4.1 | `lfs-temp/gnumake` | No change. |
| 5 | 3 | `final.coreutils` | 9.5 | `lfs-temp/coreutils` | Remove `stdbuf` from the `no-install` list, and remove `gl_cv_func_working_mktime`. |
| 6 | 3 | `final.bash` | 5.2.32 | `lfs-temp/bash` | Remove `CC_FOR_BUILD` and `bash_cv_strtold_broken`. Keep `-fpermissive` and the `sh` link. In `postInstall`, remove the path of `install` from `lib/bash/Makefile.inc` (see the file). |
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
| 17 | 3 | `final.patchelf` | 0.18.0 | `lfs-temp/patchelf` | No change. Keep the `setupHook`. The closure also has `lfs-final-gcc`, for `libstdc++`. |
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
  you remove them, the scripts store a path into `lfs-temp-*`. Item 3 of
  "Stage 4" finds this.
- **Keep the LFS settings.**

Do not use `mkTemp`. Write a smaller helper, or use `stdenv.mkDerivation`
directly. Set `pname = "lfs-final-<name>"`.

Packages 1 to 17 are built and checked. Package 18 is not built yet.

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
   { pkgs, nixpkgs, toolchain, temp, lfsStdenv }:

   rec {
     # Stage 1: built by lfsStdenv.
     glibc = pkgs.callPackage ./glibc { stdenv = lfsStdenv; inherit (toolchain) headers; };
   }
   ```

   The next stages go in the same `rec` set. Stage 2 makes new stdenvs, and
   for that it needs `nixpkgs` and `temp`. Stage 1 does not use them, but give
   them now, so that you do not change `flake.nix` again.

3. Import it in `flake.nix`, next to `hello`:

   ```nix
   final = import ./lfs-final { inherit pkgs nixpkgs toolchain temp lfsStdenv; };
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

### Verify stage 1

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

**If stage 1 fails:**

- `Hunk #1 FAILED at 48` in `elf/ldconfig.c`: the patch is the version of the
  pinned nixpkgs. Use the URL with the commit hash.
- `_FORTIFY_SOURCE` or `stack protector` errors when the loader compiles: the
  `hardeningDisable` line is missing.
- `nix path-info -r` shows `lfs-temp-glibc`: find the file with
  `grep -rl <hash> result-final-glibc`. If it is a library with a
  `RUNPATH`, check the `postConfigure` line.
- `nix path-info -r` shows `lfs-temp-bash`: check `BASH_SHELL`.

## Stage 2 — binutils and gcc for the final glibc

**Files to change:** `lfs-stdenv/default.nix`, `lfs-final/default.nix`

**Files to write:** `lfs-final/binutils/default.nix`, `lfs-final/gcc/default.nix`

**Goal:** a binutils and a gcc that use `lfs-final-glibc`, and a stdenv that
uses them.

Stage 2 is not the same as stage 1:

| | Stage 1 | Stage 2 |
|---|---|---|
| The stdenv | `lfsStdenv` of step 9 | `lfsStdenvFinalGlibc`, a new stdenv |
| The new programs use | `lfs-final-glibc` (its own) | `lfs-final-glibc` |
| What gcc compiles | — | Its own `libgcc` and `libstdc++`, with its new compiler. That compiler has no wrapper. See part 2d. |
| The result | A library | A new stdenv, `lfsStdenvFinalToolchain` |

Do the parts in this sequence. Each part has a check. Do the check before you
start the next part.

| Part | What you do | Build time |
|---|---|---|
| 2a | Let `lfs-stdenv/default.nix` take arguments. | none |
| 2b | Make `lfsStdenvFinalGlibc`. Compile `hello` with it. | less than 1 minute |
| 2c | Build `final.binutils`. | about 1.5 minutes |
| 2d | Build `final.gcc`. | about 17 minutes |
| 2e | Make `lfsStdenvFinalToolchain`. Compile `hello` with it. | less than 1 minute |

### 2a — let `lfs-stdenv` take arguments

Stage 2 needs two new stdenvs. Each one is the stdenv of step 9 with other
parts. Do not copy the file. Give it arguments. The defaults are the values of
step 9, so `lfsStdenv` does not change.

**Do:** change the start of `lfs-stdenv/default.nix`:

```diff
-{ pkgs, nixpkgs, temp }:
+{ pkgs, nixpkgs, temp,
+  name ? "lfs-stdenv",
+  libc ? temp.glibc,
+  binutils ? temp.binutils,
+  gcc ? temp.gcc }:
 let
     inherit (pkgs) lib;
     genericStdenv = import "${nixpkgs}/pkgs/stdenv/generic" { defaultConfig = pkgs.config; };
-    libc = temp.glibc;
-    bintools = pkgs.wrapBintoolsWith { bintools = temp.binutils; inherit libc; };
-    cc = pkgs.wrapCCWith { cc = temp.gcc; inherit bintools libc; };
+    bintools = pkgs.wrapBintoolsWith { bintools = binutils; inherit libc; };
+    cc = pkgs.wrapCCWith { cc = gcc; inherit bintools libc; };
 in
 genericStdenv {
-    name = "lfs-stdenv";
+    inherit name;
```

| Argument | Default (step 9) | Stage 2 gives |
|---|---|---|
| `name` | `"lfs-stdenv"` | A new name for each stdenv |
| `libc` | `temp.glibc` | `final.glibc` |
| `binutils` | `temp.binutils` | `final.binutils` (part 2e only) |
| `gcc` | `temp.gcc` | `final.gcc` (part 2e only) |

The other parts do not change: `shell`, `initialPath` and `patchelf` stay
`lfs-temp-*`. Stage 4 changes them.

**Verify:** the derivation of `lfsStdenv` is the same as before the change.

```console
$ nix eval --raw .#lfsStdenv.drvPath; echo      # BEFORE the change. Write down the path.
$ nix eval --raw .#lfsStdenv.drvPath; echo      # AFTER the change: the same path
```

If the paths are not the same, a default is not the value of step 9.

**If it fails:**

| You see | The cause |
|---|---|
| `error: attribute 'libc' missing` | The default is `temp.libc`. The attribute in `temp` is `glibc`: use `libc ? temp.glibc`. |
| The paths are the same, but in 2b the closure has `lfs-temp-glibc` | The line `libc = temp.glibc;` is still in the `let` block. A `let` name hides the argument with the same name, so the wrappers always get `temp.glibc`. Remove the line. |

### 2b — `lfsStdenvFinalGlibc` and sample compilation 1

This stdenv uses the temporary binutils and gcc, but the wrappers give them
`lfs-final-glibc`. The cc-wrapper adds `-B<glibc>/lib` and `-idirafter
<glibc>/include`. The bintools-wrapper adds `-dynamic-linker` and `-L` for the
glibc. Each program that this stdenv compiles uses `lfs-final-glibc`.

**Do:**

1. Write `lfs-final/default.nix`. Remove your `binutils` line for now. Part
   2c adds it again, with the new stdenv.

   ```nix
   { pkgs, nixpkgs, toolchain, temp, lfsStdenv }:

   let
     # The stdenv of step 9, with other parts (part 2a).
     mkStdenv = args: import ../lfs-stdenv ({ inherit pkgs nixpkgs temp; } // args);
   in
   rec {
     # Stage 1: built by lfsStdenv.
     glibc = pkgs.callPackage ./glibc { stdenv = lfsStdenv; inherit (toolchain) headers; };

     # Stage 2: temporary binutils and gcc, final glibc.
     lfsStdenvFinalGlibc = mkStdenv { name = "lfs-stdenv-final-glibc"; libc = glibc; };

     # Sample compilation 1.
     helloFinalGlibc = pkgs.callPackage ../lfs-stdenv/hello { stdenv = lfsStdenvFinalGlibc; };
   }
   ```

2. Make sure that `flake.nix` gives `nixpkgs` and `temp` (stage 1, item 3):

   ```nix
   final = import ./lfs-final { inherit pkgs nixpkgs toolchain temp lfsStdenv; };
   ```

**Verify:**

```console
$ nix build .#final.helloFinalGlibc -o result-hello-final-glibc -L
$ result-hello-final-glibc/bin/hello                    # Hello, world!
$ nix path-info -r ./result-hello-final-glibc           # TWO lines: lfs-final-glibc, lfs-hello
$ $B/$T-readelf -l result-hello-final-glibc/bin/hello | grep interpreter
                                                        # ...-lfs-final-glibc-2.40/lib/ld-linux-aarch64.so.1
$ $B/$T-readelf -d result-hello-final-glibc/bin/hello | grep RUNPATH
                                                        # ...-lfs-final-glibc-2.40/lib
```

Compare with `result-hello` of step 10. There, each path is `lfs-temp-glibc`.

The temporary gcc still reads the headers of `lfs-temp-glibc` first, before
the `-idirafter` headers. That is not a problem: both are glibc 2.40. The
final gcc of part 2d reads the headers of `lfs-final-glibc` only.

**If it fails:**

- `error: flake 'git+file:///work' does not provide attribute
  '...final.helloFinalGlibc'`, but the attribute is in `lfs-final/default.nix`:
  Nix hides the real error. To see it, evaluate the attribute directly:

  ```console
  $ nix eval --impure --raw --expr '(builtins.getFlake "git+file:///work").legacyPackages.aarch64-linux.final.helloFinalGlibc.drvPath'
  ```

  Use this command for each "does not provide attribute" error of this step.
- `error: function 'anonymous lambda' called without required argument
  'nixpkgs'` (or `'temp'`): the `final = import ./lfs-final { ... }` line of
  `flake.nix` does not give `nixpkgs` and `temp`. See item 2.
- The closure has `lfs-temp-glibc`: the `libc = glibc` argument is missing,
  or the `let` block of `lfs-stdenv/default.nix` still has
  `libc = temp.glibc;` (see 2a).
- The closure has `lfs-temp-gcc`: the `extraNativeBuildInputs` line of step 9
  is missing.
- `error: function 'anonymous lambda' called with unexpected argument`: part
  2a is not done.

### 2c — `final.binutils`

**Do:**

1. Write `lfs-final/binutils/default.nix`:

   ```nix
   { stdenv, fetchurl, texinfo, perl, triple }:

   stdenv.mkDerivation rec {
       pname = "lfs-final-binutils";
       version = "2.43";

       src = fetchurl {
           url = "mirror://gnu/binutils/binutils-${version}.tar.gz";
           hash = "sha256-AlxDbRUEkHbr5RHSllHMR4XuUCllqIOZNqZVGFgr3WQ=";
       };

       # texinfo: as in step 8b. perl: pod2man makes the man pages.
       nativeBuildInputs = [ texinfo perl ];

       # LFS builds in a separate directory.
       preConfigure = "mkdir -p build && cd build";
       configureScript = "../configure";

       # stdenv adds --build and --host with the nixpkgs name of the machine.
       # Give the three names yourself, all the same: the tools are native.
       configurePlatforms = [ ];
       configureFlags = [
           "--build=${triple}"
           "--host=${triple}"
           "--target=${triple}"
           "--disable-nls"
           "--disable-werror"
           "--disable-gprofng"
           "--enable-default-hash-style=gnu"
       ];
   }
   ```

2. Add the attribute to `lfs-final/default.nix`, after `lfsStdenvFinalGlibc`:

   ```nix
   binutils = pkgs.callPackage ./binutils { stdenv = lfsStdenvFinalGlibc; inherit (toolchain) triple; };
   ```

The changes from step 8b:

| Step 8b | Part 2c | Why |
|---|---|---|
| `mkTemp` | `stdenv.mkDerivation`, `pname = "lfs-final-binutils"` | `mkTemp` is for a build with the host compiler. |
| `--host` (from `mkTemp`), `--target` | `configurePlatforms = [ ]`, and `--build`, `--host`, `--target`, all `${triple}` | If one name is not the same, binutils is a cross binutils. Then the tools are `bin/${triple}-ld`, not `bin/ld`. |
| `--disable-shared`, `--disable-plugins`, `LDFLAGS=-all-static`, `preBuild` | Removed | They are for a static build. |
| `nativeBuildInputs = [ texinfo ]` | `[ texinfo perl ]` | `lfsStdenv` has no perl. Without perl, the build makes no man pages, and it does not fail. |
| In the source directory | `preConfigure`, `configureScript` | LFS chapter 8 builds in a separate directory. |

Do not set `dontAddPrefix`. stdenv adds `--prefix=$out`. Without it, the
prefix is `/usr/local`.

**Verify:**

```console
$ nix build .#final.binutils -o result-final-binutils -L     # about 1.5 minutes
$ ls result-final-binutils/bin
    # addr2line ar as c++filt elfedit gprof ld ld.bfd nm objcopy objdump ranlib readelf size strings strip
$ nix path-info -r ./result-final-binutils              # TWO lines: lfs-final-glibc, lfs-final-binutils
$ $B/$T-readelf -l result-final-binutils/bin/ld | grep interpreter
                                                        # ...-lfs-final-glibc-2.40/lib/ld-linux-aarch64.so.1
$ $B/$T-readelf -d result-final-binutils/bin/ld | grep RUNPATH
                                                        # ...-lfs-final-glibc-2.40/lib
$ ls result-final-binutils/share/man/man1 | head -1     # addr2line.1.gz
```

**If it fails:**

| You see | The cause |
|---|---|
| `mkdir: cannot create directory '/usr': Permission denied` | `dontAddPrefix = true`. Remove it. |
| `bin/aarch64-lfs-linux-gnu-ld`, not `bin/ld` | The three platform flags, or `configurePlatforms = [ ]`, are missing. |
| Files in `$out/tools` | A `--prefix` from step 1 is in the file. Remove it. |
| The closure has `lfs-temp-glibc` | The attribute uses `stdenv = lfsStdenv`. Use `lfsStdenvFinalGlibc`. |
| No `share/man/man1` | `perl` is missing. |

### 2d — `final.gcc`

**Do:**

1. Write `lfs-final/gcc/default.nix`:

   ```nix
   { stdenv, fetchurl, triple, glibc }:

   let
       gmp = fetchurl {
           url = "mirror://gnu/gmp/gmp-6.3.0.tar.bz2";
           hash = "sha256-rCghGnz7YJuuLiyNYFjWbI/pZDT3QM9v4uR7AA0cIMs=";
       };
       mpfr = fetchurl {
           url = "mirror://gnu/mpfr/mpfr-4.2.2.tar.xz";
           hash = "sha256-tnugOD736KhWNzTi6InvXsPDuJigHQD6CmhprYHGzgE=";
       };
       mpc = fetchurl {
           url = "mirror://gnu/mpc/mpc-1.4.1.tar.xz";
           hash = "sha256-kSBM0y8WS9O3yZLUpqjOZRlRGq2rMPeLaYLQv41z6TE=";
       };
   in
   stdenv.mkDerivation rec {
       pname = "lfs-final-gcc";
       version = "14.2.0";

       src = fetchurl {
           url = "mirror://gnu/gcc/gcc-${version}/gcc-${version}.tar.xz";
           hash = "sha256-p7Obxpy/niWCbFpgqyZHcAH3wI2FzsBLwOKcq+1vPMk=";
       };

       postUnpack = ''
           tar -xf ${gmp}  -C $sourceRoot && mv $sourceRoot/gmp-*  $sourceRoot/gmp
           tar -xf ${mpfr} -C $sourceRoot && mv $sourceRoot/mpfr-* $sourceRoot/mpfr
           tar -xf ${mpc}  -C $sourceRoot && mv $sourceRoot/mpc-*  $sourceRoot/mpc
       '';

       # The same patch as step 8c.
       patches = [ ../../lfs-temp/gcc/no-sys-dirs.patch ];
       hardeningDisable = [ "format" ];

       preConfigure = "mkdir -p build && cd build";
       configureScript = "../configure";

       configurePlatforms = [ ];
       configureFlags = [
           "--build=${triple}"
           "--host=${triple}"
           "--target=${triple}"
           "--with-native-system-header-dir=${glibc}/include"
           "--enable-languages=c,c++"
           "--disable-nls"
           "--disable-multilib"
           "--disable-bootstrap"
           "--disable-lto"
           "--disable-plugin"
           "--disable-libsanitizer"
       ];

       # gcc compiles libgcc and libstdc++ with its new xgcc. xgcc has no
       # wrapper. Give it the final glibc, as nixpkgs does
       # (pkgs/development/compilers/gcc/common/builder.nix).
       preBuild = ''
           tflags="-B${glibc}/lib -idirafter ${glibc}/include"
           lflags="-Wl,-L${glibc}/lib -Wl,-rpath,${glibc}/lib -Wl,-dynamic-linker=${glibc}/lib/ld-linux-aarch64.so.1"
           makeFlagsArray+=(
               "FLAGS_FOR_TARGET=$tflags $lflags"
               "CFLAGS_FOR_TARGET=-O2 $tflags $lflags"
               "CXXFLAGS_FOR_TARGET=-O2 $tflags $lflags"
               "LDFLAGS_FOR_TARGET=$lflags"
           )
       '';

       # As in step 8c: these scripts store paths of the build tools.
       postInstall = ''
           rm -r $out/libexec/gcc/${triple}/${version}/install-tools
       '';
   }
   ```

2. Add the attribute to `lfs-final/default.nix`, after `binutils`:

   ```nix
   gcc = pkgs.callPackage ./gcc { stdenv = lfsStdenvFinalGlibc; inherit glibc; inherit (toolchain) triple; };
   ```

   `inherit glibc` gives `final.glibc`, from the same `rec` set.

The changes from step 8c:

| Step 8c | Part 2d | Why |
|---|---|---|
| `mkTemp` | `stdenv.mkDerivation`, `pname = "lfs-final-gcc"` | As in part 2c. |
| `--target` | `configurePlatforms = [ ]`, and the three names | As in part 2c. |
| `CXX_FOR_BUILD`, `LDFLAGS_FOR_BUILD` | Removed | The build programs (`genmodes`, `gengtype` ...) now use the same compiler as gcc. There is no host compiler. |
| `--with-glibc-version` | Removed | build = host, so configure finds `features.h` in the native header directory. It sees the glibc version. |
| The `limits.h` lines of `postInstall` | Removed | The same reason. gcc finds the `limits.h` of glibc, and its own `limits.h` includes it. |
| — | `preBuild` | See "xgcc and the start files" below. |
| `./no-sys-dirs.patch` | `../../lfs-temp/gcc/no-sys-dirs.patch` | The same file. You can also copy it. |

#### xgcc and the start files

In step 8c, build was not the same as host. gcc compiled `libgcc` and
`libstdc++` with the gcc of step 6. That gcc has a sysroot, and it finds the
glibc.

Now build, host and target are the same. gcc compiles its libraries with
`xgcc`, the compiler that it just built. `xgcc` has no wrapper. The patch
removed `/lib` and `/usr/lib`. So `xgcc` does not know where the glibc is, and
the link of `libgcc_s.so` fails after about 15 minutes:

```text
ld: cannot find crti.o: No such file or directory
```

The `*_FOR_TARGET` variables give `xgcc` the flags that the cc-wrapper gives
to the other compilers:

| Flag | It gives |
|---|---|
| `-B${glibc}/lib` | The start files `crt1.o`, `crti.o`, `crtn.o` |
| `-idirafter ${glibc}/include` | The glibc headers |
| `-Wl,-L${glibc}/lib` | `libc.so` and `libm.so` for the linker |
| `-Wl,-rpath,${glibc}/lib` | A `RUNPATH`, so `libstdc++.so` finds the final glibc at run time |
| `-Wl,-dynamic-linker=...` | The final loader, not `/lib/ld-linux-aarch64.so.1` |

Use `makeFlagsArray` in `preBuild`, not `makeFlags`. Each value has spaces.
stdenv splits `makeFlags` at each space. `makeFlagsArray` keeps each value as
one argument.

**Verify:**

```console
$ nix build .#final.gcc -o result-final-gcc -L          # about 17 minutes
$ G=result-final-gcc
$ nix path-info -r ./$G                                 # TWO lines: lfs-final-glibc, lfs-final-gcc
$ $B/$T-readelf -l $G/bin/gcc | grep interpreter        # ...-lfs-final-glibc-2.40/lib/ld-linux-aarch64.so.1
$ $G/bin/gcc -v 2>&1 | grep ^Target                     # Target: aarch64-lfs-linux-gnu
$ $B/$T-readelf -d $($G/bin/gcc -print-prog-name=cc1plus) | grep -E 'NEEDED|RUNPATH'
                                                        # libm.so.6, libc.so.6, ld-linux-aarch64.so.1
                                                        # RUNPATH ...-lfs-final-glibc-2.40/lib
$ echo | $G/bin/gcc -E -v - 2>&1 | sed -n '/<...> search/,/End of/p'
                                                        # 4 directories. The last is ...-lfs-final-glibc-2.40/include
$ printf '#include <limits.h>\nint x = PATH_MAX;\n' | $G/bin/gcc -fsyntax-only -x c - && echo OK
                                                        # OK
$ $G/bin/gcc -dumpspecs | grep -A1 '^\*link_ssp'        # %{fstack-protector|...:}  (no -lssp)
```

| Check | It proves |
|---|---|
| `nix path-info -r` | No path of `lfs-temp-*` or of nixpkgs is in the result. |
| `cc1plus` | The compiler programs use the final glibc. |
| The search list | gcc reads the headers of `lfs-final-glibc` only. |
| `PATH_MAX` | The `limits.h` of gcc includes the `limits.h` of glibc. |
| `link_ssp` | gcc knows that glibc has the stack protector. Programs do not need `libssp.so.0`. |

**If it fails:**

| You see | The cause |
|---|---|
| `ld: cannot find crti.o` | The `preBuild` is missing, or it uses `makeFlags`. |
| The closure has `lfs-temp-glibc` | The attribute uses `stdenv = lfsStdenv`. |

### 2e — `lfsStdenvFinalToolchain` and sample compilation 2

**Do:** add these lines to `lfs-final/default.nix`, after `gcc`:

```nix
  # The final glibc, binutils and gcc. The other tools are still lfs-temp-*.
  lfsStdenvFinalToolchain = mkStdenv {
    name = "lfs-stdenv-final-toolchain";
    libc = glibc;
    inherit binutils gcc;
  };

  # Sample compilation 2.
  helloFinalToolchain = pkgs.callPackage ../lfs-stdenv/hello { stdenv = lfsStdenvFinalToolchain; };
```

`inherit binutils gcc` gives `final.binutils` and `final.gcc`, from the same
`rec` set.

**Verify:**

```console
$ nix build .#final.helloFinalToolchain -o result-hello-final-toolchain -L
$ result-hello-final-toolchain/bin/hello                # Hello, world!
$ nix path-info -r ./result-hello-final-toolchain       # TWO lines: lfs-final-glibc, lfs-hello
$ $B/$T-readelf -l result-hello-final-toolchain/bin/hello | grep interpreter
                                                        # ...-lfs-final-glibc-2.40/lib/ld-linux-aarch64.so.1
$ cat $(nix build --no-link --print-out-paths .#final.lfsStdenvFinalToolchain.cc)/nix-support/orig-cc
                                                        # ...-lfs-final-gcc-14.2.0
$ cat $(nix build --no-link --print-out-paths .#final.lfsStdenvFinalToolchain.cc.bintools)/nix-support/orig-bintools
                                                        # ...-lfs-final-binutils-2.43
```

The two `orig-` files prove that the wrappers wrap the final gcc and the
final binutils. The program looks the same as sample compilation 1, but now
no part of the compiler is `lfs-temp-*`.

Stage 2 is complete. Stage 3 uses `lfsStdenvFinalToolchain`.

## Stage 3 — the 14 tools

**Goal:** the 14 tools of step 7, built by `lfsStdenvFinalToolchain`, as
`lfs-final-*`.

Each tool is one file and one attribute. First do the example below. Then do
the other 13 tools in the same way.

### Example: `final.coreutils`

**Do:**

1. Write `lfs-final/coreutils/default.nix`:

   ```nix
   { stdenv, fetchurl }:

   stdenv.mkDerivation rec {
       pname = "lfs-final-coreutils";
       version = "9.5";

       src = fetchurl {
           url = "mirror://gnu/coreutils/coreutils-${version}.tar.xz";
           hash = "sha256-zTKO3qyS9qZl3p8yPJO3Eq8YWLwuDYjz9xAEaUcKG4o=";
       };

       configureFlags = [
           "--enable-install-program=hostname"          # LFS
           "--enable-no-install-program=kill,uptime"    # LFS
       ];
   }
   ```

2. Add the attribute to `lfs-final/default.nix`, after
   `lfsStdenvFinalToolchain`:

   ```nix
   # Stage 3: built by lfsStdenvFinalToolchain.
   coreutils = pkgs.callPackage ./coreutils { stdenv = lfsStdenvFinalToolchain; };
   ```

3. Make git track the new file:

   ```console
   $ git add lfs-final/coreutils
   ```

The changes from step 7 (`lfs-temp/coreutils/default.nix`):

| Step 7 | Stage 3 | Why |
|---|---|---|
| `{ fetchurl, mkTemp }:` | `{ stdenv, fetchurl }:` | `stdenv` comes from the attribute: `lfsStdenvFinalToolchain`. |
| `mkTemp rec {` | `stdenv.mkDerivation rec {` | `mkTemp` adds `--host`, `--build`, `-static` and the cross `PATH`. Stage 3 needs none of them. |
| `pname = "coreutils"` | `pname = "lfs-final-coreutils"` | `mkTemp` added `lfs-temp-`. Now you write the full name. |
| `kill,uptime,stdbuf` | `kill,uptime` | `stdbuf` loads `libstdbuf.so`. A static build cannot do that. Now the programs are not static. |
| `gl_cv_func_working_mktime=yes` | Removed | In a cross build, configure cannot run its test program, so step 7 gave the answer. Now configure runs the test. |

`src` and `version` do not change. `dontPatchShebangs` also comes from the
stdenv (the `preHook` of step 9).

**Verify:**

```console
$ nix build .#final.coreutils -o result-final-coreutils -L      # about 1 minute
$ R=result-final-coreutils
$ nix path-info -r ./$R                                 # TWO lines: lfs-final-glibc, lfs-final-coreutils
$ $B/$T-readelf -l $R/bin/ls | grep interpreter         # ...-lfs-final-glibc-2.40/lib/ld-linux-aarch64.so.1
$ $B/$T-readelf -d $R/bin/ls | grep -E 'NEEDED|RUNPATH'
                                                        # libc.so.6, ld-linux-aarch64.so.1
                                                        # RUNPATH ...-lfs-final-glibc-2.40/lib
$ $B/$T-readelf -p .comment $R/bin/ls                   # GCC: (GNU) 14.2.0
$ $R/bin/ls --version | head -1                         # ls (GNU coreutils) 9.5
$ $R/bin/stdbuf -oL $R/bin/echo ok                      # ok
$ ls $R/libexec/coreutils                               # libstdbuf.so
$ nix log ./$R | grep -E 'cross compiling|working mktime'
                                                        # checking whether we are cross compiling... no
                                                        # checking for working mktime... yes
```

| Check | It proves |
|---|---|
| `nix path-info -r` | No path of `lfs-temp-*` or of nixpkgs is in the result. |
| `NEEDED` | The programs are not static. In step 7 they had no `NEEDED` lines. |
| `stdbuf` | `stdbuf` works, and it finds `libstdbuf.so`. |
| `nix log` | configure ran its test programs. The build is native. |

**If it fails:**

| You see | The cause |
|---|---|
| `called without required argument 'mkTemp'` | The file still uses `mkTemp`. |
| The closure has `lfs-temp-glibc` | The attribute uses `stdenv = lfsStdenv`. Use `lfsStdenvFinalToolchain`. |
| `checking whether we are cross compiling... yes` | A `--host` or `--build` flag is still in the file. |

### The other 13 tools

**Strategy:** copy each file from `lfs-temp`, then edit the copy, as in the
example.

1. Copy the directory:

   ```console
   $ cp -r lfs-temp/gnused lfs-final/gnused
   ```

2. In the copy, do the changes of the coreutils example: `stdenv.mkDerivation`,
   `{ stdenv, ... }:` and `pname = "lfs-final-<name>"`.
3. Do the changes of the "What to change" column of "The packages".
4. Add the attribute with `stdenv = lfsStdenvFinalToolchain`, and `git add`
   the directory.
5. Do the checks of the example. Use a program of that tool, not `ls`. The
   closure must have two lines: `lfs-final-glibc` and the tool. Only
   `patchelf` has a third line, `lfs-final-gcc`.

If the closure has a nixpkgs package, a file stores a path. To find the
file:

```console
$ nix-store -q --references ./result-final-bash          # the stored paths
$ grep -rl <hash> result-final-bash/                     # the file with the path
```

An example: `lib/bash/Makefile.inc` of bash stores the nixpkgs `install`. The
cc-wrapper of step 9 puts the nixpkgs coreutils first on `PATH`, and configure
finds `install` there. Stage 4 removes this leak.

If you do not do item 3, these problems occur:

| Tool | The problem |
|---|---|
| bzip2 | `CC=${triple}-gcc` is not on `PATH`. The wrapper gives only `gcc`. The build fails. |
| xz | It stays static, and it has no `liblzma.so`. |
| coreutils | It has no `stdbuf`. |
| bash | `bash_cv_strtold_broken` and `CC_FOR_BUILD` stay. Both are for a cross build. |
| findutils, diffutils, gnupatch, gnutar | `gl_cv_func_working_mktime=yes` hides the configure test. The value is correct, so the build works. But the setting is for a cross build. |

**Another method, for the 6 tools with "No change" only.** gnumake, gnused,
gnugrep, gawk, gzip and patchelf only call `mkTemp`. You can call their
`lfs-temp` file directly, and give it a different function with the name
`mkTemp`:

```nix
# In lfs-final/default.nix, in the rec set.
mkFinal = args: lfsStdenvFinalToolchain.mkDerivation
    (args // { pname = "lfs-final-${args.pname}"; });
callFinal = dir: pkgs.callPackage dir { mkTemp = mkFinal; };

gnused = callFinal ../lfs-temp/gnused;
```

`mkFinal` does not add the settings of `lfs-temp/lib.nix` (`--host`,
`--build`, `-static`, the cross `PATH`). So the build is native.

The disadvantage: stage 3 then uses the files of step 7. A change in step 7
also changes stage 3. A copy for each tool is clearer. This book uses copies.

## Stage 4 — `lfsStdenvFinal`

**Do:**

1. `lfsStdenvFinal`: like step 9, but call `pkgs/build-support/cc-wrapper` and
   `bintools-wrapper` directly, as `stageFun` does. Pass `coreutils`,
   `gnugrep` and `runtimeShell` from the `lfs-final-*` set. That removes the
   wrapper leak from step 9. Use only `lfs-final-*` packages in `shell`,
   `initialPath` and `extraNativeBuildInputs`.
2. `helloFinal`: `lfs-stdenv/hello` with `stdenv = lfsStdenvFinal`.
3. Set `disallowedRequisites` on `lfsStdenvFinal` to every `lfs-` and
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
