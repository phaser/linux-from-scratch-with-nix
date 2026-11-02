# Step 3 — kernel headers

**File:** `bootstrap/headers.nix`

**Do:**

```console
$ nix build .#packages.aarch64-linux.headers -o result-headers -L
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
                                                  # the same hash as in headers.nix
```

**If it fails:** a tool is missing from the sandbox. Add it to
`nativeBuildInputs` (for example `perl`, `bison` or `flex`).

**Nix concepts:** [the sandbox](appendix-nix-concepts.md#the-sandbox), [SRI hashes](appendix-nix-concepts.md#fixed-output-derivations).
