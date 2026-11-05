# Step 13 — the rule and the layout (read, no build)

**Nix concepts for this step**

From earlier steps: [closures](appendix-nix-concepts.md#references-and-closures) (step 1), [`nix shell`](appendix-nix-concepts.md#flakes) (step 8).

---

**The rule for Part 4.** nixpkgs can build and run *tools*: the kernel's build
tools, the initramfs and disk-image builders, and QEMU. Every file *inside the
image*, and the kernel, comes from `lfsStdenvFinal`. Step 20 checks this.

**The layout.** The image uses the same idea as NixOS: a `/nix/store` with the
closure of your system, plus a few FHS symlinks so that `/bin/sh` and
`#!/usr/bin/env` work.

```
/nix/store/...           the closure of everything below
/bin  -> <sysenv>/bin    GNU tools, bash, busybox applets, gcc
/sbin -> <sysenv>/sbin   busybox init, mount, poweroff, ...
/usr/bin -> <sysenv>/bin
/etc  -> <etc>           passwd, group, hostname, inittab, rc, profile
/init -> <init script>   only in the initramfs
/proc /sys /dev /tmp     created at boot
```

**The boot flow:**

```
QEMU -kernel Image  ->  kernel  ->  /init (initramfs) or /sbin/init (disk)
                                     -> busybox init reads /etc/inittab
                                        -> ::sysinit: /etc/rc (mounts)
                                        -> ttyAMA0::respawn: -/bin/bash
```

**Do:** restart the VM with nested virtualization, so that QEMU can use KVM.
Your Mac (M4 Pro, macOS 26) supports it.

```console
$ tart stop lfs; tart run lfs --no-graphics --nested &
```

**Verify (in the VM):**

```console
$ ls -l /dev/kvm                                   # exists; without it QEMU emulates (slower, still works)
$ nix shell nixpkgs#qemu -c qemu-system-aarch64 --version | head -1
```
