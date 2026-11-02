# Step 2 — gcc stage 1

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
- C23 errors in C files (`bool`, `true`, `false`): see step 1. gcc's own
  C++ files are not affected.
- Errors about `format-security`: add `hardeningDisable = [ "format" ];`.
  nixpkgs does the same for its own gcc.
- gmp, mpfr or mpc not found: `nix log` names the missing file. Check the
  `--with-*-include` and `--with-*-lib` paths.

**Nix concepts:** [`nativeBuildInputs` and `PATH`](appendix-nix-concepts.md#nativebuildinputs-buildinputs-and-path),
[multiple outputs](appendix-nix-concepts.md#multiple-outputs-libgetdev-libgetlib),
[hardening flags](appendix-nix-concepts.md#hardening-flags),
[debugging a build](appendix-nix-concepts.md#debugging-a-build).
