# Step 1 — binutils

**File:** `bootstrap/binutils.nix`

The host compiler builds binutils on purpose. This is LFS pass 1. The result
runs on the host and produces code for the `aarch64-lfs-linux-gnu` triple.

**Do:**

1. Get the source hash. You have two ways:
   - Build once and let it fail. Copy the `got:` hash from the error to
     replace `lib.fakeHash`.
   - Or ask Nix directly:

     ```console
     $ nix store prefetch-file https://ftp.gnu.org/gnu/binutils/binutils-2.43.tar.xz
     ```

2. Build:

   ```console
   $ nix build .#packages.aarch64-linux.binutils -o result-binutils -L
   ```

**Verify:**

```console
$ $B/$T-ld --version | head -1               # GNU ld (GNU Binutils) 2.43
$ ls $B | head                               # every tool has the aarch64-lfs-linux-gnu- prefix
$ $B/$T-ld -V | grep -A3 emulations          # aarch64linux among the emulations
$ $B/$T-ld --verbose | grep SEARCH_DIR       # no /usr/lib and no /lib: there is no sysroot yet
$ nix path-info -r ./result-binutils         # host glibc and friends: rung 1 runs ON the host
$ nix why-depends ./result-binutils $(nix path-info -r ./result-binutils | grep -- '-glibc-' | head -1)
```

The last two checks show that the host still owns this binary. That is
expected until step 11.

**If it fails:**

- After the hash, read the end of the log with `nix log`.
- Errors about `bool`, `true`, `false` or old-style function declarations:
  the host compiler is nixpkgs gcc 16.2, which uses C23 by default. Add
  `env.NIX_CFLAGS_COMPILE = "-std=gnu17";`.

**Nix concepts:** [fixed-output derivations](appendix-nix-concepts.md#fixed-output-derivations),
[`stdenv.mkDerivation` and phases](appendix-nix-concepts.md#stdenvmkderivation-and-phases),
[`placeholder "out"`](appendix-nix-concepts.md#out-and-placeholder-out),
[references and closures](appendix-nix-concepts.md#references-and-closures),
[`callPackage`](appendix-nix-concepts.md#callpackage).
