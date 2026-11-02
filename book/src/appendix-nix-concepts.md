# Appendix B — Nix concepts

Each entry says what the concept is, why it matters here, and where to read
more. Read an entry when a step lists it and you do not know it yet.

Main references:

- Nix reference manual: <https://nix.dev/manual/nix/latest/>
- nixpkgs manual: <https://nixos.org/manual/nixpkgs/stable/>
- Nix Pills (a tutorial series that builds a stdenv from nothing):
  <https://nixos.org/guides/nix-pills/>
- nix.dev tutorials: <https://nix.dev/>

## Nix language

Attribute sets `{ a = 1; }`, functions `{ a, b }: ...`, `let ... in`, `rec`,
`inherit`, string interpolation `"${x}"`, multi-line strings `'' ... ''`,
`import ./file.nix`, the update operator `a // b`, and `@args` (the whole
argument set). Every `.nix` file in this repo is one function.
Read: <https://nix.dev/tutorials/nix-language>.

## Flakes

`flake.nix` declares `inputs` (here nixpkgs) and `outputs` (here
`packages.aarch64-linux.*`). `nix shell nixpkgs#qemu` opens a shell with a
package from the nixpkgs flake, without installing it. `flake.lock` pins each input to one revision and
hash. `.#packages.aarch64-linux.binutils` is an *installable*: "this flake,
that output". Read: <https://nix.dev/concepts/flakes> and
`nix flake --help`.

## Evaluation and build

Nix works in two phases. **Evaluation** runs the Nix language and produces
`.drv` files: exact build recipes. **Build** (realisation) runs a `.drv` and
produces store paths. `nix eval .#x.drvPath` only evaluates. That is why the
repo evaluates on macOS but cannot build there. `nix derivation show` and
`nix-store -q --references <drv>` show what a `.drv` contains. Read: the Nix
manual, "Derivations"; Nix Pills 6 and 7.

## The store

Every build output is a directory under `/nix/store/<hash>-<name>`. The hash
comes from all inputs of the build. Store paths never change after the build.
That is why LFS's shared `$LFS` directory has no direct equivalent here
(steps 2, 4 and 5). Read: the Nix manual, "Nix Store".

## The sandbox

On Linux, each build runs in a chroot with namespaces. It sees only the store
paths it declares, plus `/dev`, `/proc`, a `/bin/sh` and a temporary build
directory. It has no network. This is the Nix equivalent of the LFS chroot.
`nix config show sandbox` shows whether it is on. Read: the Nix manual,
`nix.conf`, option `sandbox`.

## Fixed-output derivations

A derivation that declares its output hash in advance, such as `fetchurl`. It
is the only kind of build that gets network access, because Nix can check the
result. `lib.fakeHash` is a placeholder that always fails, so Nix prints the
real hash. Hashes use the SRI format `sha256-<base64>`; `nix hash convert`
converts from hex. Read: the nixpkgs manual, "Fetchers".

## `stdenv.mkDerivation` and phases

The standard builder. It runs phases in order: `unpackPhase`, `patchPhase`,
`configurePhase`, `buildPhase`, `checkPhase`, `installPhase`, `fixupPhase`.
You change a phase with attributes (`configureFlags`, `configureScript`,
`dontAddPrefix`, `configurePlatforms`, `makeFlags`, `installFlags`,
`patches`) or hooks (`preConfigure`, `postInstall`). Custom phases must call
`runHook preX` and `runHook postX`, as `headers.nix` does. Read: the nixpkgs
manual, "The Standard Environment"; Nix Pill 19.

## `$out` and `placeholder "out"`

`$out` is the output store path, set as a shell variable during the build.
In Nix code the path is not known yet; `placeholder "out"` gives a string that
Nix replaces with the real path. `binutils.nix` uses it in `--prefix`.
Read: the Nix manual, "Built-in functions", `placeholder`.

## `nativeBuildInputs`, `buildInputs` and `PATH`

`nativeBuildInputs` are tools that run during the build. `buildInputs` are
libraries for the result. For each input, stdenv adds `$pkg/bin` to `PATH`,
and runs the package's setup hook. Only `$pkg/bin`: not `$pkg/tools/bin`
(step 2). Read: the nixpkgs manual, "Specifying dependencies"; Nix Pill 20.

## Multiple outputs, `lib.getDev`, `lib.getLib`

One derivation can produce several store paths: `out`, `dev` (headers),
`lib` (libraries), `man`. `lib.getDev gmp` returns the `dev` output if it
exists. That is why `gcc-stage1.nix` passes different paths for `include` and
`lib`. Read: the nixpkgs manual, "Multiple-output packages".

## `callPackage`

`callPackage ./file.nix { extra = ...; }` calls the function in the file and
fills its arguments from nixpkgs by name. The path can point into nixpkgs
itself, as in step 18 (`"${nixpkgs}/nixos/lib/make-ext4-fs.nix"`). `.override` changes those arguments
later; `.overrideAttrs` changes the `mkDerivation` attributes. Read: Nix
Pill 13; nix.dev, "callPackage".

