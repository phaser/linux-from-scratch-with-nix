# Introduction

A Nix implementation of the *interesting* half of Linux From Scratch: build a
Linux toolchain from source, use it to build a Nix `stdenv` that contains no
binary from the host, then build a minimal Linux system with that stdenv and
boot it in QEMU.

This is **way A**: do the bootstrap by hand, one derivation at a time, so that
every step is visible. nixpkgs does the same job in
`pkgs/stdenv/linux/default.nix`. Read that file after you finish; you will
recognise every stage.

You write every derivation. Each chapter tells you what to write and how to
check it. Steps 1 to 3 also have an answer key in `solutions/`.

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

## The code layout

Each part of the book has its own directory. Each component has its own
directory with a `default.nix`. The `default.nix` at the top of a directory
collects its components.

```
flake.nix                   wires the directories into the flake
lfs-toolchain/  steps 1-6   binutils/ gcc-stage1/ linux-headers/ glibc/ sysroot/ gcc-stage2/
lfs-temp/       steps 7-8   lib.nix (the helper), one directory per tool, glibc/ binutils/ gcc/
lfs-stdenv/     steps 9-10  default.nix (lfsStdenv), hello/
lfs-final/      step 11     one directory per package, default.nix (lfsStdenvFinal)
lfs-distro/     steps 14-18 kernel/ busybox/ sysenv/ etc/ init/ initrd/ root-image/
solutions/      the answer key, in the same tree (steps 1-3 today)
```

`lfs-toolchain/default.nix` exists already, empty. Create the other
directories when you reach their part. `flake.nix` exposes everything under
`legacyPackages.aarch64-linux`:

| Directory | How `flake.nix` imports it | Attributes the checks use |
|---|---|---|
| `lfs-toolchain/` | Merged at the top (done) | `binutils`, `gccStage1`, `headers`, `glibc`, `sysroot`, `gccStage2`, `toolchain` |
| `lfs-temp/` | As `temp` | `temp.gnumake` ... `temp.tools`, `temp.glibc`, `temp.binutils`, `temp.gcc` |
| `lfs-stdenv/` | Merged at the top | `lfsStdenv`, `hello` |
| `lfs-final/` | Merged at the top | `lfsStdenvFinal`, `helloFinal` |
| `lfs-distro/` | Merged at the top | `kernel`, `busybox`, `sysenv`, `etc`, `init`, `initrd`, `rootImage` |
| `solutions/lfs-toolchain/` | As `solutions` (done) | `solutions.binutils`, `solutions.gccStage1`, `solutions.headers`, `solutions.toolchain` |

On an aarch64-linux machine, `.#binutils` is short for
`.#legacyPackages.aarch64-linux.binutils`.

## Conventions

- Run every command **inside the Linux VM**, in the repo directory.
- Give every build its own out-link with `-o`, so the results of earlier steps
  stay available:

  ```console
  $ nix build .#binutils -o result-binutils
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

- The answer key for steps 1 to 3 evaluates (`nix eval` of each `drvPath`).
  No step has been built yet.
- A review found that the step 2 answer could not find the target binutils.
  That is fixed but also not built.
- Steps 4 to 20 have no answer key.
- Part 4 uses nixpkgs for tools that run during the build (kernel build
  tools, `makeInitrd`, `make-ext4-fs.nix`, QEMU), and for the busybox recipe.
  Everything inside the image is built by your stdenv. Step 20 checks this.
- The configure flags come from LFS. The LFS book targets x86_64; the aarch64
  adaptation here is untested. Where a derivation diverges from LFS, a comment
  says so.
