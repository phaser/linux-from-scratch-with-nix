# Appendix B — Nix concepts

Each entry says what the concept is, why it matters here, and where to read
more. The introduction ("Nix basics") gives the minimum. Each step starts
with a short version of the entries that it uses for the first time. Read
the full entry here when the short version is not enough.

Main references:

- Nix reference manual: <https://nix.dev/manual/nix/latest/>
- nixpkgs manual: <https://nixos.org/manual/nixpkgs/stable/>
- Nix Pills (a tutorial series that builds a stdenv from nothing):
  <https://nixos.org/guides/nix-pills/>
- nix.dev tutorials: <https://nix.dev/>

## Nix language

Every `.nix` file in this repo is one function. The parts of the language
that the book uses:

| Syntax | Meaning | First used |
|---|---|---|
| `{ a = 1; b = "x"; }` | An attribute set | step 1 |
| `x: x + 1`, `{ a, b }: a + b` | A function. The second takes a set. See "Function arguments". | step 1 |
| `f { a = 1; }` | A call. There are no parentheses around arguments. | step 1 |
| `inherit a b;` | The same as `a = a; b = b;` | step 1 |
| `inherit (x) a b;` | The same as `a = x.a; b = x.b;` | step 7 |
| `"--prefix=${p}"` | Interpolation. A package in `${ }` gives its store path, and the package becomes an input. | step 1 |
| `'' … ''` | A multi-line string. Nix removes the common indentation. | step 3 |
| `let a = 1; in a + 1` | Local names | step 7 |
| `rec { a = 1; b = a + 1; }` | A set whose attributes can use each other | step 7 |
| `a // b` | Merge two sets. The value from `b` wins. | step 7 |
| `x.a or d` | `x.a`, or `d` if `x` has no `a` | step 7 |
| `import ./file.nix` | The value of the file (here, always a function) | step 7 |
| `with temp; [ a b ]` | `[ temp.a temp.b ]` | step 9 |
| `builtins.attrValues s` | The list of the values of `s` | step 11 |

Read: <https://nix.dev/tutorials/nix-language>.

## Function arguments

```nix
{ stdenv, fetchurl, name ? "lfs-stdenv", ... }@args: …
```

- `{ stdenv, fetchurl }:` the function takes a set with these names. A call
  with another name fails with `called with unexpected argument`. A call
  without a name fails with `called without required argument`.
- `name ? "lfs-stdenv"` gives a default. The caller can omit `name`.
- `...` accepts other names too.
- `@args` gives the whole set to the body, also the names of `...`. Step 7
  passes `args` to `mkDerivation`.
- A `let` name hides an argument with the same name. In
  `{ libc ? temp.glibc }: let libc = temp.glibc; in …`, the argument has no
  effect (step 11, part 2a).

Read: <https://nix.dev/tutorials/nix-language>, "Functions".

## Flakes

`flake.nix` declares `inputs` (here nixpkgs) and `outputs` (here
`legacyPackages.aarch64-linux.*`). `nix shell nixpkgs#qemu` opens a shell with a
package from the nixpkgs flake, without installing it. `flake.lock` pins each input to one revision and
hash. `.#binutils` is an *installable*: "this flake,
that output". Nix looks for `packages.<system>.binutils`, then
`legacyPackages.<system>.binutils`. Unlike `packages`, `legacyPackages` can
nest, as in `.#temp.gnumake`.

A flake in a git repo sees only the files that git tracks. A new file needs
`git add`. A commit is not necessary. If git does not track the file, Nix
says that the file or the attribute does not exist.
`warning: Git tree '/work' has uncommitted changes` is normal.

`builtins.getFlake "git+file:///work"` loads a flake inside Nix code. Step 8
uses it to find the nixpkgs source. Step 11 uses it to show an error that
`nix build` hides. Read: <https://nix.dev/concepts/flakes> and
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
real hash. `nix store prefetch-file <url>` gives the hash without a build.
Hashes use the SRI format `sha256-<base64>`; `nix hash convert`
converts from hex. The store path of a fixed-output derivation comes from
the hash and the name only, not from the URL. Two `fetchurl` calls with the
same file name and hash give one store path, and Nix downloads the file once
(step 14). A patch from a URL (`patches = [ (fetchurl { … }) ]`) is a
fixed-output derivation too (step 11). Read: the nixpkgs manual, "Fetchers".

## `stdenv.mkDerivation` and phases

The standard builder. It runs phases in order: `unpackPhase`, `patchPhase`,
`configurePhase`, `buildPhase`, `checkPhase`, `installPhase`, `fixupPhase`.
You change a phase with attributes (`configureFlags`, `configureScript`,
`dontAddPrefix`, `configurePlatforms`, `makeFlags`, `installFlags`,
`patches`) or hooks (`preConfigure`, `postInstall`). Custom phases must call
`runHook preX` and `runHook postX`, as `headers.nix` does.

More attributes that the book uses:

- `dontConfigure = true;` skips the configure phase, and also `preConfigure`
  (steps 3 and 7).
- `doCheck = true;` runs `make check` (step 10).
- `makeFlags` is a list of `make` arguments. Nix joins the list with spaces
  and splits it again at each space. For a value with spaces, add it in a hook:
  `makeFlagsArray+=("CFLAGS=-O2 -g")` (step 11).
- `meta.platforms = lib.platforms.linux;` stops a build on other systems
  (step 1).
- `stdenvNoCC` is a stdenv without a C compiler (step 4).
- `$NIX_BUILD_CORES` is the number of cores for `make -j` (step 14).