## Platforms: build, host, target

`buildPlatform` runs the build, `hostPlatform` runs the result, and
`targetPlatform` is what a compiler produces code for. In this repo all three
are aarch64, but your triple `aarch64-lfs-linux-gnu` is a different *name*,
so autoconf treats steps 1 to 8 as cross builds. `configurePlatforms = [ ]`
stops stdenv from adding `--build` and `--host` itself. Read: the nixpkgs
manual, "Cross-compilation".

## Hardening flags

nixpkgs' cc-wrapper adds flags such as `-fstack-protector-strong` and
`-Werror=format-security` to every compile. `hardeningDisable` turns one off.
The flags come from the wrapper, so an unwrapped compiler (your gcc in steps 2
to 8) never sees them. Read: the nixpkgs manual, "Hardening in Nixpkgs".

## The fixup phase: strip, patchelf, patchShebangs

After install, stdenv strips debug symbols, shrinks `RPATH` with `patchelf`,
and rewrites `#!` lines to store paths. This is helpful for normal packages,
but wrong for a libc in a sysroot and for target files. Turn it off with
`dontStrip`, `dontPatchELF` and `dontPatchShebangs` (steps 4 and 8). Read:
the nixpkgs manual, "The fixup phase".

## Trivial builders: `runCommand`, `buildEnv`, `symlinkJoin`

Small builders for small jobs. `runCommand name env script` runs a shell
script. `buildEnv` and `symlinkJoin` make a tree of symlinks. Symlinks break
the sysroot check of `ld` (step 5). Read: the nixpkgs manual, "Trivial build
helpers".

## References and closures

Nix finds runtime dependencies by scanning the output for the hashes of other
store paths. The set of all of them is the **closure**. The scan reads raw
bytes, so it cannot see a hash inside a compressed file (step 17).

- `nix path-info -r <path>` lists the closure.
- `nix why-depends <a> <b>` shows why `a` refers to `b`.
- `nix-store -q --references <drv>` lists the direct inputs of a recipe (the
  build-time view).
- `allowedRequisites` and `disallowedRequisites` make a build fail when its
  closure has, or misses, a path.

This is the main tool for proving that no host binary is left (steps 7, 10
and 12). Read: the Nix manual, `nix path-info` and `nix why-depends`.

## Debugging a build

`-L` streams logs. `nix log` shows the last log. `--keep-failed` keeps the
build directory. `nix develop` opens a shell with the build environment, where
you run phases by hand. Read: nix.dev, "Troubleshooting"; `nix develop --help`.

## Stdenv internals: setup.sh, initialPath, cc-wrapper

A stdenv is a derivation with `setup` (from `pkgs/stdenv/generic/setup.sh`),
a `shell`, an `initialPath` (the tools on `PATH` in every build) and a `cc`.
The `cc` is a **wrapper**: a script around the real gcc that adds `-B`,
`-idirafter`, `-dynamic-linker` and `RPATH` flags for the libc in the store,
so no sysroot is needed. `bintools-wrapper` does the same for `ld`. nixpkgs
builds its own stdenv in stages (`pkgs/stdenv/linux/default.nix`): each stage
uses only the stage before. Read: Nix Pills 12 and 19; the nixpkgs manual,
"The Standard Environment"; the source of `pkgs/build-support/cc-wrapper/`.

## Fixed points and overlays

nixpkgs is one big function of itself (`self: super: { ... }`). Overlays change
packages in it, and every user of a package sees the change. You need this
if you later want all of nixpkgs on your stdenv (`import nixpkgs { stdenvStages = ...; }`).
Read: the nixpkgs manual, "Overlays"; Nix Pill 17.

## `buildEnv` priorities

When two packages in a `buildEnv` have the same file, the build fails, unless
one has a higher priority. `lib.lowPrio pkg` and `lib.hiPrio pkg` set
`meta.priority`; the lower number wins. Step 16 uses this so that GNU
`ls` wins over the busybox `ls`. Read: the nixpkgs manual, "buildEnv" and
`lib.meta`.

## `closureInfo`

`pkgs.closureInfo { rootPaths = [ ... ]; }` writes the full closure of some
store paths to a file (`store-paths`), plus a `registration` file for
`nix-store --load-db`. Every image builder uses it: `makeInitrd`,
`make-ext4-fs.nix` and the NixOS ISO builder. This is how a set of store
paths becomes the `/nix/store` of another system. Read: the source,
`pkgs/build-support/closure-info.nix`; then
`nixos/modules/system/boot/stage-1.nix` to see how NixOS builds its own
initramfs.

## Reproducibility

Nix pins *inputs*. It does not prove that two builds give the same bytes.
`nix build --rebuild` builds again and compares. `diffoscope` shows the
difference. Read: <https://reproducible-builds.org/>.
