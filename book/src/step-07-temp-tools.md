# Step 7 — static temporary tools

**Files to write:** `lfs-temp/lib.nix` (the helper), `lfs-temp/<tool>/default.nix`
for each tool, and `lfs-temp/default.nix`. Import it in `flake.nix` as `temp`.

These tools replace the host's `bash`, `coreutils` and so on in the stdenv's
`initialPath`. The list matches `initialPath` in nixpkgs
`pkgs/stdenv/linux/stage0.nix`.

**Do:**

1. Write one helper function for all tools. Its key parts:

   ```nix
   { stdenv, triple, binutils, gccStage2 }:
   { pname, ... }@args:
   stdenv.mkDerivation (args // {
     pname = "lfs-temp-${pname}";
     configurePlatforms = [ ];
     configureFlags = [ "--host=${triple}" "--build=${stdenv.buildPlatform.config}" ]
       ++ (args.configureFlags or [ ]);
     preConfigure = ''
       export PATH=${gccStage2}/tools/bin:${binutils}/tools/bin:$PATH
       unset CC CXX AR AS LD NM OBJCOPY OBJDUMP READELF
       export STRIP=${triple}-strip RANLIB=${triple}-ranlib
     '' + (args.preConfigure or "");
     LDFLAGS = "-static";
     dontPatchShebangs = true;  # else scripts get the host bash
   })
   ```

   The default `--prefix=$out` stays. The tools use the Nix layout. Static
   linking means that there is no loader path to get wrong.

