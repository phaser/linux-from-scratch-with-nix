# Step 2 — gcc stage 1

**File to write:** `lfs-toolchain/gcc-stage1/default.nix`, attribute `gccStage1`

**Read first:** the LFS book, chapter 5, "GCC - Pass 1".

The chicken-and-egg compiler: `--without-headers --with-newlib` means "there is
no libc, do not look for one". It can emit object files and cannot link.

**Nix concepts for this step**

New in this step:

- **`nativeBuildInputs` and `PATH`.** For each input, stdenv adds one
  directory to `PATH`, and only that one. Hint 1 shows which directory.
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

**Do:** write a derivation that meets these requirements.

1. The file is a function of
   `{ lib, stdenv, fetchurl, gmp, mpfr, libmpc, isl, binutils, triple }`.
   Pass `binutils` from step 1 when you call it.
2. The source is gcc **14.2.0** from the GNU mirror.
3. Out-of-tree build, and install under `$out/tools`, as in step 1.
4. C only. No libc, no shared libgcc, no threads, and none of the runtime
   libraries that LFS disables in pass 1.
5. gmp, mpfr and mpc: LFS unpacks their sources into the gcc tree. You can do
   the same, or use the nixpkgs libraries (they link into the compiler, which
   runs on the host). Write your choice in a comment.
6. For each LFS flag that you drop, write the reason in a comment.

**The problem to solve.** In LFS, binutils and gcc share `$LFS/tools`, so gcc
finds `aarch64-lfs-linux-gnu-as` and `-ld` in its own prefix. Here, binutils is
a separate store path. Your gcc must find the binutils from step 1 in two
situations:

- **During the build**: configure and the libgcc build look up the target tools
  by name (`aarch64-lfs-linux-gnu-ar`, `-as`, and so on).
- **After the build**: when you run `gcc -c` from `result-gcc1`, with no
  binutils on your `PATH`.

The check `-print-prog-name=as` below tells you whether your solution works.

<details>
<summary>Hint 1: why <code>nativeBuildInputs = [ binutils ]</code> is not enough</summary>

For each input, stdenv adds one directory to `PATH`. Find which one in
`pkgs/stdenv/generic/setup.sh` (search for `addToSearchPath _PATH`). Then
compare it with where step 1 installs the tools.

</details>

<details>
<summary>Hint 2: during the build</summary>

`preConfigure` is a shell fragment. It can change `PATH`.

</details>

<details>
<summary>Hint 3: after the build</summary>

Read `gcc/configure --help`, or the GCC install documentation, for options
that hardcode the path of the assembler and the linker.

</details>

<details>
<summary>Hint 4: the nixpkgs libraries</summary>

Headers and libraries are in different outputs of the same package. Look up
`lib.getDev` and `lib.getLib`, and the gcc options `--with-gmp-include` and
`--with-gmp-lib`.

</details>

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
from the host, and the exercise is void.

**If it fails:**

- `-print-prog-name=as` prints only `as`: the installed driver does not know
  your binutils. See hint 3.
- `aarch64-lfs-linux-gnu-ar: command not found` during the build: see hints 1
  and 2.
- C23 errors in C files (`bool`, `true`, `false`): see step 1.
- Errors about `format-security` in `libcpp`: add
  `hardeningDisable = [ "format" ];`. nixpkgs does the same for its own gcc.
- `no matching function for call to 'S2C(const char8_t [2])'` in `libcody`:
  the host g++ 16 uses C++20 by default. Add `export CXX="g++ -std=gnu++17"`
  to `preConfigure`.
- `checking whether g++ is for C++11... no`, then `C++11 is required`: you put
  `-std` in `CXXFLAGS`. The libcody check adds `-std=c++11` to `CXX`, and
  `CXXFLAGS` comes after it. Put the flag in `CXX`.
- gcc's configure accepts unknown `--with-*` and `--disable-*` options without
  a warning. A typo such as `--with-gmp-libs` has no effect. Compare your
  flags with `./configure --help`.
- gmp, mpfr or mpc not found: `nix log` names the missing file. See hint 4.

## Solution

Read this only if you are stuck. Try the hints first.

<details>
<summary>Show the solution</summary>

`lfs-toolchain/gcc-stage1/default.nix`:

```nix
{ lib, stdenv, fetchurl, gmp, mpfr, libmpc, isl, binutils, triple }:

stdenv.mkDerivation rec {
    pname = "lfs-gcc-stage1";
    version = "14.2.0";

    src = fetchurl {
        url = "mirror://gnu/gcc/gcc-${version}/gcc-${version}.tar.xz";
        hash = "sha256-p7Obxpy/niWCbFpgqyZHcAH3wI2FzsBLwOKcq+1vPMk=";
    };

    # The nixpkgs libraries, not the sources in the gcc tree: this gcc runs
    # on the host, so host libraries are correct here.
    buildInputs = [ gmp mpfr libmpc isl ];
    hardeningDisable = [ "format" ];

    dontAddPrefix = true;
    preConfigure = ''
        # During the build: configure and libgcc find the target tools by name.
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
        # After the build: the driver keeps these paths, so gcc -c works
        # without binutils on PATH.
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

        # Dropped LFS flags:
        #   --with-sysroot=$LFS          there is no sysroot yet; step 6 adds it
        #   --with-glibc-version=2.40    no program links glibc here; step 8 needs it
        #   --enable-default-pie, --enable-default-ssp
        #                                default flags for the final programs;
        #                                stage 1 builds only libgcc
        #   --enable-languages=c,c++     C only: no libc, so no libstdc++
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
        "--disable-bootstrap"          # not in LFS: a cross compiler does not bootstrap
    ];

    meta = {
        description = "stage-1 C compiler for ${triple}";
        platforms = lib.platforms.linux;
    };
}
```

The line in `lfs-toolchain/default.nix`:

```nix
gccStage1 = callPackage ./gcc-stage1 { inherit triple binutils; };
```

| Problem | Solution |
|---|---|
| During the build | `preConfigure` puts `${binutils}/tools/bin` on `PATH`. stdenv adds only `${binutils}/bin`, which does not exist (hint 1). |
| After the build | `--with-as` and `--with-ld` store the full paths in the driver (hint 3). |
| gmp, mpfr, mpc, isl | `lib.getDev` gives the headers, `lib.getLib` gives the libraries (hint 4). |

</details>
