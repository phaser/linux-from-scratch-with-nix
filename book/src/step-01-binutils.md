# Step 1 — binutils

**File to write:** `lfs-toolchain/binutils/default.nix`, attribute `binutils`

**Read first:** the LFS book, chapter 5, "Binutils - Pass 1"
(<https://www.linuxfromscratch.org/lfs/view/stable/>).

The host compiler builds binutils on purpose. This is LFS pass 1. The result
runs on the host and produces code for the `aarch64-lfs-linux-gnu` triple.

**Do:** write a derivation that meets these requirements.

1. The file is a function of `{ lib, stdenv, fetchurl, triple }`. Call it from
   `lfs-toolchain/default.nix` with `callPackage ./binutils { inherit triple; };`.
2. The source is binutils **2.43** from the GNU mirror (`mirror://gnu/...`).
   The later chapters expect this version.
3. The build is out of tree, in a `build/` directory, as in LFS.
4. The tools install under `$out/tools`, as LFS installs under `$LFS/tools`.
5. Take the configure flags from LFS and translate each one. Two of them need a
   decision. Write your reason in a comment:
   - `--prefix=$LFS/tools`: what is the Nix equivalent of `$LFS`?
   - `--with-sysroot=$LFS`: is there a sysroot yet?
6. `meta.platforms` says that it builds only on Linux.

<details>
<summary>Hint 1: the source hash</summary>

Set `hash = lib.fakeHash;` and build. The build fails and prints the real hash
after `got:`. Copy it into the file. Or ask Nix before you build:

```console
$ nix store prefetch-file https://ftp.gnu.org/gnu/binutils/binutils-2.43.tar.xz
```

</details>

<details>
<summary>Hint 2: the prefix</summary>

stdenv adds `--prefix=$out` to the configure flags itself. Look up
`dontAddPrefix`. In Nix code, `$out` is not known yet: look up
`placeholder "out"`.

</details>

<details>
<summary>Hint 3: the out-of-tree build</summary>

You need a hook that runs before configure, and a way to tell stdenv where the
configure script is. Look up `preConfigure` and `configureScript`.

</details>

**Build:**

```console
$ nix build .#binutils -o result-binutils -L
```

**Verify:**

```console
$ $B/$T-ld --version | head -1               # GNU ld (GNU Binutils) 2.43
$ ls $B | head                               # every tool has the aarch64-lfs-linux-gnu- prefix
$ $B/$T-ld -V | grep -A3 emulations          # aarch64linux among the emulations
$ $B/$T-ld --verbose | grep SEARCH_DIR       # no /usr/lib and no /lib: there is no sysroot yet
$ nix path-info -r ./result-binutils         # host glibc and friends: step 1 runs ON the host
$ nix why-depends ./result-binutils $(nix path-info -r ./result-binutils | grep -- '-glibc-' | head -1)
```

The last two checks show that the host still owns this binary. That is
expected until step 11.

**Compare with the answer key** (only after your checks pass):

```console
$ diff -u solutions/lfs-toolchain/binutils/default.nix lfs-toolchain/binutils/default.nix
$ nix run nixpkgs#nix-diff -- $(nix eval --raw .#solutions.binutils.drvPath) $(nix eval --raw .#binutils.drvPath)
```

`diff` compares the Nix code. `nix-diff` compares the two build recipes
(`.drv`): flags, environment and inputs. Two different files can give the same
recipe. In that case, `nix-diff` prints nothing and the store paths are equal.

**If it fails:**

- After the hash, read the end of the log with `nix log`.
- Errors about `bool`, `true`, `false` or old-style function declarations:
  the host compiler is nixpkgs gcc 16.2, which uses C23 by default. Add
  `env.NIX_CFLAGS_COMPILE = "-std=gnu17";`.

**Nix concepts:** [fixed-output derivations](appendix-nix-concepts.md#fixed-output-derivations),
[`stdenv.mkDerivation` and phases](appendix-nix-concepts.md#stdenvmkderivation-and-phases),
[`placeholder "out"`](appendix-nix-concepts.md#out-and-placeholder-out),
[references and closures](appendix-nix-concepts.md#references-and-closures),
[`callPackage`](appendix-nix-concepts.md#callpackage),
[evaluation and build](appendix-nix-concepts.md#evaluation-and-build).