2. Build the tools one at a time, in this order. `gnumake` is first because
   it is small and tests the helper. `patchelf` is C++, and the fixup phase
   of every later stdenv needs it.

   | # | Attribute | Version | `src.url` | `src.hash` |
   |---|---|---|---|---|
   | 1 | `gnumake` | 4.4.1 | `mirror://gnu/make/make-${version}.tar.gz` | `sha256-3Rb7HWe/q3mnL16DkHNcSePo5wtJRaFasfgd23hlj7M=` |
   | 2 | `coreutils` | 9.5 | `mirror://gnu/coreutils/coreutils-${version}.tar.xz` | `sha256-zTKO3qyS9qZl3p8yPJO3Eq8YWLwuDYjz9xAEaUcKG4o=` |
   | 3 | `bash` | 5.2.32 | `mirror://gnu/bash/bash-${version}.tar.gz` | `sha256-0++A0rZ9jLvk0yZcY6csRvmyeOrW4OBtYYAbWPI/ULU=` |
   | 4 | `gnused` | 4.9 | `mirror://gnu/sed/sed-${version}.tar.xz` | `sha256-biJrcy4c1zlGStaGK9Ghq6QteYKSLaelNRljHSSXUYE=` |
   | 5 | `gnugrep` | 3.11 | `mirror://gnu/grep/grep-${version}.tar.xz` | `sha256-HbKu3eidDepCsW2VKPiUyNFdrk4ZC1muzHj1qVEnbqs=` |
   | 6 | `gawk` | 5.3.0 | `mirror://gnu/gawk/gawk-${version}.tar.xz` | `sha256-ypwW09EdD/jGnXncC0cmfhMppps5t5mJVgTtRH08qQs=` |
   | 7 | `findutils` | 4.10.0 | `mirror://gnu/findutils/findutils-${version}.tar.xz` | `sha256-E4fgtn/yR9Kr3pmPkN+/cMFJE5Glnd/suK5ph4nwpPU=` |
   | 8 | `diffutils` | 3.10 | `mirror://gnu/diffutils/diffutils-${version}.tar.xz` | `sha256-kOXpPMck5OvhLt6A3xY0Bjx6hVaSaFkZv+YLVWyb0J4=` |
   | 9 | `gnupatch` | 2.7.6 | `mirror://gnu/patch/patch-${version}.tar.xz` | `sha256-rGEL2per4Nn2t8ljJVoR3LGWwl4zfGH5Tkd41jLx2P0=` |
   | 10 | `gnutar` | 1.35 | `mirror://gnu/tar/tar-${version}.tar.xz` | `sha256-TWL/NzQux67XSFNTI5MMfPlKz3HDWRiCsmp+pQ8+3BY=` |
   | 11 | `gzip` | 1.13 | `mirror://gnu/gzip/gzip-${version}.tar.xz` | `sha256-dFTraTXbF8ZlVXbC4bD6vv04tNCTbg+H9IzQYs6RoFc=` |
   | 12 | `xz` | 5.6.2 | `https://github.com/tukaani-project/xz/releases/download/v${version}/xz-${version}.tar.xz` | `sha256-qds7s9ZOJIoPrpY/j7a6hRomuhgi5QTcDv0YqAxibK8=` |
   | 13 | `bzip2` | 1.0.8 | `https://sourceware.org/pub/bzip2/bzip2-${version}.tar.gz` | `sha256-q1oDF27hBtPw+pDjgdpHjdrkBZGBU8yiSOaCzQxKImk=` |
   | 14 | `patchelf` | 0.18.0 | `https://github.com/NixOS/patchelf/releases/download/${version}/patchelf-${version}.tar.bz2` | `sha256-GVKyp4K6V2J5whHulC40F0j9tEmX9wTdU970bNBVRws=` |

   The versions are the LFS 12.2 versions. LFS 12.2 also uses binutils 2.43,
   gcc 14.2.0 and glibc 2.40. `bzip2` and `patchelf` are not in LFS chapter 6.

   **Settings for each tool.** Put these attributes in the tool file, next to
   `pname`, `version` and `src`. Each comment tells where the setting comes from:

   - *LFS*: the flag is in LFS chapter 6.
   - *static*: the flag is necessary because the helper links with `-static`.
     LFS chapter 6 links dynamically and does not need it.
   - *Nix*: the flag is necessary because of the Nix sandbox or the stdenv.

   ```nix
   # gnumake
   configureFlags = [ "--without-guile" ];                # LFS

   # coreutils
   configureFlags = [
     "--enable-install-program=hostname"                  # LFS
     "--enable-no-install-program=kill,uptime,stdbuf"     # LFS; stdbuf: static (1)
     "gl_cv_func_working_mktime=yes"                      # static (2)
   ];

   # bash
   configureFlags = [ "--without-bash-malloc" "bash_cv_strtold_broken=no" ];  # LFS
   preConfigure = ''
     export CC_FOR_BUILD="gcc -std=gnu17"                 # Nix (3)
     export CFLAGS="-g -O2 -fpermissive"                  # Nix (4)
   '';
   postInstall = "ln -s bash $out/bin/sh";                # LFS (9)

   # gnused: no settings

   # patchelf (needs `path` in its arguments; callPackage gives it)
   setupHook = "${path}/pkgs/development/tools/misc/patchelf/setup-hook.sh";  # Nix (10)

   # gnugrep
   makeFlags = [ "SHELL=/bin/sh" ];                       # Nix (5)

   # gawk
   postPatch = "sed -i 's/extras//' Makefile.in";         # LFS

   # findutils
   configureFlags = [
     "gl_cv_func_working_mktime=yes"                      # static (2)
     "ac_cv_path_SORT=sort"                               # Nix (6)
   ];

   # diffutils
   configureFlags = [
     "gl_cv_func_working_mktime=yes"                      # static (2)
     "ac_cv_path_PR_PROGRAM="                             # Nix (6)
   ];

   # gnupatch, gnutar
   configureFlags = [ "gl_cv_func_working_mktime=yes" ];  # static (2)

   # gzip
   configureFlags = [ "ac_cv_path_GREP=grep" ];           # Nix (6)
   makeFlags = [ "SHELL=/bin/sh" ];                       # Nix (5)

   # xz
   configureFlags = [
     "--disable-shared"                                   # static (7)
     "gl_cv_posix_shell=/bin/sh"                          # Nix (5)
   ];
   makeFlags = [ "LDFLAGS=-all-static" ];                 # static (7)

   # bzip2 (no configure script)
   makeFlags = [
     "CC=${triple}-gcc" "AR=${triple}-ar" "RANLIB=${triple}-ranlib"
     "PREFIX=$(out)" "LDFLAGS=-static"                    # (8)
   ];
   ```

   The `bzip2` file needs `triple` as an argument. In step 3, give it with
   `pkgs.callPackage ./bzip2 { inherit mkTemp; inherit (toolchain) triple; }`.

   Reasons:

   1. `stdbuf` needs a shared library, `libstdbuf.so`. A static build cannot
      make it.
   2. When gnulib cross-compiles, it cannot run its `mktime` test. It then
      adds its own `mktime`. The static `libc.a` also defines
      `__mktime_internal`, so the link fails with `multiple definition`.
   3. `mkbuiltins` compiles with the host gcc, which defaults to C23. The old
      `xmalloc ()` declarations fail in C23.
   4. Without ncurses, bash uses its bundled termcap. gcc 14 rejects its
      implicit `write ()` call. `-fpermissive` changes the error to a warning.
      (LFS builds ncurses before bash.)
   5. Configure writes the shell path into the scripts (`egrep`, `zgrep`,
      `xzgrep`). Stdenv calls `make SHELL=<host bash>`, and `makeFlags`
      come after it, so `SHELL=/bin/sh` replaces it.
   6. Configure stores the full path of a host tool: `sort` in `updatedb`,
      `pr` in `diff`, `grep` in `zgrep`. That path puts the host tool in the
      closure. An empty `PR_PROGRAM` disables only `diff -l`.
   7. Libtool removes `-static` from the link of `xz`. Its flag for a fully
      static program is `-all-static`. `--disable-shared` makes libtool link
      `liblzma.a`.
   8. Do not set `dontConfigure`. It also skips `preConfigure`, so the helper
      sets no `PATH`. Without a `configure` script, the configure phase runs
      only `preConfigure`. The bzip2 `Makefile` sets its own `LDFLAGS`, so
      give `-static` again here.
   9. LFS makes the same link (`ln -sv bash $LFS/bin/sh`). Scripts and
      stdenv hooks call `sh`. For example, the fixup phase of every package
      that `lfsStdenv` builds runs `xargs ... sh -c`. Without the link, the
      build of step 10 fails with `xargs: sh: No such file or directory`.
   10. `path` is the nixpkgs source. The fixup phase copies this file to
       `$out/nix-support/setup-hook`. The tool itself does not use it.
       `lfsStdenv` (step 9) runs it in every build, to shrink the `RPATH`
       of each program. The nixpkgs patchelf has the same hook.

   Example for `gnumake`. The tool file gives only what is special for the
   tool. The helper adds the cross flags and `-static`:

   ```nix
   # lfs-temp/gnumake/default.nix
   { fetchurl, mkTemp }:

   mkTemp rec {
     pname = "gnumake";
     version = "4.4.1";

     src = fetchurl {
       url = "mirror://gnu/make/make-${version}.tar.gz";
       hash = "sha256-3Rb7HWe/q3mnL16DkHNcSePo5wtJRaFasfgd23hlj7M=";
     };

     # LFS chapter 6: build make without the Guile extension language.
     configureFlags = [ "--without-guile" ];
   }
   ```

