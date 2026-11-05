# Step 10 — the first package built by your stdenv

**File to write:** `lfs-stdenv/hello/default.nix`, attribute `hello`

**Goal:** build one normal package with `lfsStdenv`, and prove that your tools
built it. The package is GNU hello: it is small, it uses `configure` and
`make`, and it has tests.

**Nix concepts for this step**

New in this step:

- **A stdenv as an argument.** `pkgs.callPackage ./hello { stdenv = lfsStdenv; }`
  gives your stdenv. An argument that you give replaces the nixpkgs value.
  [More](appendix-nix-concepts.md#callpackage).
- **Build-time and runtime closure.** `nix-store -q --references <drv>` lists
  the inputs of the recipe: what the build needs. `nix path-info -r <out>` lists
  the closure of the result: what the program needs at run time.
  [More](appendix-nix-concepts.md#references-and-closures).
- **`doCheck`.** `doCheck = true;` runs `make check` in the build.
  [More](appendix-nix-concepts.md#stdenvmkderivation-and-phases).

From earlier steps: [fixed-output derivations](appendix-nix-concepts.md#fixed-output-derivations) (step 1), [the fixup phase](appendix-nix-concepts.md#the-fixup-phase-strip-patchelf-patchshebangs) (step 4), [setup hooks](appendix-nix-concepts.md#setup-hooks) (step 7), [inside a stdenv](appendix-nix-concepts.md#stdenv-internals-setupsh-initialpath-cc-wrapper) (step 9).

---

## What is new in this step

Until now, every derivation used the nixpkgs `stdenv`. `mkTemp` also uses it:
it only changes the flags and the `PATH`. In this step, the stdenv itself is
yours. The recipe looks the same as a nixpkgs recipe. That is the reason for
step 9: a stdenv with the shape that nixpkgs expects can build a normal recipe
with no change.

| | Steps 1 to 8 | Step 10 |
|---|---|---|
| `stdenv` | nixpkgs `stdenv` | `lfsStdenv` |
| The shell of the builder | nixpkgs bash | `lfs-temp-bash` |
| `cc` in the build | nixpkgs gcc (or `$T-gcc` from `PATH`) | The wrapper around `lfs-temp-gcc` |
| `make`, `sed`, `tar`, ... | nixpkgs | `lfs-temp-*` (step 7) |
| The program runs with | The nixpkgs glibc, or static | `lfs-temp-glibc` |

## Do

1. Write `lfs-stdenv/hello/default.nix`:

   ```nix
   { stdenv, fetchurl }:

   stdenv.mkDerivation rec {
     pname = "lfs-hello";
     version = "2.12.3";

     src = fetchurl {
       url = "mirror://gnu/hello/hello-${version}.tar.gz";
       hash = "sha256-DV9gFUOC/uELEUocNOeF2LH0kgc64tOm97FHaHs2aqA=";
     };

     doCheck = true;
   }
   ```

   | Line | Why |
   |---|---|
   | `{ stdenv, fetchurl }` | The file does not name `lfsStdenv`. The caller gives the stdenv. The same file builds with any stdenv. |
   | `pname = "lfs-hello"` | The `lfs-` prefix. The checks in step 12 use it. Step 11 builds `lfs-final-hello`. |
   | `version = "2.12.3"`, the hash | The version in the pinned nixpkgs. The binary cache has the source. |
   | `fetchurl` | The nixpkgs `fetchurl`. It is a fixed-output derivation: Nix checks the hash of the result, so the tool that downloads the file does not matter. The download tools are not in the closure of `hello`. `lfsStdenv.fetchurlBoot` also works. |
   | `doCheck = true` | Run `make check`. The tests run the new `hello` with your glibc, inside the build. |

   There is no `configurePhase`, `buildPhase` or `installPhase`. The default
   phases of `setup.sh` run `./configure --prefix=$out`, `make`,
   `make check` and `make install`.

2. Add the attribute in `flake.nix`, next to `lfsStdenv`:

   ```nix
   hello = pkgs.callPackage ./lfs-stdenv/hello { stdenv = lfsStdenv; };
   ```

   `callPackage` fills each argument from `pkgs`. An argument in the second
   set replaces the `pkgs` value. Here `stdenv = lfsStdenv` replaces the
   nixpkgs stdenv. `fetchurl` still comes from `pkgs`.

   If you forget `stdenv = lfsStdenv`, there is no error. `callPackage` gives
   the nixpkgs stdenv, and you get a normal nixpkgs hello. The
   `interpreter` check below finds this.

3. Make git track the new file. A flake sees only tracked files:

   ```console
   $ git add lfs-stdenv/hello/default.nix
   ```

4. Build it:

   ```console
   $ nix build .#hello -o result-hello -L
   ```

   The build takes less than a minute. In the log, look for these lines:

   | Log line | It shows |
   |---|---|
   | `checking for gcc... gcc`, then `checking whether the C compiler works... yes` | configure found the cc-wrapper of `lfsStdenv`, and your gcc links a program. |
   | `PASS: tests/hello-1` and `# FAIL:  0` | The new binary runs with `lfs-temp-glibc`. |
   | `shrinking RPATHs of ELF executables ...` | The patchelf setup hook of step 9 removes the `RPATH` entries that `hello` does not use. |
   | `stripping (with command strip ...)` | The bintools-wrapper gives `strip` from `lfs-temp-binutils`. |

## Verify

```console
$ result-hello/bin/hello                           # Hello, world!
$ $B/$T-readelf -l result-hello/bin/hello | grep interpreter
                                                   # /nix/store/...-lfs-temp-glibc-2.40/lib/ld-linux-aarch64.so.1
$ $B/$T-readelf -d result-hello/bin/hello | grep -E 'NEEDED|R(UN)?PATH'
                                                   # NEEDED: libc.so.6 and ld-linux-aarch64.so.1
                                                   # RUNPATH: only the lfs-temp-glibc lib directory
$ $B/$T-readelf -p .comment result-hello/bin/hello # GCC: (GNU) 14.2.0
$ nix path-info -r ./result-hello                  # two lines: lfs-temp-glibc and lfs-hello
$ nix-store -q --references $(nix eval --raw .#hello.drvPath)
                                                   # lfs-stdenv, lfs-temp-bash, the source, two builder scripts:
                                                   # no nixpkgs gcc and no nixpkgs glibc
```

| Check | It proves |
|---|---|
| `interpreter` | The kernel starts `hello` with the loader of *your* glibc. With the nixpkgs stdenv, this is the nixpkgs glibc. |
| `NEEDED` | `hello` needs only glibc. If you see `libssp.so.0`, your gcc does not know the glibc version. See step 8c. |
| `RUNPATH` | The ld-wrapper adds `-rpath` for `$out/lib` and for each `-L` directory, also the gcc directories. The patchelf hook removes each directory that has no needed library. Only the glibc directory stays. |
| `nix path-info -r` | At run time, `hello` needs only your glibc. This is the runtime closure. |
| `--references` of the `.drv` | The build inputs. `lfs-stdenv` brings in the rest of your tools. |

**Two leaks that are still there.** Step 11 removes both.

1. **A host tool in the build.** The cc-wrapper puts the nixpkgs coreutils on
   `PATH`, in front of your coreutils. Its setup hook does this, so that the
   wrapper scripts have `cat` and `grep`. Then configure finds the nixpkgs
   `install`, and `make install` uses it:

   ```console
   $ nix log .#hello | grep 'BSD-compatible install'
                                                   # /nix/store/...-coreutils-9.12/bin/install -c
   ```

   This is the wrapper leak of step 9. It does not change the result, but it
   is a host program in your build.

2. **The host loader cache.** Your glibc reads `/etc/ld.so.cache` when a
   library is not in the `RPATH`:

   ```console
   $ LD_DEBUG=libs result-hello/bin/hello 2>&1 | grep -E 'search|trying file'
                                                   # search path=...-lfs-temp-glibc-2.40/lib (system search path)
                                                   # trying file=...-lfs-temp-glibc-2.40/lib/libc.so.6
   ```

   `hello` finds `libc.so.6` at once, so there is no `search cache` line. A
   program that needs a library that is not in its `RUNPATH` reads the cache
   of the Ubuntu system. nixpkgs fixes this with
   `dont-use-system-ld-so-cache.patch` in
   `pkgs/development/libraries/glibc/`. Apply it to the glibc in step 11.

**If it fails:**

- `xargs: sh: No such file or directory`, then `Some binaries contain
  forbidden references to /build/`: `lfs-temp-bash` has no `bin/sh`. See step
  7, reason 9.
- `interpreter` shows the nixpkgs glibc: the attribute does not give
  `stdenv = lfsStdenv`.
- `NEEDED libssp.so.0`, and `nix path-info -r` shows `lfs-temp-gcc`: see
  step 8c, "The wrong header directory".
- No `NEEDED libssp.so.0`, but `nix path-info -r` shows `lfs-temp-gcc`, and
  `RUNPATH` has the gcc directories: there is no `shrinking RPATHs` line in
  the log. Check `extraNativeBuildInputs` in step 9.
- `error: path '.../lfs-stdenv/hello/default.nix' does not exist`: git does
  not track the file. Run `git add`.
