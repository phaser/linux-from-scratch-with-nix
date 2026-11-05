# Step 18 — root on an ext4 disk

An initramfs lives in RAM and is lost at power-off. A real root file system is
on a disk.

**File to write:** `lfs-distro/root-image/default.nix`, attribute `rootImage`

**Nix concepts for this step**

New in this step:

- **`callPackage` with a nixpkgs path.**
  `pkgs.callPackage "${nixpkgs}/nixos/lib/make-ext4-fs.nix" { … }` uses a file
  of the nixpkgs source that is not a package attribute.
  [More](appendix-nix-concepts.md#callpackage).

From earlier steps: [`closureInfo`](appendix-nix-concepts.md#closureinfo) (step 17), [multi-line strings](appendix-nix-concepts.md#nix-language) (step 3).

---

**Do:** use the NixOS helper `nixos/lib/make-ext4-fs.nix`. It copies the
closure of `storePaths` into the image, and `populateImageCommands` adds your
own files. It runs `mkfs.ext4` under `fakeroot`, so files belong to root.

```nix
rootImage = pkgs.callPackage "${nixpkgs}/nixos/lib/make-ext4-fs.nix" {
  storePaths = [ sysenv etc ];
  volumeLabel = "lfs-root";
  populateImageCommands = ''
    mkdir -p ./files/usr ./files/root ./files/tmp ./files/proc ./files/sys ./files/dev
    ln -s ${sysenv}/bin  ./files/bin
    ln -s ${sysenv}/sbin ./files/sbin
    ln -s ${sysenv}/bin  ./files/usr/bin
    ln -s ${etc}         ./files/etc
  '';
};
```

The kernel mounts `/dev` itself when the root is on a disk
(`CONFIG_DEVTMPFS_MOUNT`), so there is no `/init` script. The kernel runs
`/sbin/init` directly.

**Verify:**

```console
$ nix build .#rootImage -o result-root.img -L
$ file -L result-root.img                          # Linux rev 1.0 ext4 filesystem data, ... volume name "lfs-root"
$ install -m 644 result-root.img /tmp/root.img     # QEMU needs a writable copy
$ qemu-system-aarch64 -M virt -accel kvm -cpu host -m 1024 -nographic \
    -kernel result-kernel/Image \
    -drive file=/tmp/root.img,if=virtio,format=raw \
    -append "console=ttyAMA0 root=/dev/vda rw"
```

Inside the guest:

```console
# mount | grep ' / '         # /dev/vda on / type ext4 (rw,...)
# echo persisted > /root/proof; poweroff
```

Boot again with the same command, then:

```console
# cat /root/proof            # persisted
```

**If it fails:** `VFS: Unable to mount root fs`. The kernel has no
`VIRTIO_BLK` or no `EXT4_FS` built in. Check `result-kernel/config` (step 14).
