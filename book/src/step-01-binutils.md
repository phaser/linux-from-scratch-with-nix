# Step 1 — binutils

**File to write:** `lfs-toolchain/binutils/default.nix`, attribute `binutils`

**Read first:** the LFS book, chapter 5, "Binutils - Pass 1"
(<https://www.linuxfromscratch.org/lfs/view/12.2/>). This book uses the
versions of LFS 12.2.

The host compiler builds binutils on purpose. This is LFS pass 1. The result
runs on the host and produces code for the `aarch64-lfs-linux-gnu` triple.

**Nix concepts for this step**

New in this step:

- **A package file is a function.** Your file starts with
  `{ lib, stdenv, fetchurl, triple }:`. `callPackage ./binutils { inherit triple; }`
  calls it. It gives `lib`, `stdenv` and `fetchurl` from nixpkgs, and you give
  `triple`. `inherit triple;` is short for `triple = triple;`.
  [More](appendix-nix-concepts.md#callpackage).
- **`stdenv.mkDerivation` and phases.** It runs unpack, patch, configure,
  build, install and fixup. Attributes change a phase:
  `configureFlags = [ "--disable-nls" ];` adds flags to `./configure`. A hook is
  a shell fragment that runs before or after a phase:
  `postInstall = "rm -r $out/share/info";`. This step uses `preConfigure`.
  [More](appendix-nix-concepts.md#stdenvmkderivation-and-phases).
- **Fixed-output derivations.** `fetchurl { url = …; hash = …; }` is the only
  kind of build with network, because Nix checks the result against the hash.
  To get the hash, use `hash = lib.fakeHash;` and read the error, or run
  `nix store prefetch-file <url>`. [More](appendix-nix-concepts.md#fixed-output-derivations).
- **`$out` and `placeholder "out"`.** `$out` is the store path of the result,
  in the shell of the build. In Nix code the path is not known yet:
  `placeholder "out"` stands for it, for example in
  `"--with-foo=${placeholder "out"}/foo"`. [More](appendix-nix-concepts.md#out-and-placeholder-out).
- **`nativeBuildInputs`.** The tools that run during the build, for example
  `nativeBuildInputs = [ texinfo ];`. The sandbox has only these tools and the
  tools of the stdenv. [More](appendix-nix-concepts.md#nativebuildinputs-buildinputs-and-path).
- **Environment variables.** `env.NIX_CFLAGS_COMPILE = "-std=gnu17";` sets a
  variable for the build. The nixpkgs cc-wrapper adds its value to each
  compile. [More](appendix-nix-concepts.md#attributes-and-environment-variables).
- **`meta.platforms`.** `meta.platforms = lib.platforms.linux;` stops a build on
  another system. [More](appendix-nix-concepts.md#stdenvmkderivation-and-phases).
- **References and closures.** `nix path-info -r` lists each store path that
  the result refers to. `nix why-depends` shows why.
  [More](appendix-nix-concepts.md#references-and-closures).
- **`nix log`.** `nix log ./result-binutils` shows the log of the build.
  [More](appendix-nix-concepts.md#debugging-a-build).

From earlier steps: [the store](appendix-nix-concepts.md#the-store) (step 0), [flakes](appendix-nix-concepts.md#flakes) (step 0), [evaluation and build](appendix-nix-concepts.md#evaluation-and-build) (step 0).

---

**Do:**

1. Write `lfs-toolchain/binutils/default.nix`:

   ```nix
   { lib, stdenv, fetchurl, texinfo, triple }:

   stdenv.mkDerivation rec {
       pname = "lfs-binutils";
       version = "2.43";

       src = fetchurl {
           url = "mirror://gnu/binutils/binutils-${version}.tar.gz";
           hash = "sha256-AlxDbRUEkHbr5RHSllHMR4XuUCllqIOZNqZVGFgr3WQ=";
       };

       # The build regenerates the bfd manual's .texi inputs, so make rebuilds
       # bfd.info and needs makeinfo. LFS lists Texinfo as a host requirement.
       nativeBuildInputs = [ texinfo ];

       dontAddPrefix = true;
       preConfigure = "mkdir -p build && cd build";
       configureScript = "../configure";

       configureFlags = [
           "--target=${triple}"
           "--prefix=${placeholder "out"}/tools"
           "--disable-nls"
           "--disable-werror"
           "--disable-gprofng"
           "--enable-default-hash-style=gnu"
       ];

       meta = {
           description = "binutils for ${triple}, built from source";
           platforms = lib.platforms.linux;
       };
   }
   ```

   | Line | Why |
   |---|---|
   | `{ lib, stdenv, fetchurl, texinfo, triple }` | `callPackage` gives the nixpkgs values. You give `triple` in item 2. |
   | `version = "2.43"` | The later chapters expect this version. |
   | `hash` | Nix checks the download against it. To get a hash, set `hash = lib.fakeHash;` and build: the error prints the real hash after `got:`. Or run `nix store prefetch-file <url>`. |
   | `nativeBuildInputs = [ texinfo ]` | The build runs `makeinfo` for the bfd manual. Without it: `makeinfo: not found`, then `Error 127` at `doc/bfd.info`. |
   | `preConfigure`, `configureScript` | The build is out of tree, in `build/`, as in LFS. `preConfigure` runs before the configure phase. `configureScript` tells stdenv where `configure` is. |
   | `meta.platforms` | The build stops on a system that is not Linux. |

   The configure flags come from LFS. The table shows how each one changes:

   | LFS flag | This file | Why |
   |---|---|---|
   | `--prefix=$LFS/tools` | `--prefix=${placeholder "out"}/tools` and `dontAddPrefix = true;` | `$LFS` becomes `$out`, the store path of this package. The tools install under `$out/tools`, as LFS installs them under `$LFS/tools`. stdenv adds `--prefix=$out` itself, and `dontAddPrefix` stops that. In Nix code, `$out` is not known yet, so `placeholder "out"` stands for it. |
   | `--with-sysroot=$LFS` | removed | There is no sysroot yet. Step 5 makes it. The `SEARCH_DIR` check below shows the result. |
   | `--target=$LFS_TGT` | `--target=${triple}` | `triple` is `aarch64-lfs-linux-gnu`. |
   | `--enable-gprofng=no` | `--disable-gprofng` | The same meaning. |
   | `--disable-nls`, `--disable-werror`, `--enable-default-hash-style=gnu` | the same | As in LFS. |

2. Add the attribute to the set in `lfs-toolchain/default.nix`:

   ```nix
   binutils = callPackage ./binutils { inherit triple; };
   ```

3. Make git track the new file:

   ```console
   $ git add lfs-toolchain/binutils
   ```

**Build:**

```console
$ nix build .#binutils -o result-binutils -L
```

**Verify:**

```console
$ $B/$T-ld --version | head -1               # GNU ld (GNU Binutils) 2.43
$ ls $B | head                               # every tool has the aarch64-lfs-linux-gnu- prefix
$ $B/$T-ld -V | grep -A3 emulations          # aarch64linux among the emulations
$ $B/$T-ld --verbose | grep SEARCH_DIR       # no /usr/lib and no /lib: there is no sysroot yet
$ nix path-info -r ./result-binutils         # host glibc and friends: step 1 runs ON the host
$ nix why-depends ./result-binutils $(nix path-info -r ./result-binutils | grep -- '-glibc-' | head -1)
```

The last two checks show that the host still owns this binary. That is
expected until step 11.

**If it fails:**

- Read the end of the log with `nix log ./result-binutils`.
- `hash mismatch`: the URL or the version is different from the file above.
  Copy the hash after `got:`.
- `bad value ... for enable-default-hash-style option`: the `ld` configure
  accepts only `sysv`, `gnu` or `both`. It runs late, after `bfd` builds.
- Errors about `bool`, `true`, `false` or old-style function declarations:
  the host compiler is nixpkgs gcc 16.2, which uses C23 by default. Add
  `env.NIX_CFLAGS_COMPILE = "-std=gnu17";`.
