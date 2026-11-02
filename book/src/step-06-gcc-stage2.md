# Step 6 — gcc stage 2 (milestone 1)

**File to write:** `lfs-toolchain/gcc-stage2/default.nix`, attribute `gccStage2`

This is a full cross compiler: C and C++, linked against your glibc through the
sysroot. It follows crosstool-ng's "final gcc" more than LFS.

**Do:** copy your `lfs-toolchain/gcc-stage1/default.nix`, then change it:

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
$ nix build .#gccStage2 -o result-gcc2 -L    # about 20 to 40 minutes
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

Then add the `toolchain` attribute to `lfs-toolchain/default.nix`: a
`linkFarm` of all six components. `nix build .#toolchain` now builds the whole
toolchain.

**This is milestone 1:** a compiler you built, linking against a libc you
built, producing a binary that runs.

**If it fails:** `libsanitizer` errors: add `--disable-libsanitizer`.

**Nix concepts:** [`callPackage` and `override`](appendix-nix-concepts.md#callpackage),
[debugging a build](appendix-nix-concepts.md#debugging-a-build).
