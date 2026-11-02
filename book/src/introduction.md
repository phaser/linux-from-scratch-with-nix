# Introduction

A Nix implementation of the *interesting* half of Linux From Scratch: build a
Linux toolchain from source, use it to build a Nix `stdenv` that contains no
binary from the host, then build a minimal Linux system with that stdenv and
boot it in QEMU.

This is **way A**: do the bootstrap by hand, one derivation at a time, so that
every step is visible. nixpkgs does the same job in
`pkgs/stdenv/linux/default.nix`. Read that file after you finish; you will
recognise every stage.

Steps 1 to 3 are implemented in `bootstrap/`. From step 4 on, this book tells
you what to write and how to check it. You write the code.

The book has five parts and two appendices. Each step is one chapter. Read
the parts in order: every step uses the results of the steps before it.
Appendix B explains the Nix concepts. Read an entry when a chapter links to
it and you do not know it yet.

## What success looks like

There are four milestones.

| Milestone | After step | Proof |
|---|---|---|
| 1. A binary that your compiler built, linked against your glibc, runs | 6 | It prints the version of *your* glibc, not the host glibc. |
| 2. A Nix `stdenv` with no host binary in it | 12 | `nix path-info -r` of the final stdenv shows only your packages. |
| 3. A minimal system boots in QEMU from an initramfs | 17 | `/proc/version` names your gcc; PID 1 is your busybox. |
| 4. The system boots from its own disk and compiles a program | 19 | `gcc` inside the guest builds a binary that prints `glibc 2.40`. |

## How to read each step

Each step has the same parts:

- **Do**: what to build or write.
- **Verify**: commands with the expected result as a comment. Run all of them.
  Do not continue to the next step if one check fails.
- **If it fails**: the most likely causes.
- **Nix concepts**: what you need to know for this step. Each name links to
  an entry in [Appendix B — Nix concepts](appendix-nix-concepts.md).

## Conventions

- Run every command **inside the Linux VM**, in the repo directory.
- Give every build its own out-link with `-o`, so the results of earlier steps
  stay available:

  ```console
  $ nix build .#packages.aarch64-linux.binutils -o result-binutils
  ```

- Set these variables once per shell. Later steps add more.

  ```console
  $ T=aarch64-lfs-linux-gnu
  $ B=$PWD/result-binutils/tools/bin
  ```

- Name every derivation with a prefix that tells where it belongs:

  | Prefix | Built by | Steps |
  |---|---|---|
  | `lfs-` | The host stdenv (cross tools, sysroot) | 1 to 6 |
  | `lfs-temp-` | Your cross compiler (temporary tools) | 7 and 8 |
  | `lfs-final-` | Your own stdenv | 11 to 20 |

  The checks in step 12 use these prefixes with `grep`.

## Status

- Steps 1 to 3 are written and evaluate (`nix eval` of each `drvPath`). No
  step has been built yet.
- A review found that step 2 could not find the target binutils. That is fixed
  but also not built.
- Steps 4 to 20 are design notes. You write the code.
- Part 4 uses nixpkgs for tools that run during the build (kernel build
  tools, `makeInitrd`, `make-ext4-fs.nix`, QEMU), and for the busybox recipe.
  Everything inside the image is built by your stdenv. Step 20 checks this.
- The configure flags come from LFS. The LFS book targets x86_64; the aarch64
  adaptation here is untested. Where a derivation diverges from LFS, a comment
  says so.
