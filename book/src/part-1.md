# Part 1 — The cross toolchain

You write three derivations: binutils, gcc stage 1 and the kernel headers.
Each one goes in its own directory under `lfs-toolchain/`. The host compiler
builds all three, as in LFS pass 1.

These three chapters have an answer key in `solutions/lfs-toolchain/`. Write
your own version first, and run all the checks. Then compare.

Chapters in this part:

- [Step 1 — binutils](step-01-binutils.md)
- [Step 2 — gcc stage 1](step-02-gcc-stage1.md)
- [Step 3 — kernel headers](step-03-headers.md)
