# my-linux-distro

A Nix implementation of the *interesting* half of Linux From Scratch: build a
Linux toolchain from source, with nothing inherited from the build machine's
compiler except the one that bootstraps the first stage.

This is option C from the conversation that started it: not "an LFS VM", not
"a NixOS image", but **the bootstrap** — binutils → gcc → headers → glibc →
gcc again. The thing `pkgs/stdenv/linux/default.nix` does, at your scale.

---

## What success looks like

Not a bootable distro. A **binary that your own compiler built, running on the
machine that built it**. On an `aarch64-linux` builder that is achievable
without any chroot or bootloader, because target and builder are the same
architecture. Everything else in LFS (systemd, userland, kernel, GRUB) is
downstream of that moment and is not this project.

---

## Prerequisite: a Linux builder

None of this builds on `aarch64-darwin`. glibc will not build there at all, and
you would be cross-compiling for no reason.

You need one of:

- **nix-darwin's linux-builder**, which runs an `aarch64-linux` VM on Apple
  Silicon and lets `nix build` delegate to it. Check the option name for your
  nix-darwin version; it exposes a remote builder named `linux-builder`.
- **A Linux VM with Nix installed** (Lima, UTM, or a cloud box).

With a builder configured, everything is built for `aarch64-linux`:

```console
$ nix build .#packages.aarch64-linux.binutils
$ nix build .#packages.aarch64-linux.gccStage1
```

If you get `a 'aarch64-linux' with features {} is required to build ...`, the
builder is not configured. That is a prerequisite, not a bug.

---

## The ladder

Six rungs. Do not skip; each one produces something the next one consumes, and
each one has a check that tells you whether it actually worked.

### Rung 1 — binutils

**File:** `bootstrap/binutils.nix`

Built with the *host* compiler, on purpose. This is LFS pass 1 and it is not
cheating: everything after this point uses only what you built.

**Check:**

```console
$ nix build .#packages.aarch64-linux.binutils
$ ./result/tools/bin/aarch64-lfs-linux-gnu-ld --version
```

**Expected first failure:** `hash mismatch`. Copy the `got:` hash into
`lib.fakeHash`. This is the loop from Exercise 19, now with a real tarball.

**Second likely failure:** `configure` cannot find a C compiler. That is the
stdenv not being what you think; check `nix log`.

### Rung 2 — gcc stage 1

**File:** `bootstrap/gcc-stage1.nix`

The chicken-and-egg compiler: `--without-headers --with-newlib` means "there is
no libc, do not look for one". It can emit object files and cannot link.

**Check:**

```console
$ nix build .#packages.aarch64-linux.gccStage1
$ echo 'int main(void){return 0;}' > /tmp/hello.c
$ ./result/tools/bin/aarch64-lfs-linux-gnu-gcc -c /tmp/hello.c -o /tmp/hello.o
$ file /tmp/hello.o        # ELF 64-bit, ARM aarch64
```

**The check that should fail:** run the same command without `-c`. It must fail
with something about `crt1.o` or `-lc`. If it *succeeds*, you are not building a
stage-1 compiler, you are linking against the host's libc — and the whole
exercise is void.

**Likely failures:** gmp/mpfr/mpc configure probing. The `--with-*-include` and
`--with-*-lib` flags are there for exactly this; if configure still misses,
`nix log` will name the missing header, and you add the `.dev` output.

### Rung 3 — kernel headers

**File:** `bootstrap/headers.nix`

**Check:**

```console
$ nix build .#packages.aarch64-linux.headers
$ ls ./result/usr/include/linux/ | head
$ ls ./result/usr/include/asm/   | head
```

### Rung 4 — glibc, and the first real problem

This is where following LFS literally stops working, and it is the reason this
project is worth doing.

LFS says:

```
--with-headers=$LFS/usr/include
make DESTDIR=$LFS install
```

`$LFS` is a **directory that accumulates files across chapters**: headers go in
at 5.4, glibc at 5.5, gcc at 6.1, and every later stage reads the accumulated
result. Nix store paths are immutable. You cannot install into one and then
add to it.

So you have two choices, and you have to pick one deliberately:

**(a) Compose a sysroot.** Build `glibc` with `DESTDIR=$out`, build `headers`
with `$out/usr/include`, and merge them:

```nix
sysroot = pkgs.buildEnv {
  name = "lfs-sysroot";
  paths = [ headers glibc ];
  pathsToLink = [ "/usr" "/lib" "/lib64" ];
};
```

Then gcc stage 2 gets `--with-sysroot=${sysroot}` and
`--with-native-system-header-dir=/usr/include`. The merge is the `$LFS` of the
original recipe, made explicit.

**(b) Predict the path.** Refuse to accept immutability, hardcode a path under
`/tmp`, and lose reproducibility. Do not do this. If you find yourself reaching
for it, that is the lesson arriving.

The configure line for glibc, with (a) in mind:

```
../configure --prefix=/usr \
  --host=aarch64-lfs-linux-gnu \
  --build=$(../scripts/config.guess) \
  --enable-kernel=4.19 \
  --with-headers=${headers}/usr/include \
  --disable-nscd \
  libc_cv_slibdir=/usr/lib
```

Install with `make DESTDIR=$out install`. Then check:

```console
$ ls $out/usr/lib/libc.so $out/usr/lib/ld-linux-aarch64.so.1
```

The LFS "adjusting the toolchain" steps (rewriting `libc.so`, fixing the
dynamic loader path) are `sed` commands against `$LFS`. Here they become
`postInstall` edits against `$out` — same commands, different target directory.

### Rung 5 — gcc stage 2, and the payoff

Rebuild gcc against *your* glibc, with `--with-sysroot=${sysroot}`, no
`--without-headers`, no `--with-newlib`. Now:

```console
$ ./result/tools/bin/aarch64-lfs-linux-gnu-gcc /tmp/hello.c -o /tmp/hello
$ file /tmp/hello          # dynamically linked, interpreter your ld.so
$ /tmp/hello               # runs, because builder and target are both aarch64
```

That is the whole project. A compiler you built, linking against a libc you
built, producing a binary that runs.

### Rung 6 — the stretch: a userspace

`pkgsStatic.busybox` + an `init` + `runCommand` to assemble a tree, booted in
QEMU. This is where "distro" starts, and it is a different project with a
different failure mode (boot, not build).

---

## Debugging loop

The same one from Exercise 26, and it works here:

```console
$ nix build .#packages.aarch64-linux.binutils 2>&1 | tail -30
$ nix log /nix/store/....drv
$ nix develop .#packages.aarch64-linux.binutils
```

That last one is the important one: it drops you into the *build environment*
with `$src`, `$out` and `$PATH` set, so you can re-run `./configure` by hand and
iterate in seconds instead of minutes.

When you change a `configureFlag`, everything downstream rebuilds. That is the
DAG doing its job; it is also why you want to reach rung 5 once before you start
optimising anything.

---

## Status, honestly

I wrote and evaluated these derivations on `aarch64-darwin`, where **nothing
here can build** — see the prerequisite. Evaluation is verified; no rung has
been built end to end. Expect the first `nix build` to fail on the hash, the
second to fail on a prerequisite, and that to be the normal experience of
bootstrapping.

The configure flags are taken from LFS and adapted for a sandbox: `--prefix`
inside `$out`, out-of-tree builds, and prerequisites supplied by nixpkgs rather
than `contrib/download_prerequisites`. Where I had to diverge from LFS, there is
a comment saying so.
