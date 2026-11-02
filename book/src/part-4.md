# Part 4 — A minimal root distro

A kernel and a root file system that boot in QEMU, with a shell, the core
tools and your compiler. This is where "distro" starts. The failure mode
changes: from "it does not build" to "it does not boot".

Chapters in this part:

- [Step 13 — the rule and the layout (read, no build)](step-13-layout.md)
- [Step 14 — the kernel](step-14-kernel.md)
- [Step 15 — busybox, from the nixpkgs recipe](step-15-busybox.md)
- [Step 16 — the system tree](step-16-system-tree.md)
- [Step 17 — the initramfs and the first boot (milestone 3)](step-17-initramfs.md)
- [Step 18 — root on an ext4 disk](step-18-root-disk.md)
- [Step 19 — the system builds a program (milestone 4)](step-19-self-hosting.md)
- [Step 20 — the proof for the image](step-20-image-proof.md)
