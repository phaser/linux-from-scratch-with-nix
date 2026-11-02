# Part 3 — Leaving the host (way A)

Until now the host stdenv built every tool. This part builds a stdenv in which
your tools do everything. It is LFS chapters 6 to 8, in Nix.

The plan:

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
