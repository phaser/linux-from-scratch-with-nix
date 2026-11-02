# my-linux-distro

A Nix implementation of the *interesting* half of Linux From Scratch: build a
Linux toolchain from source, then use it to build a Nix `stdenv` that contains
no binary from the host.

This is **way A**: do the bootstrap by hand, one derivation at a time, so that
every step is visible. nixpkgs does the same job in
`pkgs/stdenv/linux/default.nix`. Read that file after you finish; you will
recognise every stage.

Steps 1 to 3 are implemented in `bootstrap/`. From step 4 on, this README tells
you what to write and how to check it. You write the code.

---

## What success looks like

There are two milestones.

| Milestone | After step | Proof |
|---|---|---|
| 1. A binary that your compiler built, linked against your glibc, runs | 6 | It prints the version of *your* glibc, not the host glibc. |
| 2. A Nix `stdenv` with no host binary in it | 12 | `nix path-info -r` of the final stdenv shows only your packages. |

A bootable distro is not the goal. Kernel, init and boot come after milestone 2.

---

## How to read each step

Each step has the same parts:

- **Do**: what to build or write.
- **Verify**: commands with the expected result as a comment. Run all of them.
  Do not continue to the next step if one check fails.
- **If it fails**: the most likely causes.
- **Nix concepts**: what you need to know for this step. Each name links to
  the [Nix concepts](#nix-concepts) section at the end.

### Conventions

- Run every command **inside the Linux VM**, in the repo directory.
- Give every build its own out-link with `-o`, so the results of earlier steps
  stay available:

  ```console
  $ nix build .#packages.aarch64-linux.binutils -o result-binutils
  ```

- Set these variables once per shell. Later steps add more.

  ```console
  $ T=aarch64-lfs-linux-gnu
  $ B=$PWD/result-binutils/tools/bin
  ```

- Name every derivation with a prefix that tells where it belongs:

  | Prefix | Built by | Steps |
  |---|---|---|
  | `lfs-` | The host stdenv (cross tools, sysroot) | 1 to 6 |
  | `lfs-temp-` | Your cross compiler (temporary tools) | 7 and 8 |
  | `lfs-final-` | Your own stdenv | 11 |

  The checks in step 12 use these prefixes with `grep`.

---

## Part 0 — The environment

### Step 0 — A Linux VM with Nix

None of this builds on `aarch64-darwin`:

- The flake pins `system = "aarch64-linux"`.
- The kernel headers need a case-sensitive file system. The macOS `/nix`
  volume is case-insensitive APFS.
- macOS cannot execute the Linux binaries that the checks run.

**Do** (on the Mac, with Tart):

```console
$ tart clone ghcr.io/cirruslabs/ubuntu:latest lfs
$ tart set lfs --cpu 8 --memory 16384 --disk-size 80
$ tart run lfs --no-graphics &
$ rsync -a ~/projects/my-linux-distro admin@$(tart ip lfs):   # password: admin
$ ssh admin@$(tart ip lfs)
```

Then, inside the VM:

```console
$ curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
$ . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
$ cd my-linux-distro
```

Copy the repo with `rsync`. Do not use `tart run --dir`: a shared folder stays
on the case-insensitive macOS volume.

**Verify:**

```console
$ uname -m                                   # aarch64
$ nix --version                              # prints a version
$ nix config show sandbox                    # true
$ d=$(mktemp -d); touch $d/a $d/A; ls $d | wc -l; rm -r $d    # 2 (case-sensitive)
$ df -h /nix | tail -1                       # 40G or more available
$ nix eval --raw .#packages.aarch64-linux.binutils.drvPath    # /nix/store/...-lfs-binutils-2.43.drv
$ ldd --version | head -1                    # the HOST glibc version; write it down for step 6
```

**Nix concepts:** [flakes](#flakes), [evaluation and build](#evaluation-and-build),
[the sandbox](#the-sandbox).

---

## Part 1 — The cross toolchain (implemented)

### Step 1 — binutils

**File:** `bootstrap/binutils.nix`

The host compiler builds binutils on purpose. This is LFS pass 1. The result
runs on the host and produces code for the `aarch64-lfs-linux-gnu` triple.

**Do:**

1. Get the source hash. You have two ways:
   - Build once and let it fail. Copy the `got:` hash from the error to
     replace `lib.fakeHash`.
   - Or ask Nix directly:

     ```console
     $ nix store prefetch-file https://ftp.gnu.org/gnu/binutils/binutils-2.43.tar.xz
     ```

2. Build:

   ```console
   $ nix build .#packages.aarch64-linux.binutils -o result-binutils -L
   ```

**Verify:**

```console
$ $B/$T-ld --version | head -1               # GNU ld (GNU Binutils) 2.43
$ ls $B | head                               # every tool has the aarch64-lfs-linux-gnu- prefix
$ $B/$T-ld -V | grep -A3 emulations          # aarch64linux among the emulations
$ $B/$T-ld --verbose | grep SEARCH_DIR       # no /usr/lib and no /lib: there is no sysroot yet
$ nix path-info -r ./result-binutils         # host glibc and friends: rung 1 runs ON the host
$ nix why-depends ./result-binutils $(nix path-info -r ./result-binutils | grep -- '-glibc-' | head -1)
```

The last two checks show that the host still owns this binary. That is
expected until step 11.

**If it fails:** after the hash, read the end of the log with `nix log`.

**Nix concepts:** [fixed-output derivations](#fixed-output-derivations),
[`stdenv.mkDerivation` and phases](#stdenvmkderivation-and-phases),
[`placeholder "out"`](#out-and-placeholder-out),
[references and closures](#references-and-closures),
[`callPackage`](#callpackage).

### Step 2 — gcc stage 1

**File:** `bootstrap/gcc-stage1.nix`

The chicken-and-egg compiler: `--without-headers --with-newlib` means "there is
no libc, do not look for one". It can emit object files and cannot link.

This step meets the immutable store for the first time. In LFS, binutils and
gcc share `$LFS/tools`, so gcc finds the target `as` and `ld` there. Here
binutils is a separate store path. So `gcc-stage1.nix` puts
`${binutils}/tools/bin` on `PATH` for the build, and passes `--with-as` and
`--with-ld` for the installed driver.

**Do:**

```console
$ nix build .#packages.aarch64-linux.gccStage1 -o result-gcc1 -L    # about 10 to 20 minutes
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
$ $B/$T-readelf -p .comment /tmp/hello.o          # GCC: (GCC) 14.2.0
$ echo '#include <stdio.h>' | $G1/$T-gcc -E -     # FAILS: stdio.h: No such file or directory
$ $G1/$T-gcc /tmp/hello.c -o /tmp/hello           # FAILS: cannot find crt1.o ... cannot find -lc
```

The last two checks **must fail**. If they succeed, the compiler found a libc
from the host, and the exercise is void.

**If it fails:**

- `-print-prog-name=as` prints only `as`: the `--with-as` flag did not reach
  configure. Check the flags in `nix log`.
- Errors about `format-security`: add `hardeningDisable = [ "format" ];`.
  nixpkgs does the same for its own gcc.
- gmp, mpfr or mpc not found: `nix log` names the missing file. Check the
  `--with-*-include` and `--with-*-lib` paths.

**Nix concepts:** [`nativeBuildInputs` and `PATH`](#nativebuildinputs-buildinputs-and-path),
[multiple outputs](#multiple-outputs-libgetdev-libgetlib),
[hardening flags](#hardening-flags),
[debugging a build](#debugging-a-build).

### Step 3 — kernel headers

**File:** `bootstrap/headers.nix`

**Do:**

```console
$ nix build .#packages.aarch64-linux.headers -o result-headers -L
$ H=$PWD/result-headers/usr/include
```

**Verify:**

```console
$ ls $H                                           # asm  asm-generic  drm  linux  misc  mtd  rdma  scsi  sound  video  xen ...
$ find $PWD/result-headers -type f ! -name '*.h' | wc -l      # 0
$ grep -r '__NR_openat' $H | head -1              # one line: the syscall numbers are there
$ ls $H/linux/netfilter | grep -i '^xt_connmark.h$'
                                                  # 2 lines: xt_CONNMARK.h and xt_connmark.h
$ echo '#include <linux/types.h>' | $G1/$T-gcc -E -I $H - | tail -1
                                                  # no error: gcc stage 1 + your headers work together
```

The `netfilter` check is the reason for the case-sensitive file system.

Optional: compare the source hash with the kernel's signed list.

```console
$ curl -s https://cdn.kernel.org/pub/linux/kernel/v6.x/sha256sums.asc | grep ' linux-6.12.tar.xz'
$ nix hash convert --hash-algo sha256 --to sri <hex-from-the-line-above>
                                                  # the same hash as in headers.nix
```

**If it fails:** a tool is missing from the sandbox. Add it to
`nativeBuildInputs` (for example `perl`, `bison` or `flex`).

**Nix concepts:** [the sandbox](#the-sandbox), [SRI hashes](#fixed-output-derivations).

---

## Part 2 — libc and the full cross compiler

From here on you write the derivations. Add each one to
`bootstrap/default.nix`.

### Step 4 — glibc (FHS layout, for the sysroot)

**File to write:** `bootstrap/glibc.nix`

LFS installs glibc into the shared `$LFS` directory. Nix store paths are
immutable, so you cannot install into one and add to it later. This step
builds glibc into its own path with an FHS layout (`/usr/lib`,
`/usr/include`). Step 5 merges it with the headers.

**Do:** write a derivation with these parts:

- `pname = "lfs-glibc"`, version `2.40`, source
  `mirror://gnu/glibc/glibc-2.40.tar.xz`.
- `stdenv`, not `stdenvNoCC`. When `build` differs from `host`, glibc
  configure looks for a build compiler (`BUILD_CC`) for helper programs.
- `nativeBuildInputs = [ bison python3 perl ];`.
- `preConfigure`: put `${gccStage1}/tools/bin` and `${binutils}/tools/bin` on
  `PATH`, as in step 2. Then `mkdir build && cd build`, and
  `echo "rootsbindir=/usr/sbin" > configparms` (from LFS).
- `configureScript = "../configure";`, `dontAddPrefix = true;`,
  `configurePlatforms = [ ];`.
- `configureFlags`:

  ```
  --prefix=/usr
  --host=aarch64-lfs-linux-gnu
  --build=${stdenv.buildPlatform.config}
  --enable-kernel=4.19
  --with-headers=${headers}/usr/include
  --disable-nscd
  libc_cv_slibdir=/usr/lib
  ```

- `installFlags = [ "DESTDIR=${placeholder "out"}" ];`.
- `dontStrip = true; dontPatchELF = true;`. The fixup phase must not touch
  `ld.so` or `libc.so.6`.

**Verify:**

```console
$ nix build .#packages.aarch64-linux.glibc -o result-glibc -L
$ L=$PWD/result-glibc/usr/lib
$ ls $L/{libc.so,libc.so.6,libc.a,ld-linux-aarch64.so.1,crt1.o,crti.o,crtn.o}
                                                  # all 7 exist
$ cat $L/libc.so                                  # GROUP ( /usr/lib/libc.so.6 /usr/lib/libc_nonshared.a AS_NEEDED ( /usr/lib/ld-linux-aarch64.so.1 ) )
$ $B/$T-readelf -h $L/libc.so.6 | grep Machine    # AArch64
$ $B/$T-readelf -p .comment $L/libc.so.6          # GCC: (GCC) 14.2.0  (your gcc stage 1)
$ $L/ld-linux-aarch64.so.1 --version | head -1    # ld.so (GNU libc) stable release version 2.40.
$ nix path-info -r ./result-glibc                 # see the note below
```

The `libc.so` check shows absolute paths under `/usr/lib`. The linker resolves
them inside the sysroot only when it finds the script inside the sysroot. Step 5
depends on this.

The loader check runs your `ld.so` directly. This works because the VM and the
target are both aarch64.

`nix path-info -r` can show a nixpkgs `bash`. `patchShebangs` rewrote
`#!/bin/bash` in `usr/bin/ldd` to a host store path. That is a host leak. Set
`dontPatchShebangs = true;` and check again: the closure is then glibc alone.

**If it fails:**

- `configure: error: ... C compiler cannot create executables`: `PATH` does
  not contain gcc stage 1. Check `preConfigure`.
- `makeinfo` missing: add `texinfo` to `nativeBuildInputs`.

**Nix concepts:** [fixup phase](#the-fixup-phase-strip-patchelf-patchshebangs),
[platforms](#platforms-build-host-target), [`placeholder "out"`](#out-and-placeholder-out).

### Step 5 — the sysroot

**File to write:** a `sysroot` attribute in `bootstrap/default.nix`

The sysroot is the `$LFS` directory of the original recipe, made explicit:
headers and glibc in one tree.

**Do:** use `runCommand` and **copy** the files. Do not use `buildEnv` or
`symlinkJoin`.

```nix
sysroot = pkgs.runCommand "lfs-sysroot" { } ''
  mkdir -p $out
  cp -r ${headers}/. $out/
  chmod -R u+w $out
  cp -r ${glibc}/. $out/
'';
```

Why copy: `ld` decides whether a linker script such as `libc.so` is inside the
sysroot with `realpath`. A `buildEnv` file is a symlink, its real path is in
the glibc store path, and `ld` then looks for `/usr/lib/libc.so.6` on the
*host*. (An earlier version of this README suggested `buildEnv`. That was
wrong.)

**Verify:**

```console
$ nix build .#packages.aarch64-linux.sysroot -o result-sysroot
$ S=$(readlink -f result-sysroot)
$ find $S -type l | wc -l                         # small: only glibc's own symlinks
$ [ "$(readlink -f $S/usr/lib/libc.so)" = "$S/usr/lib/libc.so" ] && echo ok    # ok
$ ls $S/usr/include/{stdio.h,linux/types.h}      # both exist
```

**Nix concepts:** [trivial builders](#trivial-builders-runcommand-buildenv-symlinkjoin),
[immutability of the store](#the-store).

### Step 6 — gcc stage 2 (milestone 1)

**File to write:** `bootstrap/gcc-stage2.nix`

This is a full cross compiler: C and C++, linked against your glibc through the
sysroot. It follows crosstool-ng's "final gcc" more than LFS.

**Do:** copy `gcc-stage1.nix`, then change it:

- `pname = "lfs-gcc-stage2"`.
- Remove `--with-newlib`, `--without-headers`, `--disable-shared`,
  `--disable-threads` and the `--disable-lib*` flags.
- Add `--with-sysroot=${sysroot}` and
  `--with-native-system-header-dir=/usr/include`.
- Use `--enable-languages=c,c++`.

**Verify:** write this test program:

```console
$ G2=$PWD/result-gcc2/tools/bin
$ cat > /tmp/ver.c <<'EOF'
#include <stdio.h>
#include <gnu/libc-version.h>
int main(void) { printf("glibc %s\n", gnu_get_libc_version()); return 0; }
EOF
```

Then run the checks:

```console
$ nix build .#packages.aarch64-linux.gccStage2 -o result-gcc2 -L    # about 20 to 40 minutes
$ $G2/$T-gcc -print-sysroot                       # the sysroot store path ($S)
$ $G2/$T-gcc -print-file-name=libc.so             # $S/usr/lib/libc.so
$ echo '#include <stdio.h>' | $G2/$T-gcc -E - | grep -m1 stdio.h    # a path inside $S

# Static: no loader, no host libc. This is the cleanest proof.
$ $G2/$T-gcc -static /tmp/ver.c -o /tmp/ver-static
$ file /tmp/ver-static                            # statically linked
$ /tmp/ver-static                                 # glibc 2.40

# Dynamic: the loader path is the trap from the old rung 5.
$ $G2/$T-gcc /tmp/ver.c -o /tmp/ver -Wl,--trace | grep libc.so.6    # a path inside $S, not /usr/lib
$ $B/$T-readelf -l /tmp/ver | grep interpreter    # /lib/ld-linux-aarch64.so.1
$ /tmp/ver                                        # glibc <HOST version from step 0>
$ $S/usr/lib/ld-linux-aarch64.so.1 --library-path $S/usr/lib /tmp/ver    # glibc 2.40

# C++
$ printf '#include <iostream>\nint main(){std::cout<<"c++ ok\\n";}\n' > /tmp/cxx.cc
$ $G2/$T-g++ -static /tmp/cxx.cc -o /tmp/cxx && /tmp/cxx    # c++ ok
```

Read the two dynamic runs carefully. The same binary prints the host version or
`2.40`, depending on which loader runs it. gcc embeds the standard loader path,
not the sysroot path. On NixOS, `/tmp/ver` does not run at all, because NixOS
has no `/lib/ld-linux-aarch64.so.1`.

**This is milestone 1:** a compiler you built, linking against a libc you
built, producing a binary that runs.

**If it fails:** `libsanitizer` errors: add `--disable-libsanitizer`.

**Nix concepts:** [`callPackage` and `override`](#callpackage),
[debugging a build](#debugging-a-build).

---

## Part 3 — Leaving the host (way A)

Until now the host stdenv built every tool. This part builds a stdenv in which
your tools do everything. It is LFS chapters 6 to 8, in Nix.

The plan:

| Step | Builds | Built by | Runs with |
|---|---|---|---|
| 7 | Static temporary tools (bash, coreutils, make, ...) | gcc stage 2 (cross) | No loader (static) |
| 8 | glibc (Nix layout), native binutils and gcc | gcc stage 2 (cross) | Static, or glibc from step 8 |
| 9 | `lfsStdenv` | Assembled from steps 7 and 8 | — |
| 10 | A test package (GNU hello) | `lfsStdenv` | glibc from step 8 |
| 11 | Everything again, as `lfs-final-*` | `lfsStdenv` | Final glibc |
| 12 | Proof | — | — |

### Step 7 — static temporary tools

**File to write:** `bootstrap/temp.nix`

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
     '' + (args.preConfigure or "");
     LDFLAGS = "-static";
   })
   ```

   The default `--prefix=$out` stays. The tools use the Nix layout. Static
   linking means that there is no loader path to get wrong.

2. Build the tools one at a time, in this order. Take the configure flags from
   LFS chapter 6 for each tool.

   1. `gnumake` (small; it tests the helper)
   2. `coreutils`
   3. `bash` (add `--without-bash-malloc`)
   4. `gnused`, `gnugrep`, `gawk`, `findutils`, `diffutils`, `gnupatch`
   5. `gnutar`, `gzip`, `xz`
   6. `bzip2` (no configure script: `dontConfigure = true;` and
      `makeFlags = [ "CC=${triple}-gcc" "AR=${triple}-ar" "RANLIB=${triple}-ranlib" "PREFIX=$(out)" ];`)
   7. `patchelf` (C++; the fixup phase of every later stdenv needs it)

3. Add a `tempTools` attribute: a `buildEnv` of all of them. Here `buildEnv` is
   correct, because nothing reads these files through a sysroot.

**Verify each tool** (example for coreutils):

```console
$ nix build .#packages.aarch64-linux.temp.coreutils -o result-temp-coreutils -L
$ file result-temp-coreutils/bin/ls                # ELF 64-bit LSB executable, ARM aarch64, statically linked
$ result-temp-coreutils/bin/ls --version | head -1 # ls (GNU coreutils) <version>
$ $B/$T-readelf -p .comment result-temp-coreutils/bin/ls    # GCC: (GCC) 14.2.0  (gcc stage 2)
$ nix path-info -r ./result-temp-coreutils         # ONE line: the tool itself
```

**Verify all tools together:**

```console
$ nix build .#packages.aarch64-linux.tempTools -o result-temp
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

**Nix concepts:** [functions that make derivations](#nix-language),
[`//` and `@args`](#nix-language),
[references and closures](#references-and-closures).

### Step 8 — glibc for the store, native binutils, native gcc

**File to write:** more attributes in `bootstrap/temp.nix`

Step 4's glibc uses `/usr/lib` paths, which only work through a sysroot. A Nix
stdenv has no sysroot: the cc-wrapper passes store paths to gcc. So you need a
second glibc with the Nix layout.

#### 8a — `lfs-temp-glibc`

**Do:** as in step 4, but:

- Built by gcc stage 2 (`PATH` to `${gccStage2}/tools/bin`).
- Keep the default `--prefix=$out`. Remove `libc_cv_slibdir`, `DESTDIR` and
  `rootsbindir`.
- In `postInstall`, link the kernel headers into `$out/include`, without
  `scsi`. nixpkgs glibc does the same (`pkgs/development/libraries/glibc/default.nix`).
- `dontStrip`, `dontPatchELF`, `dontPatchShebangs`.

**Verify:**

```console
$ nix build .#packages.aarch64-linux.temp.glibc -o result-temp-glibc -L
$ cat result-temp-glibc/lib/libc.so                # GROUP ( /nix/store/...-lfs-temp-glibc-2.40/lib/libc.so.6 ... )
$ result-temp-glibc/lib/ld-linux-aarch64.so.1 --version | head -1    # ... version 2.40.
$ ls result-temp-glibc/include/{stdio.h,linux/types.h}               # both exist
$ nix path-info -r ./result-temp-glibc             # ONE line
```

Compare the `libc.so` output with step 4: store paths instead of `/usr/lib`.
This is the Nix answer to the old LFS "adjusting the toolchain" chapter.

#### 8b — `lfs-temp-binutils` (native)

**Do:** `--host=${triple} --target=${triple}`, static (the helper from step 7),
plus `--disable-plugins --disable-gprofng`. A static `ld` cannot load plugins.

**Verify:**

```console
$ ls result-temp-binutils/bin                      # ld, as, ar ... WITHOUT the triple prefix (host = target)
$ file result-temp-binutils/bin/ld                 # statically linked
$ result-temp-binutils/bin/ld --verbose | grep SEARCH_DIR
                                                   # /usr/lib and /lib appear: a native ld searches them
```

The last check matters. Inside the sandbox those directories do not exist. In
`nix develop` on the VM they do. The cc-wrapper and the bintools-wrapper hide
them in step 9.

#### 8c — `lfs-temp-gcc` (native)

**Do:**

- `--host=${triple} --target=${triple}`, static.
- Unpack the gmp, mpfr and mpc sources into the gcc source tree, as LFS does.
  Do not use the nixpkgs copies: those were built by the host.
- `--enable-languages=c,c++ --disable-multilib --disable-bootstrap`
  `--disable-lto --disable-plugin --disable-libsanitizer`.
- Apply the nixpkgs patch `pkgs/development/compilers/gcc/patches/gcc-12-no-sys-dirs.patch`.
  It stops gcc searching `/usr/include` and `/usr/lib`.

**Verify:**

```console
$ nix build .#packages.aarch64-linux.temp.gcc -o result-temp-gcc -L
$ result-temp-gcc/bin/gcc -v 2>&1 | grep -E '^(Target|Configured)'
                                                   # Target: aarch64-lfs-linux-gnu, --host=aarch64-lfs-linux-gnu
$ file result-temp-gcc/bin/gcc $(result-temp-gcc/bin/gcc -print-prog-name=cc1)
                                                   # both statically linked
$ echo | result-temp-gcc/bin/gcc -E -v - 2>&1 | sed -n '/search starts/,/End of search/p'
                                                   # no /usr/include (the patch works)
```

**Nix concepts:** [multiple outputs](#multiple-outputs-libgetdev-libgetlib),
[patches](#stdenvmkderivation-and-phases).

### Step 9 — `lfsStdenv`

**File to write:** `bootstrap/stdenv.nix`

A stdenv is a derivation that holds a shell, an `initialPath` of tools, a
wrapped compiler and `setup.sh`. You build one with
`pkgs/stdenv/generic/default.nix`. nixpkgs calls it in `stageFun`, in
`pkgs/stdenv/linux/default.nix`. Keep that function open while you write this
file.

**Do:**

```nix
{ pkgs, nixpkgs, temp }:
let
  inherit (pkgs) lib;
  genericStdenv = import "${nixpkgs}/pkgs/stdenv/generic" { defaultConfig = pkgs.config; };
  libc = temp.glibc;
  bintools = pkgs.wrapBintoolsWith { bintools = temp.binutils; inherit libc; };
  cc = pkgs.wrapCCWith { cc = temp.gcc; inherit bintools libc; };
in
genericStdenv {
  name = "lfs-stdenv";
  inherit (pkgs.stdenv) buildPlatform hostPlatform targetPlatform;
  config = pkgs.config;
  shell = "${temp.bash}/bin/bash";
  initialPath = with temp; [ coreutils findutils diffutils gnused gnugrep gawk
                             gnutar gzip xz bzip2 gnumake bash gnupatch patchelf ];
  fetchurlBoot = import "${nixpkgs}/pkgs/build-support/fetchurl/boot.nix" {
    inherit (pkgs.stdenv.hostPlatform) system;
    inherit (pkgs.config) rewriteURL;
  };
  inherit cc;
  preHook = "dontPatchShebangs=1";
}
```

This uses the nixpkgs `wrapCCWith`, and those wrapper scripts run with the
*host* bash and coreutils. That is a known leak. You remove it in step 11.

You also need `nixpkgs` (the flake input) in `bootstrap/default.nix`. Pass it
from `flake.nix`.

**Verify:**

```console
$ nix build .#packages.aarch64-linux.lfsStdenv -o result-lfs-stdenv
$ ls result-lfs-stdenv                             # setup (and nix-support)
$ grep -o '/nix/store/[a-z0-9]*-lfs-temp-[a-z]*' result-lfs-stdenv/setup | sort -u
                                                   # the temp tools from initialPath
$ nix path-info -r ./result-lfs-stdenv | grep -v -- '-lfs-'
                                                   # host bash, coreutils, gnugrep: the wrapper leak, expected now
$ nix why-depends ./result-lfs-stdenv <one-of-those-paths>
                                                   # the chain goes through the gcc wrapper
```

**Nix concepts:** [the stdenv internals](#stdenv-internals-setupsh-initialpath-cc-wrapper),
[`import` of nixpkgs files](#nix-language), [overlays and fixed points](#fixed-points-and-overlays).

### Step 10 — the first package built by your stdenv

**File to write:** a `hello` attribute

**Do:** build GNU hello with `lfsStdenv.mkDerivation`. Use `lfsStdenv.fetchurlBoot`
or `pkgs.fetchurl` for the source (a fixed-output derivation; both are fine).

**Verify:**

```console
$ nix build .#packages.aarch64-linux.hello -o result-hello -L
$ result-hello/bin/hello                           # Hello, world!
$ $B/$T-readelf -l result-hello/bin/hello | grep interpreter
                                                   # /nix/store/...-lfs-temp-glibc-2.40/lib/ld-linux-aarch64.so.1
$ $B/$T-readelf -d result-hello/bin/hello | grep RUNPATH
                                                   # the lfs-temp-glibc lib directory
$ $B/$T-readelf -p .comment result-hello/bin/hello # GCC: (GCC) 14.2.0  (lfs-temp-gcc)
$ nix path-info -r ./result-hello                  # hello + lfs-temp-glibc, nothing else
$ nix-store -q --references $(nix eval --raw .#packages.aarch64-linux.hello.drvPath)
                                                   # lfs-stdenv, lfs-temp-bash, the source, setup hooks:
                                                   # no nixpkgs gcc and no nixpkgs glibc
$ LD_DEBUG=libs result-hello/bin/hello 2>&1 | grep -E 'search cache|trying file'
                                                   # see the note below
```

The `LD_DEBUG` check can show `search cache=/etc/ld.so.cache`. Your glibc reads
the cache of the Ubuntu VM at run time. That is a runtime leak. nixpkgs fixes it
with `dont-use-system-ld-so-cache.patch` in
`pkgs/development/libraries/glibc/`. Apply it to the glibc in step 11.

**Nix concepts:** [build-time and runtime closure](#references-and-closures),
[`.drv` files](#evaluation-and-build).

### Step 11 — rebuild everything with itself

Your temporary tools were built by a cross compiler and are static. Rebuild
them natively, with `lfsStdenv`, as normal dynamic Nix packages. Do it in the
same order as nixpkgs, because each stage may only use the stage before it.

**Do:**

1. `lfs-final-glibc` with `lfsStdenv`. Apply `dont-use-system-ld-so-cache.patch`.
2. `lfsStdenv1`: the same as `lfsStdenv`, but with `libc = lfs-final-glibc` in
   both wrappers.
3. With `lfsStdenv1`: `lfs-final-binutils`, `lfs-final-gcc` (with
   `no-sys-dirs`), and the `lfs-final-*` versions of all tools from step 7.
   They are dynamic now. Remove `LDFLAGS = "-static"` and the `--host` flags.
4. `lfsStdenvFinal`: like step 9, but call `pkgs/build-support/cc-wrapper` and
   `bintools-wrapper` directly, as `stageFun` does. Pass
   `coreutils`, `gnugrep` and `runtimeShell` from the `lfs-final-*` set. That
   removes the wrapper leak from step 9.
5. Set `disallowedRequisites` on `lfsStdenvFinal` to every `lfs-` and
   `lfs-temp-` package. The build then fails if one of them leaks in.

**Verify:**

```console
$ nix build .#packages.aarch64-linux.lfsStdenvFinal -o result-final-stdenv -L
$ nix build .#packages.aarch64-linux.helloFinal -o result-final-hello -L
$ result-final-hello/bin/hello                     # Hello, world!
$ $B/$T-readelf -l result-final-hello/bin/hello | grep interpreter    # ...-lfs-final-glibc-2.40/...
$ LD_DEBUG=libs result-final-hello/bin/hello 2>&1 | grep -c 'search cache'    # 0
```

**Nix concepts:** [stdenv stages](#stdenv-internals-setupsh-initialpath-cc-wrapper),
[`disallowedRequisites`](#references-and-closures).

### Step 12 — the proof (milestone 2)

**Verify:**

```console
# 1. Nothing from steps 1 to 8 in the final stdenv.
$ nix path-info -r ./result-final-stdenv | grep -E -- '-lfs-(temp-|binutils|gcc-stage|glibc|sysroot)'
                                                   # no output

# 2. Nothing from nixpkgs that contains code.
$ nix path-info -r ./result-final-stdenv | grep -v -- '-lfs-final-' | grep -v -- '-lfs-stdenv'
                                                   # only setup-hook .sh files and setup.sh copied from nixpkgs

# 3. The same for a package.
$ nix path-info -r ./result-final-hello            # hello + lfs-final-glibc

# 4. Reproducible: build again and compare.
$ nix build .#packages.aarch64-linux.helloFinal --rebuild
                                                   # no "differs" message
```

If check 4 reports a difference, compare the two outputs with `diffoscope`
(`nix run nixpkgs#diffoscope -- <path> <path>.check`, with `--keep-failed`).

**This is milestone 2:** a stdenv in which your own tools built every binary.
The host still provided the kernel, the Nix daemon and the sandbox `/bin/sh`.
Those are the limits of way A.

**Nix concepts:** [reproducibility](#reproducibility).

---

## Part 4 — Next: a userspace

Build busybox (or the `lfs-final-*` tools), an `init` and a kernel with
`lfsStdenvFinal`. Assemble a tree with `runCommand`, and boot it in QEMU. This
is where "distro" starts. It is a different project with a different failure
mode (boot, not build).

---

## Debugging a build

```console
$ nix build .#packages.aarch64-linux.<name> -L            # stream the full log
$ nix log .#packages.aarch64-linux.<name>                 # the log of the last failed build
$ nix build .#packages.aarch64-linux.<name> --keep-failed # keep the build directory under /tmp
$ nix develop .#packages.aarch64-linux.<name>             # a shell with the build environment
```

In `nix develop`, run the phases by hand: `unpackPhase`, `cd` into the source,
then `configurePhase`, `buildPhase`. Change a flag and run the phase again.
This takes seconds instead of a full rebuild. Note that `nix develop` runs
outside the sandbox: host files such as `/usr/include` are visible there.

When you change a `configureFlag`, every later step rebuilds. That is the
dependency graph doing its job. Reach milestone 1 before you optimise
anything.

---

## Nix concepts

Each entry says what the concept is, why it matters here, and where to read
more. Read an entry when a step lists it and you do not know it yet.

Main references:

- Nix reference manual: <https://nix.dev/manual/nix/latest/>
- nixpkgs manual: <https://nixos.org/manual/nixpkgs/stable/>
- Nix Pills (a tutorial series that builds a stdenv from nothing):
  <https://nixos.org/guides/nix-pills/>
- nix.dev tutorials: <https://nix.dev/>

### Nix language

Attribute sets `{ a = 1; }`, functions `{ a, b }: ...`, `let ... in`, `rec`,
`inherit`, string interpolation `"${x}"`, multi-line strings `'' ... ''`,
`import ./file.nix`, the update operator `a // b`, and `@args` (the whole
argument set). Every `.nix` file in this repo is one function.
Read: <https://nix.dev/tutorials/nix-language>.

### Flakes

`flake.nix` declares `inputs` (here nixpkgs) and `outputs` (here
`packages.aarch64-linux.*`). `flake.lock` pins each input to one revision and
hash. `.#packages.aarch64-linux.binutils` is an *installable*: "this flake,
that output". Read: <https://nix.dev/concepts/flakes> and
`nix flake --help`.

### Evaluation and build

Nix works in two phases. **Evaluation** runs the Nix language and produces
`.drv` files: exact build recipes. **Build** (realisation) runs a `.drv` and
produces store paths. `nix eval .#x.drvPath` only evaluates. That is why the
repo evaluates on macOS but cannot build there. `nix derivation show` and
`nix-store -q --references <drv>` show what a `.drv` contains. Read: the Nix
manual, "Derivations"; Nix Pills 6 and 7.

### The store

Every build output is a directory under `/nix/store/<hash>-<name>`. The hash
comes from all inputs of the build. Store paths never change after the build.
That is why LFS's shared `$LFS` directory has no direct equivalent here
(steps 2, 4 and 5). Read: the Nix manual, "Nix Store".

### The sandbox

On Linux, each build runs in a chroot with namespaces. It sees only the store
paths it declares, plus `/dev`, `/proc`, a `/bin/sh` and a temporary build
directory. It has no network. This is the Nix equivalent of the LFS chroot.
`nix config show sandbox` shows whether it is on. Read: the Nix manual,
`nix.conf`, option `sandbox`.

### Fixed-output derivations

A derivation that declares its output hash in advance, such as `fetchurl`. It
is the only kind of build that gets network access, because Nix can check the
result. `lib.fakeHash` is a placeholder that always fails, so Nix prints the
real hash. Hashes use the SRI format `sha256-<base64>`; `nix hash convert`
converts from hex. Read: the nixpkgs manual, "Fetchers".

### `stdenv.mkDerivation` and phases

The standard builder. It runs phases in order: `unpackPhase`, `patchPhase`,
`configurePhase`, `buildPhase`, `checkPhase`, `installPhase`, `fixupPhase`.
You change a phase with attributes (`configureFlags`, `configureScript`,
`dontAddPrefix`, `configurePlatforms`, `makeFlags`, `installFlags`,
`patches`) or hooks (`preConfigure`, `postInstall`). Custom phases must call
`runHook preX` and `runHook postX`, as `headers.nix` does. Read: the nixpkgs
manual, "The Standard Environment"; Nix Pill 19.

### `$out` and `placeholder "out"`

`$out` is the output store path, set as a shell variable during the build.
In Nix code the path is not known yet; `placeholder "out"` gives a string that
Nix replaces with the real path. `binutils.nix` uses it in `--prefix`.
Read: the Nix manual, "Built-in functions", `placeholder`.

### `nativeBuildInputs`, `buildInputs` and `PATH`

`nativeBuildInputs` are tools that run during the build. `buildInputs` are
libraries for the result. For each input, stdenv adds `$pkg/bin` to `PATH`,
and runs the package's setup hook. Only `$pkg/bin`: not `$pkg/tools/bin`
(step 2). Read: the nixpkgs manual, "Specifying dependencies"; Nix Pill 20.

### Multiple outputs, `lib.getDev`, `lib.getLib`

One derivation can produce several store paths: `out`, `dev` (headers),
`lib` (libraries), `man`. `lib.getDev gmp` returns the `dev` output if it
exists. That is why `gcc-stage1.nix` passes different paths for `include` and
`lib`. Read: the nixpkgs manual, "Multiple-output packages".

### `callPackage`

`callPackage ./file.nix { extra = ...; }` calls the function in the file and
fills its arguments from nixpkgs by name. `.override` changes those arguments
later; `.overrideAttrs` changes the `mkDerivation` attributes. Read: Nix
Pill 13; nix.dev, "callPackage".

### Platforms: build, host, target

`buildPlatform` runs the build, `hostPlatform` runs the result, and
`targetPlatform` is what a compiler produces code for. In this repo all three
are aarch64, but your triple `aarch64-lfs-linux-gnu` is a different *name*,
so autoconf treats steps 1 to 8 as cross builds. `configurePlatforms = [ ]`
stops stdenv from adding `--build` and `--host` itself. Read: the nixpkgs
manual, "Cross-compilation".

### Hardening flags

nixpkgs' cc-wrapper adds flags such as `-fstack-protector-strong` and
`-Werror=format-security` to every compile. `hardeningDisable` turns one off.
The flags come from the wrapper, so an unwrapped compiler (your gcc in steps 2
to 8) never sees them. Read: the nixpkgs manual, "Hardening in Nixpkgs".

### The fixup phase: strip, patchelf, patchShebangs

After install, stdenv strips debug symbols, shrinks `RPATH` with `patchelf`,
and rewrites `#!` lines to store paths. This is helpful for normal packages,
but wrong for a libc in a sysroot and for target files. Turn it off with
`dontStrip`, `dontPatchELF` and `dontPatchShebangs` (steps 4 and 8). Read:
the nixpkgs manual, "The fixup phase".

### Trivial builders: `runCommand`, `buildEnv`, `symlinkJoin`

Small builders for small jobs. `runCommand name env script` runs a shell
script. `buildEnv` and `symlinkJoin` make a tree of symlinks. Symlinks break
the sysroot check of `ld` (step 5). Read: the nixpkgs manual, "Trivial build
helpers".

### References and closures

Nix finds runtime dependencies by scanning the output for the hashes of other
store paths. The set of all of them is the **closure**.

- `nix path-info -r <path>` lists the closure.
- `nix why-depends <a> <b>` shows why `a` refers to `b`.
- `nix-store -q --references <drv>` lists the direct inputs of a recipe (the
  build-time view).
- `allowedRequisites` and `disallowedRequisites` make a build fail when its
  closure has, or misses, a path.

This is the main tool for proving that no host binary is left (steps 7, 10
and 12). Read: the Nix manual, `nix path-info` and `nix why-depends`.

### Debugging a build

`-L` streams logs. `nix log` shows the last log. `--keep-failed` keeps the
build directory. `nix develop` opens a shell with the build environment, where
you run phases by hand. Read: nix.dev, "Troubleshooting"; `nix develop --help`.

### Stdenv internals: setup.sh, initialPath, cc-wrapper

A stdenv is a derivation with `setup` (from `pkgs/stdenv/generic/setup.sh`),
a `shell`, an `initialPath` (the tools on `PATH` in every build) and a `cc`.
The `cc` is a **wrapper**: a script around the real gcc that adds `-B`,
`-idirafter`, `-dynamic-linker` and `RPATH` flags for the libc in the store,
so no sysroot is needed. `bintools-wrapper` does the same for `ld`. nixpkgs
builds its own stdenv in stages (`pkgs/stdenv/linux/default.nix`): each stage
uses only the stage before. Read: Nix Pills 12 and 19; the nixpkgs manual,
"The Standard Environment"; the source of `pkgs/build-support/cc-wrapper/`.

### Fixed points and overlays

nixpkgs is one big function of itself (`self: super: { ... }`). Overlays change
packages in it, and every user of a package sees the change. You need this
if you later want all of nixpkgs on your stdenv (`import nixpkgs { stdenvStages = ...; }`).
Read: the nixpkgs manual, "Overlays"; Nix Pill 17.

### Reproducibility

Nix pins *inputs*. It does not prove that two builds give the same bytes.
`nix build --rebuild` builds again and compares. `diffoscope` shows the
difference. Read: <https://reproducible-builds.org/>.

---

## Status

- Steps 1 to 3 are written and evaluate (`nix eval` of each `drvPath`). No
  step has been built yet.
- A review found that step 2 could not find the target binutils. That is fixed
  but also not built.
- Steps 4 to 12 are design notes. You write the code.
- The configure flags come from LFS. The LFS book targets x86_64; the aarch64
  adaptation here is untested. Where a derivation diverges from LFS, a comment
  says so.
