# Step 17 — the initramfs and the first boot (milestone 3)

**File to write:** `lfs-distro/initrd/default.nix`, attribute `initrd`

**Nix concepts for this step**

New in this step:

- **`closureInfo`.** `makeInitrd` uses `closureInfo` to find the closure of
  each object, and copies it into the archive.
  [More](appendix-nix-concepts.md#closureinfo).
- **Compressed outputs hide references.** The reference scan looks for
  hashes in the bytes. In a compressed file it finds none.
  [More](appendix-nix-concepts.md#references-and-closures).

From earlier steps: [`nix shell`](appendix-nix-concepts.md#flakes) (step 8).

---

**Do:** use the nixpkgs helper `makeInitrd`. It copies the closure of each
object into `/nix/store` and creates the symlinks.

`makeInitrd` is not a `mkDerivation` that you write. It is a function of
nixpkgs that returns a derivation. Its output is a compressed cpio archive.
You give it a `name` and a list of `contents`.

`lfs-distro/initrd/default.nix`:

```nix
{ makeInitrd, init, sysenv, etc }:

makeInitrd {
  name = "lfs-initrd";
  contents = [
    { object = init;                symlink = "/init"; }
    { object = "${sysenv}/bin";      symlink = "/bin"; }
    { object = "${sysenv}/sbin";     symlink = "/sbin"; }
    { object = "${sysenv}/bin";      symlink = "/usr/bin"; }
    { object = etc;                 symlink = "/etc"; }
  ];
}
```

In `lfs-distro/default.nix`, add the attribute. `callPackage` gives
`makeInitrd` from `pkgs`. The other three are attributes of step 16:

```nix
initrd = pkgs.callPackage ./initrd { inherit init sysenv etc; };
```

In `flake.nix`, add `initrd` to `inherit (distro) …;`.

**Verify the archive:**

```console
$ nix build .#initrd -o result-initrd
$ ls -lL result-initrd/initrd                      # a gzip file, tens of MB
$ zcat result-initrd/initrd | result-busybox/bin/busybox cpio -t 2>/dev/null | grep -E '^(init|bin|etc|nix/store/[^/]*lfs-final-glibc[^/]*)$'
                                                   # init, bin, etc, and the glibc store path
$ nix path-info -r ./result-initrd                 # ONE line. See the note below.
```

The last check is a trap. Nix finds references by scanning for store hashes.
The archive is compressed, so Nix finds none. The closure check of the image
must run on its *inputs* (step 20), not on the archive.

**Boot (0a, Tart VM with KVM):**

```console
$ nix shell nixpkgs#qemu
$ qemu-system-aarch64 -M virt -accel kvm -cpu host -m 1024 -nographic \
    -kernel result-kernel/Image -initrd result-initrd/initrd \
    -append "console=ttyAMA0 rdinit=/init"
```

**Boot (0b, Docker container, or no `/dev/kvm`):** QEMU emulates the CPU
(TCG). This is slower, but it works.

```console
$ nix shell nixpkgs#qemu
$ qemu-system-aarch64 -M virt -accel tcg -cpu max -m 1024 -nographic \
    -kernel result-kernel/Image -initrd result-initrd/initrd \
    -append "console=ttyAMA0 rdinit=/init"
```

To leave QEMU: `Ctrl-a`, then `x`.

**Verify inside the guest:**

```console
# cat /proc/version          # Linux version 6.12.0 (lfs@lfs) (... (GCC) 14.2.0, GNU ld (GNU Binutils) 2.43) ...
# readlink /proc/1/exe       # /nix/store/...-lfs-final-busybox-.../bin/busybox
# grep -m1 libc /proc/self/maps    # .../lfs-final-glibc-2.40/lib/libc.so.6
# ls /nix/store | grep -v lfs-final- | grep -v gcc-wrapper | grep -v bintools-wrapper
                             # no output (or only setup-hook files; look at each one)
# ps                         # init, bash, ps: a very small system
# poweroff                   # clean shutdown through busybox init
```

**This is milestone 3:** a system that boots, with a kernel, init, shell and
libc built by your own toolchain.

**If it fails:**

| Symptom | Cause |
|---|---|
| No output at all | Wrong console. The `virt` machine uses `ttyAMA0`. |
| `Kernel panic - not syncing: No working init found` | `/init` is missing, not executable, or its shebang path is not in the archive. |
| `Attempted to kill init` | PID 1 exited. Check that `/init` ends with `exec /sbin/init`. |
| `can't open /dev/ttyAMA0` | `/etc/rc` did not mount `/dev`. |
