# Step 14 — the kernel

**File to write:** `lfs-distro/kernel/default.nix`, attribute `kernel`, pname `lfs-final-linux`

**Nix concepts for this step**

New in this step:

- **`mkDerivation` of a given stdenv.** `lfsStdenvFinal.mkDerivation { … }`
  uses your stdenv directly, without `callPackage`.
  [More](appendix-nix-concepts.md#stdenvmkderivation-and-phases).
- **The attributes of a derivation.** A derivation is a set. `headers.src`
  is the source of step 3. [More](appendix-nix-concepts.md#nix-language).
- **Attributes are environment variables.** `KBUILD_BUILD_USER = "lfs";`
  sets the variable `KBUILD_BUILD_USER` in the build.
  [More](appendix-nix-concepts.md#attributes-and-environment-variables).
- **`patchShebangs` and `$NIX_BUILD_CORES`.** `patchShebangs scripts` rewrites
  the `#!` lines of a directory now, not in the fixup phase.
  `$NIX_BUILD_CORES` is the number of cores for `make -j`.
  [More](appendix-nix-concepts.md#the-fixup-phase-strip-patchelf-patchshebangs).

From earlier steps: [your own phases](appendix-nix-concepts.md#stdenvmkderivation-and-phases) (step 3), [`nativeBuildInputs`](appendix-nix-concepts.md#nativebuildinputs-buildinputs-and-path) (step 1), [`with`](appendix-nix-concepts.md#nix-language) (step 9), [reproducibility](appendix-nix-concepts.md#reproducibility) (step 12).

---

**Do:**

- `lfsStdenvFinal.mkDerivation`. Reuse the source of step 3: `src = headers.src;`.
- `nativeBuildInputs = with pkgs; [ bc bison flex perl openssl ];`. These are
  nixpkgs tools that run during the build. They do not go into the image.
- `postPatch = "patchShebangs scripts";`. Kernel scripts use
  `#!/usr/bin/env perl`, which does not exist in the sandbox.
- Fix the values that the kernel embeds, for a reproducible build:
  `KBUILD_BUILD_USER = "lfs"; KBUILD_BUILD_HOST = "lfs"; KBUILD_BUILD_TIMESTAMP = "1970-01-01";`.
- `configurePhase`: `make defconfig`. Start with `defconfig`, because it
  works. Make it smaller later.
- `buildPhase`: `make -j$NIX_BUILD_CORES Image`. Only the image, no modules.
- `installPhase`: copy `arch/arm64/boot/Image` and `.config` (as `config`) to `$out`.

**Verify:**

```console
$ nix build .#kernel -o result-kernel -L    # about 10 to 30 minutes
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

- `openssl/...h: No such file`: add `openssl.dev` to `nativeBuildInputs`, or
  disable the option that needs it with `scripts/config --disable <OPTION>`.
- A script fails with `bad interpreter`: run `patchShebangs` on that directory too.
