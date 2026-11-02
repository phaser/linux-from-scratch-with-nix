# Step 12 — the proof (milestone 2)

**Verify:**

```console
# 1. Nothing from steps 1 to 8 in the final stdenv.
$ nix path-info -r ./result-final-stdenv | grep -E -- '-lfs-(temp-|binutils|gcc-stage|glibc|sysroot)'
                                                   # no output

# 2. Nothing from nixpkgs that contains code.
$ nix path-info -r ./result-final-stdenv | grep -v -- '-lfs-final-' | grep -v -- '-lfs-stdenv'
                                                   # only setup-hook .sh files and setup.sh copied from nixpkgs

# 3. The same for a package.
$ nix path-info -r ./result-final-hello            # hello + lfs-final-glibc

# 4. Reproducible: build again and compare.
$ nix build .#packages.aarch64-linux.helloFinal --rebuild
                                                   # no "differs" message
```

If check 4 reports a difference, compare the two outputs with `diffoscope`
(`nix run nixpkgs#diffoscope -- <path> <path>.check`, with `--keep-failed`).

**This is milestone 2:** a stdenv in which your own tools built every binary.
The host still provided the kernel, the Nix daemon and the sandbox `/bin/sh`.
Those are the limits of way A.

**Nix concepts:** [reproducibility](appendix-nix-concepts.md#reproducibility).
