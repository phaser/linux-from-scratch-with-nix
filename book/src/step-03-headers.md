# Step 3 — kernel headers

**File to write:** `lfs-toolchain/linux-headers/default.nix`, attribute `headers`

**Read first:** the LFS book, chapter 5, "Linux API Headers".

glibc needs the shape of the kernel's system call interface. LFS installs the
headers into `$LFS/usr/include`. Here they go to their own store path, and
step 5 combines them with glibc.

**Nix concepts for this step**

New in this step:

- **Your own phases.** `dontConfigure = true;` skips the configure phase. To
  replace a phase, write it, and keep its hooks:

  ```nix
  buildPhase = ''
      runHook preBuild
      make
      runHook postBuild
  '';
  ```

  [More](appendix-nix-concepts.md#stdenvmkderivation-and-phases).
- **Multi-line strings.** `'' … ''` is a string over several lines. Nix
  removes the common indentation. [More](appendix-nix-concepts.md#nix-language).
- **SRI hashes.** A hash has the form `sha256-<base64>`.
  `nix hash convert --hash-algo sha256 --to sri <hex>` converts a hex hash, as
  the kernel publishes it. [More](appendix-nix-concepts.md#fixed-output-derivations).

From earlier steps: [the sandbox](appendix-nix-concepts.md#the-sandbox) (step 0): a tool that you do not declare is not there, [`nativeBuildInputs`](appendix-nix-concepts.md#nativebuildinputs-buildinputs-and-path) (step 1).

---

**Do:**

1. Write `lfs-toolchain/linux-headers/default.nix`:

   ```nix
   { lib, stdenv, fetchurl }:

   stdenv.mkDerivation rec {
       pname = "lfs-linux-headers";
       version = "6.12";

       src = fetchurl {
           url = "http://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${version}.tar.xz";
           hash = "sha256-saJWK+VuQq+z+EidTCp6xHKsIwmPHvHB5A2mAfVGJes=";
       };

       dontConfigure = true;

       buildPhase = ''
           runHook preBuild
           make mrproper
           make headers
           runHook postBuild
       '';

       installPhase = ''
           runHook preInstall
           find usr/include -type f ! -name '*.h' -delete
           mkdir -p $out/usr/include
           cp -r usr/include/. $out/usr/include
           runHook postInstall
       '';

       meta = {
           description = "Linux ${version} userspace headers";
           platforms = lib.platforms.linux;
       };
   }
   ```

   | Line | Why |
   |---|---|
   | `version = "6.12"` | The kernel of LFS 12.2. Step 14 builds the kernel from the same source. |
   | `dontConfigure = true` | The kernel has no `./configure`. |
   | `buildPhase` | The two `make` commands of LFS. |
   | `installPhase` | LFS removes each file that is not a header, then copies `usr/include`. The headers go to `$out/usr/include`. |
   | `runHook` lines | A phase that you write must call its hooks, so that `preBuild`, `postInstall` and the others still run. |

   The file does not set `ARCH`. Without `ARCH`, the kernel build reads the
   architecture from `uname -m`. On aarch64, that gives `arm64`. To make the
   build independent of the build machine, write `make ARCH=arm64 headers`.

2. Add the attribute to `lfs-toolchain/default.nix`:

   ```nix
   headers = callPackage ./linux-headers { };
   ```

3. Make git track the new file:

   ```console
   $ git add lfs-toolchain/linux-headers
   ```

**Build:**

```console
$ nix build .#headers -o result-headers -L
$ H=$PWD/result-headers/usr/include
```

**Verify:**

```console
$ ls $H                                           # asm  asm-generic  drm  linux  misc  mtd  rdma  scsi  sound  video  xen ...
$ find $PWD/result-headers -type f ! -name '*.h' | wc -l      # 0
$ grep -r '__NR_openat' $H | head -1              # one line: the syscall numbers are there
$ ls $H/linux/netfilter | grep -i '^xt_connmark.h$'
                                                  # 2 lines: xt_CONNMARK.h and xt_connmark.h
$ echo '#include <linux/types.h>' | $G1/$T-gcc -E -I $H - | tail -1
                                                  # no error: gcc stage 1 + your headers work together
```

The `netfilter` check is the reason for the case-sensitive file system.

Optional: compare the source hash with the kernel's signed list.

```console
$ curl -s https://cdn.kernel.org/pub/linux/kernel/v6.x/sha256sums.asc | grep ' linux-6.12.tar.xz'
$ nix hash convert --hash-algo sha256 --to sri <hex-from-the-line-above>
                                                  # the same hash as in your file
```

**If it fails:** a tool is missing from the sandbox. Add it to
`nativeBuildInputs` (for example `perl`, `bison` or `flex`).