Read: the nixpkgs manual, "The Standard Environment"; Nix Pill 19.

## Patches

`patches` is a list of diff files. `patchPhase` applies them in order, after
`unpackPhase`, with `patch -p1` (change it with `patchFlags`). A list item is
usually a path such as `./fix.patch`. Nix copies the file into the store, so in
a flake git must track it. A patch can also come from nixpkgs
(`"${path}/pkgs/..."`) or from `fetchpatch`. For a small change that is not a
diff, use `substituteInPlace` in `postPatch`. Step 8 uses the first patch.
Read: the nixpkgs manual, "The Standard Environment", `patchPhase`.

## `$out` and `placeholder "out"`

`$out` is the output store path, set as a shell variable during the build.
In Nix code the path is not known yet; `placeholder "out"` gives a string that
Nix replaces with the real path. `binutils.nix` uses it in `--prefix`.
Read: the Nix manual, "Built-in functions", `placeholder`.

## Attributes and environment variables

`mkDerivation` gives each attribute to the build as an environment variable.
`KBUILD_BUILD_USER = "lfs";` (step 14) and `BASH_SHELL = "/bin/sh";`
(step 11) work this way. A list becomes one string, with a space between the
items.

A wrong name is no error. `installPhaser = …;` is a valid attribute: it
becomes the variable `installPhaser`, and stdenv runs its default install
phase. When a setting seems to have no effect, check the spelling of its name
first (step 14).

`env.X = "…";` sets the variable `X` explicitly. Use it for names that are
not attributes of `mkDerivation`, such as `env.NIX_CFLAGS_COMPILE` (step 1).

The nixpkgs wrappers read some `NIX_*` variables at each call:

| Variable | Effect |
|---|---|
| `NIX_CFLAGS_COMPILE` | The cc-wrapper adds these flags to each compile. |
| `NIX_DONT_SET_RPATH` | The ld-wrapper adds no `-rpath` (step 11). |
| `NIX_NO_SELF_RPATH` | The ld-wrapper does not add `$out/lib` to the rpath (step 11). |

Read: the nixpkgs manual, "The Standard Environment"; the source of
`pkgs/build-support/cc-wrapper/` and `bintools-wrapper/`.

## Setup hooks

A package can have a `setupHook`: a shell file. stdenv runs it at the start
of each build that has the package in `nativeBuildInputs`, or in the
`extraNativeBuildInputs` of the stdenv.

- The patchelf hook runs `patchelf --shrink-rpath` on each ELF file in the
  fixup phase (steps 7 and 9).
- The cc-wrapper hook sets `CC` and other variables. It also puts the
  `coreutils` of the wrapper on `PATH`. That is the leak of step 9.

A package in `initialPath` is only on `PATH`. Its hook does not run (step 9).
Read: the nixpkgs manual, "Package setup hooks".

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
the sysroot check of `ld` (step 5). `linkFarm name [ { name = "a"; path = x; } ]`
makes a directory with one named symlink for each item (step 6).
`writeScript name text` writes one executable file (step 16). Read: the
nixpkgs manual, "Trivial build helpers".

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
you run phases by hand.

Sometimes `nix build .#a.b` says
`does not provide attribute 'packages.aarch64-linux.a.b'`, but `a.b` exists.
Nix then hides an evaluation error. Evaluate the attribute directly to see
the error:

```console
$ nix eval --impure --raw --expr '(builtins.getFlake "git+file:///work").legacyPackages.aarch64-linux.a.b.drvPath'
```

Read: nix.dev, "Troubleshooting"; `nix develop --help`.

## Stdenv internals: setup.sh, initialPath, cc-wrapper

A stdenv is a derivation with `setup` (from `pkgs/stdenv/generic/setup.sh`),
a `shell`, an `initialPath` (the tools on `PATH` in every build) and a `cc`.
The `cc` is a **wrapper**: a script around the real gcc that adds `-B`,
`-idirafter`, `-dynamic-linker` and `RPATH` flags for the libc in the store,
so no sysroot is needed. `bintools-wrapper` does the same for `ld`. nixpkgs
builds its own stdenv in stages (`pkgs/stdenv/linux/default.nix`): each stage
uses only the stage before.

`pkgs.wrapCCWith` and `pkgs.wrapBintoolsWith` make the wrappers. They call
`callPackage` on the wrapper file, so the programs of the wrapper scripts
(`coreutils`, `gnugrep`, `runtimeShell`, `expand-response-params`) come from
nixpkgs. Both functions add your arguments last (`// extraArgs`). An argument
that you give replaces the nixpkgs value (step 11, stage 4).

`genericStdenv` (`pkgs/stdenv/generic`) also takes `extraNativeBuildInputs`
(packages with a setup hook for each build), `fetchurlBoot` (the `fetchurl`
of the stdenv itself) and `preHook` (shell code at the start of each build).
Read: Nix Pills 12 and 19; the nixpkgs manual,
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

Nix pins *inputs*. The store path comes from the inputs, not from the
output, so two builds of one derivation have the same path also when their
bytes differ. Nix does not prove that two builds give the same bytes.
`nix build --rebuild` builds again and compares. `diffoscope` shows the
difference.

The usual causes of a difference are the time, the user and the host of the
build. stdenv sets `SOURCE_DATE_EPOCH`, and many tools use it instead of the
clock. Some tools have their own variables: the kernel reads
`KBUILD_BUILD_TIMESTAMP`, `KBUILD_BUILD_USER` and `KBUILD_BUILD_HOST`
(step 14). Read: <https://reproducible-builds.org/>.