3. Write `lfs-temp/default.nix`. It collects the tools of this step. It
   contains four things:

   - The inputs: `pkgs`, and the step 1-6 set as `toolchain`.
   - `mkTemp`: the helper, applied once to the toolchain parts.
   - One attribute for each tool. `callPackage` gives `mkTemp` to the tool file.
   - `tools`: a `buildEnv` of all the tools. Here `buildEnv` is correct,
     because nothing reads these files through a sysroot.

   ```nix
   # lfs-temp/default.nix
   { pkgs, toolchain }:

   let
     mkTemp = import ./lib.nix {
       inherit (pkgs) stdenv;
       inherit (toolchain) triple binutils gccStage2;
     };
     call = dir: pkgs.callPackage dir { inherit mkTemp; };
   in
   rec {
     gnumake   = call ./gnumake;
     coreutils = call ./coreutils;
     # ... one line for each tool, in the build order above

     tools = pkgs.buildEnv {
       name = "lfs-temp-tools";
       paths = [ gnumake coreutils /* ... */ ];
     };
   }
   ```

   `lib.nix` needs `triple`. Add `triple` to the `inherit` line of
   `lfs-toolchain/default.nix`, so that `toolchain.triple` exists.

4. Import the set in `flake.nix` as `temp`:

   ```nix
   legacyPackages.${system} =
     let toolchain = import ./lfs-toolchain { inherit pkgs; };
     in toolchain // {
       temp = import ./lfs-temp { inherit pkgs toolchain; };
       solutions = import ./solutions/lfs-toolchain { inherit pkgs; };
     };
   ```

   `nix build .#temp.gnumake` now builds one tool. `nix build .#temp.tools`
   builds all of them.

**Verify each tool** (example for coreutils):

```console
$ nix build .#temp.coreutils -o result-temp-coreutils -L
$ file result-temp-coreutils/bin/ls                # ELF 64-bit LSB executable, ARM aarch64, statically linked
$ result-temp-coreutils/bin/ls --version | head -1 # ls (GNU coreutils) <version>
$ $B/$T-readelf -p .comment result-temp-coreutils/bin/ls    # GCC: (GCC) 14.2.0  (gcc stage 2)
$ nix path-info -r ./result-temp-coreutils         # ONE line: the tool itself
```

**Verify all tools together:**

```console
$ nix build .#temp.tools -o result-temp
$ env -i PATH=$(readlink -f result-temp)/bin bash -c 'type -P ls sed grep make tar xz patchelf'
                                                   # every path is inside result-temp
$ for f in result-temp/bin/*; do file -L $f; done | grep -vc 'statically linked'
                                                   # 0 (scripts such as egrep are fine; check them by hand)
```

**If it fails:**

- A configure test tries to run a program: that is a cross-compile check.
  LFS chapter 6 lists the cache variables for each tool (for example
  `gl_cv_...=yes`).
- Link warnings about `getpwnam` in static binaries are normal for glibc.
- `checking for aarch64-lfs-linux-gnu-gcc... gcc`, then `C compiler cannot
  create executables`: configure uses the `CC=gcc` from stdenv (the host
  gcc). Unset `CC` and the other tool variables in `preConfigure`.
- `nix path-info -r` shows the toolchain: the binary is not stripped, and its
  debug info holds store paths. Set `STRIP` and `RANLIB` to the `${triple}-`
  tools. The strip hook needs both (`stripDirs: Ranlib command is empty`).

**Nix concepts:** [functions that make derivations](appendix-nix-concepts.md#nix-language),
[`//` and `@args`](appendix-nix-concepts.md#nix-language),
[references and closures](appendix-nix-concepts.md#references-and-closures).
