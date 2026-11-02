# my-linux-distro

A Nix implementation of the *interesting* half of Linux From Scratch: build a
Linux toolchain from source, use it to build a Nix `stdenv` that contains no
binary from the host, then build a minimal Linux system with that stdenv and
boot it in QEMU.

## The book

The guide is a book with one chapter per step. Start here:
**[book/src/introduction.md](book/src/introduction.md)**. The table of
contents is [book/src/SUMMARY.md](book/src/SUMMARY.md).

| Part | Steps | Result |
|---|---|---|
| [0 — The environment](book/src/part-0.md) | 0 | A Linux VM with Nix |
| [1 — The cross toolchain](book/src/part-1.md) | 1 to 3 | binutils, gcc stage 1, kernel headers (implemented in `bootstrap/`) |
| [2 — libc and the full cross compiler](book/src/part-2.md) | 4 to 6 | Milestone 1: a binary that runs on your glibc |
| [3 — Leaving the host](book/src/part-3.md) | 7 to 12 | Milestone 2: a stdenv with no host binary |
| [4 — A minimal root distro](book/src/part-4.md) | 13 to 20 | Milestones 3 and 4: a system that boots and compiles |
| [Appendix A — Debugging a build](book/src/appendix-debugging.md) | | |
| [Appendix B — Nix concepts](book/src/appendix-nix-concepts.md) | | |

To read it as a web site:

```console
$ nix run nixpkgs#mdbook -- serve book --open
```

## Quick start

You need an `aarch64-linux` machine with Nix. On a Mac, use a VM (chapter
[Step 0](book/src/step-00-vm.md)). Then:

```console
$ nix build .#packages.aarch64-linux.binutils -o result-binutils -L
```

## Status

Steps 1 to 3 are written and evaluate. No step has been built yet. Steps 4 to
20 are design notes; you write the code.
