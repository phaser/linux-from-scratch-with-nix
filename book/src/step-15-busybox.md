# Step 15 — busybox, from the nixpkgs recipe

**File to write:** `lfs-distro/busybox/default.nix`, attribute `busybox`, pname `lfs-final-busybox`

busybox gives you `init`, `mount`, `poweroff`, `getty` and about 300 other
small tools. Here you use the nixpkgs *recipe* with *your* stdenv.

**Do:**

```nix
busybox = (pkgs.busybox.override { stdenv = lfsStdenvFinal; }).overrideAttrs {
  pname = "lfs-final-busybox";
};
```

`override` changes the arguments of the recipe. `overrideAttrs` changes the
`mkDerivation` attributes. The nixpkgs recipe already sets `CONFIG_TC n`; the
`tc` applet does not compile against recent kernel headers.

**Verify:**

```console
$ nix build .#busybox -o result-busybox -L
$ result-busybox/bin/busybox | head -1             # BusyBox v1.37.0 ...
$ result-busybox/bin/busybox --list | wc -l        # about 300
$ ls -l result-busybox/sbin/init                   # a symlink to ../bin/busybox
$ $B/$T-readelf -p .comment result-busybox/bin/busybox    # GCC: (GCC) 14.2.0
$ $B/$T-readelf -l result-busybox/bin/busybox | grep interpreter    # ...-lfs-final-glibc-2.40/...
$ nix path-info -r ./result-busybox                # busybox + lfs-final-glibc (+ its own outputs)
```

**If it fails:** the recipe uses an argument that your stdenv does not
provide. Read the error, then the recipe:
`pkgs/os-specific/linux/busybox/default.nix` in nixpkgs.

**Nix concepts:** [`override` and `overrideAttrs`](appendix-nix-concepts.md#callpackage).
