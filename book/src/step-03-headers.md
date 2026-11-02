# Step 3 — kernel headers

**File to write:** `lfs-toolchain/linux-headers/default.nix`, attribute `headers`

**Read first:** the LFS book, chapter 5, "Linux API Headers".

glibc needs the shape of the kernel's system call interface. LFS installs the
headers into `$LFS/usr/include`. Here they go to their own store path, and
step 5 combines them with glibc.

**Do:** write a derivation that meets these requirements.

1. The file is a function of `{ lib, stdenv, fetchurl }`.
2. The source is Linux **6.12** from `cdn.kernel.org`.
3. It runs the same two `make` commands as LFS.
4. It removes every file that is not a header, as LFS does.
5. The headers install to `$out/usr/include`.

<details>
<summary>Hint 1: there is no configure script</summary>

The kernel has no `./configure`. Look up `dontConfigure`.

</details>

<details>
<summary>Hint 2: your own phases</summary>

You replace `buildPhase` and `installPhase` with your own commands. A custom
phase must call `runHook preBuild` and `runHook postBuild` (or `preInstall` and
`postInstall`), so that hooks still run.

</details>

<details>
<summary>Hint 3: the architecture</summary>

The kernel build reads the architecture from `uname -m` when you do not set
`ARCH`. In the VM, that gives `arm64`. Think about whether you want to depend on
that, or set it.

</details>

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

**Compare with the answer key:**

```console
$ diff -u solutions/lfs-toolchain/linux-headers/default.nix lfs-toolchain/linux-headers/default.nix
$ nix run nixpkgs#nix-diff -- $(nix eval --raw .#solutions.headers.drvPath) $(nix eval --raw .#headers.drvPath)
```

**If it fails:** a tool is missing from the sandbox. Add it to
`nativeBuildInputs` (for example `perl`, `bison` or `flex`).

**Nix concepts:** [the sandbox](appendix-nix-concepts.md#the-sandbox),
[SRI hashes](appendix-nix-concepts.md#fixed-output-derivations),
[phases](appendix-nix-concepts.md#stdenvmkderivation-and-phases).
