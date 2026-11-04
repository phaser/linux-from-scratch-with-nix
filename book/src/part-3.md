# Part 3 — Leaving the host (way A)

Until now the host stdenv built every tool. This part builds a stdenv in which
your tools do everything. It is LFS chapters 6 to 8, in Nix.

## The ways to leave the host

There are four ways to get from your cross toolchain to a stdenv with no host
binary in it. This book uses way A.

| Way | What you do | Result |
|---|---|---|
| **A — by hand** (this book) | Write each stage as a derivation: temporary tools, a native toolchain, `lfsStdenv`, then a rebuild with itself. | A stdenv made of your packages. Each stage is visible and has checks. |
| **B — your seed for the nixpkgs bootstrap** | Make a bootstrap-tools tarball from your toolchain, and give it to nixpkgs as `bootstrapFiles` (`pkgs/stdenv/linux/default.nix`). nixpkgs then does its own stages. | All of nixpkgs, built from your seed. |
| **C — full-source bootstrap** | Start from the nixpkgs `minimal-bootstrap` (`pkgs/os-specific/linux/minimal-bootstrap`): a seed of a few hundred bytes, then GNU Mes, tinycc and gcc. | No compiler binary from outside at all. |
| **D — the LFS chroot** | Build the LFS chapter 7 tree with `/usr` paths, then build chapter 8 inside it with `chroot`, in one large derivation or outside Nix. | An LFS system, but no Nix stdenv. |

**Why way A.**

- **You see each stage.** Way B uses the stages that nixpkgs already has. You
  supply the seed, and nixpkgs does the work. A failure then occurs deep in
  the nixpkgs stage code, not in a file that you wrote. Also, the tarball must
  have the exact layout that the nixpkgs stages expect.
- **It works on aarch64.** In way C, the Mes and tinycc stages support only
  `i686-linux` and `x86_64-linux`. This book builds for aarch64.
- **It gives a Nix stdenv.** Way D gives one FHS tree. It has no store paths,
  no cache for each package, and no closure checks. Milestone 2 needs a stdenv
  and `nix path-info -r`.
- **It follows LFS.** Steps 7 to 11 match LFS chapters 6 to 8, so you can
  compare each step with the LFS book.

After way A, ways B and C are easier to understand. Read
`pkgs/stdenv/linux/default.nix`: its stages do what steps 7 to 11 do. Step 12
shows what way A does not remove: the host kernel, the Nix daemon and the
sandbox `/bin/sh`.

## The plan

| Step | Builds | Built by | Runs with |
|---|---|---|---|
| 7 | Static temporary tools (bash, coreutils, make, ...) | gcc stage 2 (cross) | No loader (static) |
| 8 | glibc (Nix layout), native binutils and gcc | gcc stage 2 (cross) | Static, or glibc from step 8 |
| 9 | `lfsStdenv` | Assembled from steps 7 and 8 | — |
| 10 | A test package (GNU hello) | `lfsStdenv` | glibc from step 8 |
| 11 | Everything again, as `lfs-final-*` | `lfsStdenv` | Final glibc |
| 12 | Proof | — | — |

Chapters in this part:

- [Step 7 — static temporary tools](step-07-temp-tools.md)
- [Step 8 — glibc for the store, native binutils, native gcc](step-08-native-toolchain.md)
- [Step 9 — `lfsStdenv`](step-09-lfs-stdenv.md)
- [Step 10 — the first package built by your stdenv](step-10-first-package.md)
- [Step 11 — rebuild everything with itself](step-11-rebuild.md)
- [Step 12 — the proof (milestone 2)](step-12-proof.md)
