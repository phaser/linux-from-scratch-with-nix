# Step 0 — A Linux VM with Nix

None of this builds on `aarch64-darwin`:

- The flake pins `system = "aarch64-linux"`.
- The kernel headers need a case-sensitive file system. The macOS `/nix`
  volume is case-insensitive APFS.
- macOS cannot execute the Linux binaries that the checks run.

**Do** (on the Mac, with Tart):

```console
$ tart clone ghcr.io/cirruslabs/ubuntu:latest lfs
$ tart set lfs --cpu 8 --memory 16384 --disk-size 80
$ tart run lfs --no-graphics --nested &          # --nested: KVM for QEMU in Part 4
$ rsync -a ~/projects/my-linux-distro admin@$(tart ip lfs):   # password: admin
$ ssh admin@$(tart ip lfs)
```

Then, inside the VM:

```console
$ curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
$ . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
$ cd my-linux-distro
```

Copy the repo with `rsync`. Do not use `tart run --dir`: a shared folder stays
on the case-insensitive macOS volume.

**Verify:**

```console
$ uname -m                                   # aarch64
$ nix --version                              # prints a version
$ nix config show sandbox                    # true
$ d=$(mktemp -d); touch $d/a $d/A; ls $d | wc -l; rm -r $d    # 2 (case-sensitive)
$ df -h /nix | tail -1                       # 40G or more available
$ nix eval --raw .#solutions.binutils.drvPath    # /nix/store/...-lfs-binutils-2.43.drv
$ ldd --version | head -1                    # the HOST glibc version; write it down for step 6
```

**Nix concepts:** [flakes](appendix-nix-concepts.md#flakes), [evaluation and build](appendix-nix-concepts.md#evaluation-and-build),
[the sandbox](appendix-nix-concepts.md#the-sandbox).
