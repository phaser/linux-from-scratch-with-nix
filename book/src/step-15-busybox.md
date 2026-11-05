# Step 15 — busybox, from the nixpkgs recipe

**File to change:** `lfs-distro/default.nix`, attribute `busybox`, pname `lfs-final-busybox`. This step has no directory: it reuses the nixpkgs recipe.

busybox gives you `init`, `mount`, `poweroff`, `getty` and about 300 other
small tools. Here you use the nixpkgs *recipe* with *your* stdenv.

**Nix concepts for this step**

New in this step:

- **`override` and `overrideAttrs`.** A package from `callPackage` has
  `.override { stdenv = …; }`, which calls the recipe again with other
  arguments. `.overrideAttrs { pname = …; }` changes the attributes of
  `mkDerivation`. [More](appendix-nix-concepts.md#callpackage).

From earlier steps: [`callPackage`](appendix-nix-concepts.md#callpackage) (step 1).

---

**Do:**

```nix
busybox = (pkgs.busybox.override { stdenv = lfsStdenvFinal; }).overrideAttrs {
  pname = "lfs-final-busybox";
  depsBuildBuild = [ ];
};
```

`override` changes the arguments of the recipe. `overrideAttrs` changes the
`mkDerivation` attributes. The nixpkgs recipe already sets `CONFIG_TC n`; the
`tc` applet does not compile against recent kernel headers.

`depsBuildBuild = [ ]` is necessary. The recipe adds the nixpkgs compiler
(`buildPackages.stdenv.cc`) to `depsBuildBuild`. The busybox Makefile does not
use `$CC`. It runs `gcc` from `PATH`, and the nixpkgs `gcc` comes first.
Without this line, the nixpkgs GCC and glibc build busybox, and only the name
is yours. This is a native build, so busybox does not need a second compiler.

**Verify:**

```console
$ nix build .#busybox -o result-busybox -L
$ result-busybox/bin/busybox | head -1             # BusyBox v1.37.0 ...
$ result-busybox/bin/busybox --list | wc -l        # about 300
$ ls -l result-busybox/sbin/init                   # a symlink to ../bin/busybox
$ $B/$T-readelf -p .comment result-busybox/bin/busybox    # GCC: (GNU) 14.2.0
$ $B/$T-readelf -l result-busybox/bin/busybox | grep interpreter    # ...-lfs-final-glibc-2.40/...
$ nix path-info -r ./result-busybox                # busybox + lfs-final-glibc (+ its own outputs)
```

**If it fails:** the recipe uses an argument that your stdenv does not
provide. Read the error, then the recipe:
`pkgs/os-specific/linux/busybox/default.nix` in nixpkgs.

**If the closure has `glibc-2.44` or `xgcc-…-libgcc`:** the nixpkgs compiler
built busybox. Make sure that `depsBuildBuild = [ ];` is in `overrideAttrs`.
