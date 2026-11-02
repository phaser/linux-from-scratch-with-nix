# Step 7 — static temporary tools

**Files to write:** `lfs-temp/lib.nix` (the helper), `lfs-temp/<tool>/default.nix`
for each tool, and `lfs-temp/default.nix`. Import it in `flake.nix` as `temp`.

These tools replace the host's `bash`, `coreutils` and so on in the stdenv's
`initialPath`. The list matches `initialPath` in nixpkgs
`pkgs/stdenv/linux/stage0.nix`.

**Do:**

1. Write one helper function for all tools. Its key parts:

   ```nix
   { stdenv, triple, binutils, gccStage2 }:
   { pname, ... }@args:
   stdenv.mkDerivation (args // {
     pname = "lfs-temp-${pname}";
     configurePlatforms = [ ];
     configureFlags = [ "--host=${triple}" "--build=${stdenv.buildPlatform.config}" ]
       ++ (args.configureFlags or [ ]);
     preConfigure = ''
       export PATH=${gccStage2}/tools/bin:${binutils}/tools/bin:$PATH
     '' + (args.preConfigure or "");
     LDFLAGS = "-static";
   })
   ```

   The default `--prefix=$out` stays. The tools use the Nix layout. Static
   linking means that there is no loader path to get wrong.

2. Build the tools one at a time, in this order. Take the configure flags from
   LFS chapter 6 for each tool.

   1. `gnumake` (small; it tests the helper)
   2. `coreutils`
   3. `bash` (add `--without-bash-malloc`)
   4. `gnused`, `gnugrep`, `gawk`, `findutils`, `diffutils`, `gnupatch`
   5. `gnutar`, `gzip`, `xz`
   6. `bzip2` (no configure script: `dontConfigure = true;` and
      `makeFlags = [ "CC=${triple}-gcc" "AR=${triple}-ar" "RANLIB=${triple}-ranlib" "PREFIX=$(out)" ];`)
   7. `patchelf` (C++; the fixup phase of every later stdenv needs it)

3. Add a `tools` attribute to `lfs-temp/default.nix`: a `buildEnv` of all of them. Here `buildEnv` is
   correct, because nothing reads these files through a sysroot.

**Verify each tool** (example for coreutils):

```console
$ nix build .#temp.coreutils -o result-temp-coreutils -L
$ file result-temp-coreutils/bin/ls                # ELF 64-bit LSB executable, ARM aarch64, statically linked
$ result-temp-coreutils/bin/ls --version | head -1 # ls (GNU coreutils) <version>
$ $B/$T-readelf -p .comment result-temp-coreutils/bin/ls    # GCC: (GCC) 14.2.0  (gcc stage 2)
$ nix path-info -r ./result-temp-coreutils         # ONE line: the tool itself
```

**Verify all tools together:**

```console
$ nix build .#temp.tools -o result-temp
$ env -i PATH=$(readlink -f result-temp)/bin bash -c 'type -P ls sed grep make tar xz patchelf'
                                                   # every path is inside result-temp
$ for f in result-temp/bin/*; do file -L $f; done | grep -vc 'statically linked'
                                                   # 0 (scripts such as egrep are fine; check them by hand)
```

**If it fails:**

- A configure test tries to run a program: that is a cross-compile check.
  LFS chapter 6 lists the cache variables for each tool (for example
  `gl_cv_...=yes`).
- Link warnings about `getpwnam` in static binaries are normal for glibc.

**Nix concepts:** [functions that make derivations](appendix-nix-concepts.md#nix-language),
[`//` and `@args`](appendix-nix-concepts.md#nix-language),
[references and closures](appendix-nix-concepts.md#references-and-closures).
