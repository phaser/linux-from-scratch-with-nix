# Step 2 — gcc stage 1

**File to write:** `lfs-toolchain/gcc-stage1/default.nix`, attribute `gccStage1`

**Read first:** the LFS book, chapter 5, "GCC - Pass 1".

The chicken-and-egg compiler: `--without-headers --with-newlib` means "there is
no libc, do not look for one". It can emit object files and cannot link.

**Nix concepts for this step**

New in this step:

- **`nativeBuildInputs` and `PATH`.** For each input, stdenv adds one
  directory to `PATH`, and only that one: `<input>/bin`.
  [More](appendix-nix-concepts.md#nativebuildinputs-buildinputs-and-path).
- **A package in a string.** `"${binutils}/tools/bin"` gives the store path
  of `binutils` and makes it an input of the build. You can use it in
  `preConfigure` and in configure flags. [More](appendix-nix-concepts.md#nix-language).
- **Multiple outputs.** One package can have several store paths: `out`,
  `dev` (headers), `lib` (libraries). `lib.getDev gmp` gives the `dev` output,
  `lib.getLib gmp` the `lib` output. [More](appendix-nix-concepts.md#multiple-outputs-libgetdev-libgetlib).
- **Hardening flags.** The nixpkgs cc-wrapper adds flags such as
  `-Werror=format-security`. `hardeningDisable = [ "format" ];` removes one.
  [More](appendix-nix-concepts.md#hardening-flags).
- **Debugging a build.** `-L` shows the log during the build. `nix log` shows
  it after. `--keep-failed` keeps the build directory.
  [More](appendix-nix-concepts.md#debugging-a-build).

From earlier steps: [`stdenv.mkDerivation` and phases](appendix-nix-concepts.md#stdenvmkderivation-and-phases) (step 1), [`callPackage`](appendix-nix-concepts.md#callpackage) (step 1), [fixed-output derivations](appendix-nix-concepts.md#fixed-output-derivations) (step 1).

---

**Do:**

1. Write `lfs-toolchain/gcc-stage1/default.nix`:

   ```nix
   { lib, stdenv, fetchurl, gmp, mpfr, libmpc, isl, binutils, triple }:

   stdenv.mkDerivation rec {
       pname = "lfs-gcc-stage1";
       version = "14.2.0";

       src = fetchurl {
           url = "mirror://gnu/gcc/gcc-${version}/gcc-${version}.tar.xz";
           hash = "sha256-p7Obxpy/niWCbFpgqyZHcAH3wI2FzsBLwOKcq+1vPMk=";
       };

       buildInputs = [ gmp mpfr libmpc isl ];
       hardeningDisable = [ "format" ];

       dontAddPrefix = true;
       preConfigure = ''
           export PATH=${binutils}/tools/bin:$PATH
           # The host g++ 16 defaults to C++20, where u8"" literals are char8_t,
           # and libcody fails. g++ 14 defaults to gnu++17. Not CXXFLAGS: it
           # comes after the -std=c++11 that the libcody configure check adds.
           export CXX="g++ -std=gnu++17"
           mkdir -p build && cd build
       '';
       configureScript = "../configure";

       configureFlags = [
           "--target=${triple}"
           "--prefix=${placeholder "out"}/tools"
           "--with-as=${binutils}/tools/bin/${triple}-as"
           "--with-ld=${binutils}/tools/bin/${triple}-ld"

           "--with-gmp-include=${lib.getDev gmp}/include"
           "--with-gmp-lib=${lib.getLib gmp}/lib"
           "--with-mpfr-include=${lib.getDev mpfr}/include"
           "--with-mpfr-lib=${lib.getLib mpfr}/lib"
           "--with-mpc-include=${lib.getDev libmpc}/include"
           "--with-mpc-lib=${lib.getLib libmpc}/lib"
           "--with-isl-include=${lib.getDev isl}/include"
           "--with-isl-lib=${lib.getLib isl}/lib"

           "--with-newlib"
           "--without-headers"
           "--enable-languages=c"
           "--disable-nls"
           "--disable-shared"
           "--disable-multilib"
           "--disable-threads"
           "--disable-libatomic"
           "--disable-libgomp"
           "--disable-libquadmath"
           "--disable-libssp"
           "--disable-libvtv"
           "--disable-libstdcxx"
           "--disable-bootstrap"
       ];

       meta = {
           description = "stage-1 C compiler for ${triple}";
           platforms = lib.platforms.linux;
       };
   }
   ```

   | Line | Why |
   |---|---|
   | `binutils` in the arguments | The binutils of step 1. You give it in item 2. |
   | `version = "14.2.0"` | The gcc of LFS 12.2. |
   | `dontAddPrefix`, `--prefix`, `preConfigure`, `configureScript` | Out-of-tree build, and install under `$out/tools`, as in step 1. |
   | `export PATH=${binutils}/tools/bin:$PATH` | gcc finds binutils during the build. See below. |
   | `--with-as`, `--with-ld` | gcc finds binutils after the build. See below. |
   | `buildInputs = [ gmp mpfr libmpc isl ]` and the `--with-gmp...` flags | LFS unpacks the gmp, mpfr and mpc sources into the gcc tree. This file uses the nixpkgs libraries: this gcc runs on the host, so host libraries are correct. Each library has its headers and its libraries in different outputs. `lib.getDev` gives the headers, `lib.getLib` the libraries. Step 8 uses the sources in the tree, because that gcc runs on the target. |
   | `hardeningDisable = [ "format" ]` | The cc-wrapper adds `-Werror=format-security`, and `libcpp` fails with it. nixpkgs does the same for its own gcc. |
   | `export CXX="g++ -std=gnu++17"` | See the comment in the file. With `-std` in `CXXFLAGS`, configure fails: `checking whether g++ is for C++11... no`, then `C++11 is required`. |
   | `--with-newlib`, `--without-headers` | There is no libc: do not look for one. |
   | `--enable-languages=c` | C only. Step 4 compiles glibc with this gcc, and glibc is C. |
   | `--disable-shared`, `--disable-threads`, `--disable-lib...` | A shared libgcc, threads and the runtime libraries need a libc. LFS disables them in pass 1. |
   | `--disable-nls`, `--disable-multilib` | As in LFS. |
   | `--disable-bootstrap` | Not in LFS. A cross compiler does not bootstrap. The flag makes this explicit. |

   This file does not use these LFS flags:

   | LFS flag | Why |
   |---|---|
   | `--with-sysroot=$LFS` | There is no sysroot yet. Step 6 adds the flag. |
   | `--with-glibc-version=2.40` | No program links glibc in this step. Step 8 uses the flag and explains it. |
   | `--enable-default-pie`, `--enable-default-ssp` | They change only the default compile flags. This book does not use them. |
   | `--enable-languages=c,c++` | This file builds C only. |

2. Add the attribute to `lfs-toolchain/default.nix`:

   ```nix
   gccStage1 = callPackage ./gcc-stage1 { inherit triple binutils; };
   ```

3. Make git track the new file:

   ```console
   $ git add lfs-toolchain/gcc-stage1
   ```

**How gcc finds binutils.** In LFS, binutils and gcc share `$LFS/tools`, so
gcc finds `aarch64-lfs-linux-gnu-as` and `-ld` in its own prefix. Here,
binutils is a separate store path. gcc must find it in two situations:

- **During the build.** configure and the libgcc build look up the target
  tools by name (`aarch64-lfs-linux-gnu-ar`, `-as`, and so on).
  `nativeBuildInputs = [ binutils ]` is not sufficient. For each input,
  stdenv adds only `<input>/bin` to `PATH` (`addToSearchPath _PATH` in
  `pkgs/stdenv/generic/setup.sh`). Step 1 installs the tools in
  `<input>/tools/bin`. The `PATH` line in `preConfigure` adds that directory.
- **After the build.** You run `gcc -c` from `result-gcc1`, with no binutils
  on your `PATH`. `--with-as` and `--with-ld` store the full paths in the
  driver. The check `-print-prog-name=as` below shows them.

**Build:**

```console
$ nix build .#gccStage1 -o result-gcc1 -L    # about 10 to 20 minutes
$ G1=$PWD/result-gcc1/tools/bin
$ echo 'int main(void){return 0;}' > /tmp/hello.c
```

**Verify:**

```console
$ $G1/$T-gcc --version | head -1                  # aarch64-lfs-linux-gnu-gcc (GCC) 14.2.0
$ $G1/$T-gcc -print-prog-name=as                  # .../lfs-binutils-2.43/tools/bin/aarch64-lfs-linux-gnu-as
$ $G1/$T-gcc -print-prog-name=ld                  # .../lfs-binutils-2.43/tools/bin/aarch64-lfs-linux-gnu-ld
$ $G1/$T-gcc -print-sysroot                       # empty line: no sysroot
$ $G1/$T-gcc -print-libgcc-file-name              # a libgcc.a path inside result-gcc1
$ $G1/$T-gcc -c /tmp/hello.c -o /tmp/hello.o && file /tmp/hello.o
                                                  # ELF 64-bit LSB relocatable, ARM aarch64
$ $B/$T-readelf -p .comment /tmp/hello.o          # GCC: (GNU) 14.2.0
$ echo '#include <stdio.h>' | $G1/$T-gcc -E -     # FAILS: stdio.h: No such file or directory
$ $G1/$T-gcc /tmp/hello.c -o /tmp/hello           # FAILS: cannot find crt1.o ... cannot find -lc
```

The last two checks **must fail**. If they succeed, the compiler found a libc
from the host, and the result is not valid.

**If it fails:**

- `-print-prog-name=as` prints only `as`: the installed driver does not know
  your binutils. Check `--with-as` and `--with-ld`.
- `aarch64-lfs-linux-gnu-ar: command not found` during the build: check the
  `PATH` line in `preConfigure`.
- C23 errors in C files (`bool`, `true`, `false`): see step 1.
- gcc's configure accepts unknown `--with-*` and `--disable-*` options without
  a warning. A typo such as `--with-gmp-libs` has no effect. Compare your
  flags with `./configure --help`.
- gmp, mpfr or mpc not found: `nix log` names the missing file. Check the
  `lib.getDev` and `lib.getLib` flags.
