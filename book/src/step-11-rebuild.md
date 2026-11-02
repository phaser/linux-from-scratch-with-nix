# Step 11 — rebuild everything with itself

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

**Nix concepts:** [stdenv stages](appendix-nix-concepts.md#stdenv-internals-setupsh-initialpath-cc-wrapper),
[`disallowedRequisites`](appendix-nix-concepts.md#references-and-closures).
