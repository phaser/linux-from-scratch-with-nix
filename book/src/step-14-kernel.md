# Step 14 — the kernel

**File to write:** `lfs-distro/kernel/default.nix`, attribute `kernel`, pname `lfs-final-linux`

**Nix concepts for this step**

New in this step:

- **The attributes of a derivation.** A derivation is a set, and you can read
  its attributes. `inherit (toolchain.headers) src version;` takes the source
  and the version of step 3, so this step has no `fetchurl`. See "The source:
  no new download". [More](appendix-nix-concepts.md#nix-language).
- **The path of a fixed-output derivation.** It comes from the hash and the
  name only, not from the URL. The same file is never downloaded twice.
  [More](appendix-nix-concepts.md#fixed-output-derivations).
- **Attributes are environment variables.** `KBUILD_BUILD_USER = "lfs";`
  sets the variable `KBUILD_BUILD_USER` in the build.
  [More](appendix-nix-concepts.md#attributes-and-environment-variables).
- **Same path, different bytes.** The store path comes from the inputs of
  the build, not from its output. A value that changes at each build, such as
  the time, gives different bytes at the same path. See "Why the kernel needs
  fixed build values". [More](appendix-nix-concepts.md#reproducibility).
- **`patchShebangs` and `$NIX_BUILD_CORES`.** `patchShebangs scripts` rewrites
  the `#!` lines of a directory now, not in the fixup phase.
  `$NIX_BUILD_CORES` is the number of cores for `make -j`.
  [More](appendix-nix-concepts.md#the-fixup-phase-strip-patchelf-patchshebangs).

From earlier steps: [`callPackage` with your stdenv](appendix-nix-concepts.md#callpackage) (step 10), [hardening flags](appendix-nix-concepts.md#hardening-flags) (step 2), [your own phases](appendix-nix-concepts.md#stdenvmkderivation-and-phases) (step 3), [`nativeBuildInputs`](appendix-nix-concepts.md#nativebuildinputs-buildinputs-and-path) (step 1), [`with`](appendix-nix-concepts.md#nix-language) (step 9), [reproducibility](appendix-nix-concepts.md#reproducibility) (step 12).

---

This is the first package of the distro. It is also the first part of the
image, so `lfsStdenvFinal` builds it. nixpkgs gives only the tools that run
during the build.

## Do

1. Write `lfs-distro/kernel/default.nix`:

   ```nix
   { stdenv, src, version, bc, bison, flex, perl, openssl }:

   stdenv.mkDerivation {
     pname = "lfs-final-linux";
     inherit src version;

     nativeBuildInputs = [ bc bison flex perl openssl ];

     hardeningDisable = [ "all" ];

     postPatch = "patchShebangs scripts";

     KBUILD_BUILD_USER = "lfs";
     KBUILD_BUILD_HOST = "lfs";
     KBUILD_BUILD_TIMESTAMP = "1970-01-01";

     configurePhase = ''
       runHook preConfigure
       make ARCH=arm64 defconfig
       runHook postConfigure
     '';

     buildPhase = ''
       runHook preBuild
       make ARCH=arm64 -j$NIX_BUILD_CORES Image
       runHook postBuild
     '';

     installPhase = ''
       runHook preInstall
       mkdir -p $out
       cp arch/arm64/boot/Image $out/Image
       cp .config $out/config
       runHook postInstall
     '';
   }
   ```

   | Line | Why |
   |---|---|
   | `{ stdenv, src, version, … }` | The caller gives `lfsStdenvFinal` as `stdenv`, and the source and version of step 3. The other names come from nixpkgs. |
   | `pname = "lfs-final-linux"` | The `lfs-final-` prefix: your stdenv built it. Step 20 uses the prefix. |
   | `inherit src version;` | The same Linux 6.12 tarball as the headers of step 3. See "The source: no new download" below. |
   | `nativeBuildInputs` | `bc`, `bison`, `flex` and `perl` run during the build. Some host programs of the kernel link `libcrypto` from `openssl`. None of them goes into the image. |
   | `hardeningDisable = [ "all" ]` | The cc-wrapper adds `-fstack-protector-strong`, `-D_FORTIFY_SOURCE` and PIE flags to each compile. The kernel sets its own flags, and these break it. nixpkgs also disables them for its kernel. |
   | `postPatch = "patchShebangs scripts"` | The kernel scripts start with `#!/usr/bin/env perl`. The sandbox has no `/usr/bin/env`. `patchShebangs` puts the store path of `perl` in each `#!` line. |
   | `KBUILD_BUILD_*` | The kernel stores the user, the host and the time of the build. Fixed values make the build reproducible. See "Why the kernel needs fixed build values" below. |
   | `ARCH=arm64` | Without `ARCH`, the kernel uses `uname -m` of the build machine. |
   | `make defconfig` | The default configuration for arm64. It has the console, `devtmpfs`, initramfs, virtio and ext4 that QEMU needs. Make it smaller later. |
   | `make … Image` | Only the kernel image. No modules: the options that QEMU needs are built in (`=y`). |
   | `installPhase` | `Image` boots in QEMU (steps 17 and 18). `config` is for the checks below. |

   There is no `configureFlags`: the kernel has no `./configure`. The three
   phases replace the default phases, so each one calls its `runHook` lines
   (step 3).

   ### The source: no new download

   Until now, each package had its own `fetchurl` with a `url` and a `hash`.
   This file has no `fetchurl`. It takes `src` from step 3:

   ```nix
   inherit (toolchain.headers) src version;     # in lfs-distro/default.nix
   ```

   `toolchain.headers` is the derivation of step 3. A derivation is a set, so
   `toolchain.headers.src` is its `src` attribute: the `fetchurl` of
   `lfs-toolchain/linux-headers/default.nix`.

   ```nix
   src = fetchurl {
     url = "http://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${version}.tar.xz";
     hash = "sha256-saJWK+VuQq+z+EidTCp6xHKsIwmPHvHB5A2mAfVGJes=";
   };
   ```

   This is one of the main features of Nix. Each package is a value, and you
   can use any part of another package by name: its source, its version, its
   output. Nix does not copy or download anything again. The reference is also
   exact: the kernel gets the same tarball, with the same hash, as step 3, and
   not "Linux 6.12 from somewhere". In LFS, you download each tarball to
   `$LFS/sources` once, and you must use the same file in each chapter by
   hand. Here, Nix does it.

   Two reasons to reuse it:

   - **One version.** The headers in glibc (step 3) and the kernel in the
     image come from the same tarball. If you change the version in step 3,
     both change.
   - **No second download.** The tarball is already in the store, from step 3.

   **How Nix knows the hash.** You gave it in step 3. `fetchurl` is a
   fixed-output derivation: Nix downloads the file, computes its sha256, and
   compares it with `hash`. If the two are different, the build fails. The
   store path of a fixed-output derivation comes from the hash and the name
   only, not from the URL. So a second `fetchurl` with the same file name and
   the same hash gives the same store path, and Nix downloads nothing. A
   `fetchurl` here would also work, but the version would then be in two
   places.

   **How to get a hash for another version** (steps 1 and 3):

   ```console
   $ nix store prefetch-file https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.tar.xz
                                         # hash: sha256-…
   ```

   Or set `hash = lib.fakeHash;`, build, and copy the hash after `got:`. Or
   convert the hex hash that kernel.org signs (step 3, "Optional").

   **The hash of the result is a different hash.** You do not give it. The
   store path of `lfs-final-linux` comes from all its inputs: the source hash,
   the flags, the compiler and the stdenv. After the build, Nix records a hash
   of the output:

   ```console
   $ nix path-info --json ./result-kernel | grep -o '"narHash":"[^"]*"'
   ```

   The next section shows why this second hash must be the same at each
   build.

   ### Why the kernel needs fixed build values

   **What the kernel stores.** The kernel writes three values of the build
   into the image. You see them in `/proc/version` of the running system
   (step 17):

   ```
   Linux version 6.12.0 (lfs@lfs) (gcc (GCC) 14.2.0, …) #1 SMP PREEMPT 1970-01-01
                         \_/ \_/                                         \________/
                        user host                                        timestamp
   ```

   Without the three variables, the kernel takes them from the build:

   | Value | Without the variable | Is it the same at each build? |
   |---|---|---|
   | User | `whoami` in the sandbox, for example `nixbld` | Usually. It depends on the Nix configuration (build users or not). |
   | Host | `hostname` in the sandbox: `localhost` | Usually. Nix sets it in the sandbox. |
   | Timestamp | `date`: the time of the build | **No.** Each build gives a new value. |

   **Why this matters in Nix.** Nix computes the store path from the
   *inputs* of the build: the source, the flags, the compiler and the other
   derivations. Nix does not look at the *output* when it chooses the path. So
   two builds of the same derivation always get the same store path, also when
   their bytes are different:

   - Your build and a build on another machine have the same path
     `/nix/store/…-lfs-final-linux-6.12`. With a timestamp in it, the two
     `Image` files are different. A binary cache can give you either one.
   - Nix cannot see the difference by itself. `nix build --rebuild` builds
     again and compares the bytes (step 12). With `date` in the image, that
     check always fails.
   - Each change in the image changes the closure of each system that uses it
     (steps 17 and 18). A build that you cannot repeat is a build that you
     cannot check.

   **What stdenv does already.** stdenv sets `SOURCE_DATE_EPOCH` to the newest
   time of a file in the source (you see `setting SOURCE_DATE_EPOCH to
   timestamp …` in each build log). Many build tools read this variable
   instead of the clock. The kernel does not use it for its build timestamp.
   It reads `KBUILD_BUILD_TIMESTAMP`, and without it, it calls `date`. So set
   the three `KBUILD_BUILD_*` variables. The kernel documents them in
   `Documentation/kbuild/reproducible-builds.rst`.

   **How the values get to the build.** `mkDerivation` gives each attribute
   to the builder as an environment variable. `KBUILD_BUILD_USER = "lfs";` in
   the Nix file is `export KBUILD_BUILD_USER=lfs` in the build. `make` reads
   it from the environment. For a name that is not an attribute of
   `mkDerivation`, use `env.<NAME>` (step 1).

   **To check it.** Build the kernel a second time and compare. This takes
   as long as the first build:

   ```console
   $ nix build .#kernel --rebuild                    # no "differs" message
   ```

2. Write `lfs-distro/default.nix`. Steps 15 to 18 add their attributes to the
   same set:

   ```nix
   # Part 4: the distro.
   { pkgs, nixpkgs, toolchain, final, lfsStdenvFinal }:

   rec {
     # Step 14
     kernel = pkgs.callPackage ./kernel {
       stdenv = lfsStdenvFinal;
       inherit (toolchain.headers) src version;
     };
   }
   ```

   `final` and `nixpkgs` are for steps 16 and 18. Give them now, so that you
   do not change `flake.nix` again.

3. Add two lines to the `rec` set of `flake.nix`, after `helloFinal`:

   ```nix
   distro = import ./lfs-distro { inherit pkgs nixpkgs toolchain final lfsStdenvFinal; };
   inherit (distro) kernel;
   ```

   `inherit (distro) kernel;` puts `kernel` at the top, so `.#kernel` works.
   Steps 15 to 18 add their names to this line.

4. Make git track the new files:

   ```console
   $ git add lfs-distro
   ```

## Verify

```console
$ nix build .#kernel -o result-kernel -L    # about 10 to 30 minutes (not measured yet)
$ file result-kernel/Image                         # Linux kernel ARM64 boot executable Image, little-endian, 4K pages
$ grep -E '^CONFIG_(SERIAL_AMBA_PL011_CONSOLE|DEVTMPFS|BLK_DEV_INITRD|VIRTIO_BLK|EXT4_FS|BINFMT_SCRIPT)=' result-kernel/config
                                                   # all 6 lines end with =y
$ grep CONFIG_CC_VERSION_TEXT result-kernel/config # CONFIG_CC_VERSION_TEXT="gcc (GCC) 14.2.0"
$ grep -a -o 'Linux version [^)]*)' result-kernel/Image | head -1
                                                   # Linux version 6.12.0 (lfs@lfs)
```

`CONFIG_CC_VERSION_TEXT` shows which compiler built the kernel. It must be
14.2.0. A `16.2.0` means that the nixpkgs gcc built it.

**If it fails:**

- Errors about `-fstack-protector`, `_FORTIFY_SOURCE` or `relocation` in
  early kernel files: `hardeningDisable` is missing.
- `Can't find default configuration "arch/x86/configs/defconfig"`, or a
  similar wrong architecture: `ARCH=arm64` is missing.
- `CONFIG_CC_VERSION_TEXT` shows `16.2.0`: the attribute does not give
  `stdenv = lfsStdenvFinal`, so `callPackage` gives the nixpkgs stdenv.
- `openssl/...h: No such file`: add `openssl.dev` to `nativeBuildInputs`, or
  disable the option that needs it with `scripts/config --disable <OPTION>`.
- A script fails with `bad interpreter`: run `patchShebangs` on that directory too.
- `mkdir: cannot create directory '/boot': Permission denied`, after
  `install flags: … install`: stdenv ran its default install phase,
  `make install`, so it did not find your `installPhase`. Check the spelling.
  A wrong name, such as `installPhaser`, gives no error. See the next item.
- `/proc/version` or `Image` shows the real date of the build: a
  `KBUILD_BUILD_*` name is wrong (for example `KBUILD_BUILD_TIME`). The kernel
  ignores names that it does not know, and it uses `date`.

**A wrong attribute name gives no error.** `mkDerivation` gives each
attribute to the build as an environment variable, so each name is valid.
Nix cannot know that `installPhaser` was meant to be `installPhase`. The
error comes later, as a different behaviour. When a phase or a setting seems
to have no effect, check the spelling of its name first.

## Bonus: where `.config` comes from

Your file has no list of kernel options, but the kernel has about 10,000 of
them. Look at what one line does:

```nix
make ARCH=arm64 defconfig
```

1. `defconfig` reads `arch/arm64/configs/defconfig` from the Linux tarball.
   That file is short, about 1,000 lines. It lists only the options that
   differ from the default. The kernel developers keep it, and it boots on
   most arm64 machines, QEMU `virt` too.
2. Kconfig, the configuration system of the kernel, adds the default value of
   each other option. It also checks the dependencies between the options.
3. The result is `.config` in the build directory, the full list. `make Image`
   reads it. Your `installPhase` copies it to `$out/config`, so that you can
   read it after the build.

See the input file without a build:

```console
$ tar -xOf $(nix build --no-link --print-out-paths .#headers.src) \
    linux-6.12/arch/arm64/configs/defconfig | wc -l          # about 1000
$ wc -l result-kernel/config                                 # about 10000
```

The source is the same store path as in step 3, so the first command
downloads nothing.

### Add or change an option

Change `.config` after `make defconfig`, in the configure phase. Then let
Kconfig check the dependencies again with `olddefconfig`.

**A few options: `scripts/config`.**

```nix
configurePhase = ''
  runHook preConfigure
  make ARCH=arm64 defconfig
  scripts/config --enable CONFIG_IKCONFIG_PROC     # /proc/config.gz in the guest
  scripts/config --disable CONFIG_SOUND
  make ARCH=arm64 olddefconfig
  runHook postConfigure
'';
```

| Command | Effect |
|---|---|
| `scripts/config --enable X` | `CONFIG_X=y`: built into `Image` |
| `scripts/config --module X` | `CONFIG_X=m`: a module. This step builds no modules, so do not use it. |
| `scripts/config --disable X` | `# CONFIG_X is not set` |
| `scripts/config --set-val X 64` | `CONFIG_X=64`, for a number or a string |

**Many options: a fragment file in the repo.** Write the options in
`lfs-distro/kernel/extra.config`:

```
CONFIG_IKCONFIG=y
CONFIG_IKCONFIG_PROC=y
# CONFIG_SOUND is not set
```

Then merge it in the configure phase:

```nix
configurePhase = ''
  runHook preConfigure
  make ARCH=arm64 defconfig
  scripts/kconfig/merge_config.sh -m .config ${./extra.config}
  make ARCH=arm64 olddefconfig
  runHook postConfigure
'';
```

`${./extra.config}` is a path in the repo. Nix copies the file into the store
and gives its store path to the build, as for a patch (step 8). Run
`git add lfs-distro/kernel/extra.config`.

**Check that the option is there.** Kconfig removes an option when one of its
dependencies is off, and it gives no error. Check the result:

```console
$ grep -E '^CONFIG_IKCONFIG(_PROC)?=' result-kernel/config    # both =y
```

To stop the build when an option is missing, add a check after
`olddefconfig`:

```sh
grep -q '^CONFIG_IKCONFIG_PROC=y' .config || { echo "CONFIG_IKCONFIG_PROC is missing"; exit 1; }
```

**What Nix does with the change.** The configure phase is part of the
derivation. A new option, or a change in `extra.config`, gives a new store
path, so Nix builds the kernel again. The old kernel stays in the store, so a
change back gives the old path, and Nix builds nothing.
