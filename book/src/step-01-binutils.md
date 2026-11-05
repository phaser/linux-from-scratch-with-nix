# Step 1 — binutils

**File to write:** `lfs-toolchain/binutils/default.nix`, attribute `binutils`

**Read first:** the LFS book, chapter 5, "Binutils - Pass 1"
(<https://www.linuxfromscratch.org/lfs/view/12.2/>). This book uses the
versions of LFS 12.2.

The host compiler builds binutils on purpose. This is LFS pass 1. The result
runs on the host and produces code for the `aarch64-lfs-linux-gnu` triple.

**Nix concepts for this step**

New in this step:

- **A package file is a function.** Your file starts with
  `{ lib, stdenv, fetchurl, triple }:`. `callPackage ./binutils { inherit triple; }`
  calls it. It gives `lib`, `stdenv` and `fetchurl` from nixpkgs, and you give
  `triple`. `inherit triple;` is short for `triple = triple;`.
  [More](appendix-nix-concepts.md#callpackage).
- **`stdenv.mkDerivation` and phases.** It runs unpack, patch, configure,
  build, install and fixup. Attributes change a phase:
  `configureFlags = [ "--disable-nls" ];` adds flags to `./configure`. A hook is
  a shell fragment that runs before or after a phase:
  `postInstall = "rm -r $out/share/info";`. Hint 3 names the hook and the
  attribute that you need.
  [More](appendix-nix-concepts.md#stdenvmkderivation-and-phases).
- **Fixed-output derivations.** `fetchurl { url = …; hash = …; }` is the only
  kind of build with network, because Nix checks the result against the hash.
  To get the hash, use `hash = lib.fakeHash;` and read the error, or run
  `nix store prefetch-file <url>`. [More](appendix-nix-concepts.md#fixed-output-derivations).
- **`$out` and `placeholder "out"`.** `$out` is the store path of the result,
  in the shell of the build. In Nix code the path is not known yet:
  `placeholder "out"` stands for it, for example in
  `"--with-foo=${placeholder "out"}/foo"`. [More](appendix-nix-concepts.md#out-and-placeholder-out).
- **`nativeBuildInputs`.** The tools that run during the build, for example
  `nativeBuildInputs = [ texinfo ];`. The sandbox has only these tools and the
  tools of the stdenv. [More](appendix-nix-concepts.md#nativebuildinputs-buildinputs-and-path).
- **Environment variables.** `env.NIX_CFLAGS_COMPILE = "-std=gnu17";` sets a
  variable for the build. The nixpkgs cc-wrapper adds its value to each
  compile. [More](appendix-nix-concepts.md#attributes-and-environment-variables).
- **`meta.platforms`.** `meta.platforms = lib.platforms.linux;` stops a build on
  another system. [More](appendix-nix-concepts.md#stdenvmkderivation-and-phases).
- **References and closures.** `nix path-info -r` lists each store path that
  the result refers to. `nix why-depends` shows why.
  [More](appendix-nix-concepts.md#references-and-closures).
- **`nix log`.** `nix log ./result-binutils` shows the log of the build.
  [More](appendix-nix-concepts.md#debugging-a-build).

From earlier steps: [the store](appendix-nix-concepts.md#the-store) (step 0), [flakes](appendix-nix-concepts.md#flakes) (step 0), [evaluation and build](appendix-nix-concepts.md#evaluation-and-build) (step 0).

---

**Do:** write a derivation that meets these requirements.

1. The file is a function of `{ lib, stdenv, fetchurl, triple }`. Add the
   attribute to the set in `lfs-toolchain/default.nix`:
   `binutils = callPackage ./binutils { inherit triple; };`. Then run
   `git add lfs-toolchain/binutils`.
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

**If it fails:**

- After the hash, read the end of the log with `nix log`.
- `makeinfo: not found`, then `Error 127` at `doc/bfd.info`: the build
  regenerates the inputs of the bfd manual, so `make` rebuilds it. Add
  `texinfo` to `nativeBuildInputs`. LFS lists Texinfo as a host requirement,
  so the LFS book never shows this failure.
- `bad value ... for enable-default-hash-style option`: the `ld` configure
  accepts only `sysv`, `gnu` or `both`. It runs late, after `bfd` builds.
- Errors about `bool`, `true`, `false` or old-style function declarations:
  the host compiler is nixpkgs gcc 16.2, which uses C23 by default. Add
  `env.NIX_CFLAGS_COMPILE = "-std=gnu17";`.
