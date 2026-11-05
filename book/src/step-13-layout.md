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

QEMU runs the image in steps 17 to 19. With KVM, QEMU runs the guest at
almost full speed. Without KVM, QEMU emulates the CPU (TCG): this is slower,
but it works. Do the part for your route of step 0.

**Do (0a, Tart VM):** restart the VM with nested virtualization, so that QEMU
can use KVM. Apple silicon M3 or later, with macOS 15 or later, supports it.

```console
$ tart stop lfs; tart run lfs --no-graphics --nested &
```

**Do (0b, Docker container):** nothing. The Docker VM on the Mac gives the
container no KVM. QEMU uses TCG.

**Verify** (in the VM or in the container):

```console
$ ls -l /dev/kvm                                   # 0a: exists. 0b: No such file or directory
$ nix shell nixpkgs#qemu -c qemu-system-aarch64 --version | head -1
                                                   # QEMU emulator version ...
```

The QEMU commands in steps 17 and 18 use KVM:

| Route | QEMU options |
|---|---|
| 0a, with `/dev/kvm` | `-accel kvm -cpu host` |
| 0b, or no `/dev/kvm` | `-accel tcg -cpu max` |

In the container, QEMU runs in the terminal of `docker compose run`
(`-nographic`). To leave QEMU: `Ctrl-a`, then `x`.
