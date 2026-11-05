# Step 0 — A Linux environment with Nix

None of this builds on `aarch64-darwin`:

- The flake pins `system = "aarch64-linux"`.
- The kernel headers need a case-sensitive file system. The macOS `/nix`
  volume is case-insensitive APFS.
- macOS cannot execute the Linux binaries that the checks run.

You need an aarch64 Linux system with Nix, the Nix sandbox, and a
case-sensitive `/nix`. This step gives two routes. Do one of them:

| | 0a — Tart VM | 0b — Docker container |
|---|---|---|
| Runs on | A Linux VM (Ubuntu), with SSH | A container in the Docker VM |
| The repo | A copy in the VM (`rsync`) | The Mac folder, mounted at `/work` |
| The store | The VM disk | The `lfs-nix-store` volume |
| Edit files | Copy them again after each change, or edit in the VM | Edit on the Mac. The container sees the change at once. |
| `result-*` links | Work in the VM | Work only in the container |
| `git push` | From the VM, if it has your key | From the Mac only. The container has no `ssh`. |
| KVM for QEMU (Part 4) | Yes (`--nested`) | No. Use `-accel tcg -cpu max`. |

**Nix concepts for this step**

New in this step:

- **The store.** Nix keeps each package in `/nix/store`. Step 3 needs a
  case-sensitive file system, so the store is on the disk of the VM, or in a
  Docker volume. It is not on the Mac. [More](appendix-nix-concepts.md#the-store).
- **The sandbox.** Each build runs isolated, with only its declared inputs and
  no network. `nix config show sandbox` must print `true`. Without the sandbox,
  a build can use host files, and the checks of this book prove nothing.
  [More](appendix-nix-concepts.md#the-sandbox).
- **Flakes.** `.#triple` means "the attribute `triple` of the flake in this
  directory". Nix looks for it in
  `legacyPackages.aarch64-linux`. The flake sees only the files that git tracks.
  [More](appendix-nix-concepts.md#flakes).
- **Evaluation and build.** `nix eval --raw .#triple` evaluates the code, but
  builds nothing. The check in "Verify" uses it to prove that the flake
  evaluates. In step 1, `nix eval --raw .#binutils.drvPath` shows the recipe,
  a `.drv` file, also without a build.
  [More](appendix-nix-concepts.md#evaluation-and-build).

---

## 0a — A Tart VM

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

Then do the checks in "Verify" below.

## 0b — A Docker container

**Files to write:** `Dockerfile` and `docker-compose.yml`, in the repo root

You need Docker on an Apple silicon Mac (Docker Desktop, OrbStack, or Colima).
The Docker VM is aarch64 Linux, so the container is aarch64 too. In the Docker
settings, give the VM 8 CPUs and 16 GB of memory or more, as for the Tart VM.

1. Write the `Dockerfile`. It installs Nix in Ubuntu, with the sandbox on:

   ```dockerfile
   FROM ubuntu:24.04

   RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl file git xz-utils \
    && rm -rf /var/lib/apt/lists/*

   # --init none: no systemd in a container, so there is no daemon.
   # store = local: root uses the store directly instead of the daemon socket.
   # sandbox-fallback = false: fail, do not silently build without the sandbox.
   #   The installer drops it from --extra-conf, so append it directly.
   # The self-test warning during the build is expected (it tries the daemon).
   RUN curl -fsSL https://install.determinate.systems/nix \
     | sh -s -- install linux --init none --no-confirm \
         --extra-conf "sandbox = true" \
         --extra-conf "store = local" \
    && echo "sandbox-fallback = false" >> /etc/nix/nix.custom.conf

   ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"

   # The mounted repo belongs to the Mac user, not root; git refuses it without this.
   RUN git config --system --add safe.directory '*'

   WORKDIR /work
   CMD ["bash", "-l"]
   ```

   | Line | Why |
   |---|---|
   | `ca-certificates curl` | The Nix installer downloads over HTTPS. |
   | `file` | The checks use `file` to show the type of a program. |
   | `git` | A flake in a git repository needs `git`. Nix reads only the files that git tracks. |
   | `xz-utils` | The installer unpacks a `.tar.xz` file. |
   | `--init none` | A container has no systemd, so the installer must not set up the daemon. |
   | `store = local` | With no daemon, root uses the store directly. |
   | `sandbox = true`, `sandbox-fallback = false` | Every build runs in the sandbox. If the sandbox cannot start, the build fails. It does not run without the sandbox. |
   | `safe.directory '*'` | The mounted repo belongs to your Mac user, and the container runs as root. Without this line, git refuses the repo. |

2. Write `docker-compose.yml`:

   ```yaml
   services:
     lfs:
       build: .
       image: lfs-nix
       privileged: true          # the Nix sandbox needs namespaces
       volumes:
         - nix-store:/nix
         - .:/work
       working_dir: /work
       stdin_open: true
       tty: true

   volumes:
     nix-store:
       name: lfs-nix-store       # a fixed name: each run uses the same store
   ```

   | Line | Why |
   |---|---|
   | `privileged: true` | The sandbox needs mount and user namespaces. Without them, every build fails. |
   | `nix-store:/nix` | The store is in a named volume. It is on the Linux side of Docker, so it is case-sensitive. It also stays when the container stops. On the first run, Docker copies the `/nix` of the image into the volume. |
   | `.:/work` | The repo folder on the Mac. This folder is case-insensitive. That is not a problem: Nix copies the flake into the store before it builds. |
   | `stdin_open`, `tty` | An interactive shell. |

3. Build the image and open a shell:

   ```console
   $ docker compose build
   $ docker compose run --rm lfs                  # a shell in /work
   ```

   You can also run one command, without a shell:

   ```console
   $ docker compose run --rm lfs nix build .#binutils -o result-binutils -L
   ```

Some messages are normal:

- `volume "lfs-nix-store" already exists but was not created by Docker Compose`:
  the volume has a fixed name. Each `docker compose run` uses the same store.
- `warning: Git tree '/work' has uncommitted changes`: Nix uses the files as
  they are on disk, also when you did not commit them.

When you change the `Dockerfile`, the volume still holds the old `/nix`.
Remove the volume, then build again. This also removes every build in the
store.

```console
$ docker compose build && docker volume rm lfs-nix-store
```

The `result-*` links point into the volume, so they work only in the
container. On the Mac they show as broken links. Run git commands on the
Mac. The container has no git identity, no `ssh` and no key.

## The start files

**Files to write:** `flake.nix` and `lfs-toolchain/default.nix`. Copy
`flake.lock` from this repo, so that you get the same nixpkgs.

Do this in the repo directory: on the Mac for 0b, in the VM for 0a.

1. Write `flake.nix`:

   ```nix
   {
     description = "my-linux-distro: a Linux toolchain from source, LFS-style, with Nix";

     inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

     outputs = { self, nixpkgs }:
       let
         system = "aarch64-linux";
         pkgs = import nixpkgs { inherit system; };
       in {
         # legacyPackages, not packages: legacyPackages can nest (.#temp.gnumake).
         # Steps 7, 9 and 11 add more attributes here.
         legacyPackages.${system} = import ./lfs-toolchain { inherit pkgs; };
       };
   }
   ```

2. Write `lfs-toolchain/default.nix`. Steps 1 to 6 add one attribute each:

   ```nix
   # Your cross toolchain: steps 1 to 6.
   { pkgs }:

   let
     inherit (pkgs) callPackage linkFarm;
     triple = "aarch64-lfs-linux-gnu";
   in
   rec {
     inherit triple;
   }
   ```

   The set is `rec`, so that an attribute can use another one: step 2 gives
   `binutils` to gcc. `triple` is in the set, because later steps use
   `toolchain.triple`.

3. Make git track the files:

   ```console
   $ git add flake.nix flake.lock lfs-toolchain
   ```

## Verify

Run these checks in the VM (0a) or in the container (0b):

```console
$ uname -m                                   # aarch64
$ nix --version                              # prints a version
$ nix config show sandbox                    # true
$ d=$(mktemp -d -p /nix); touch $d/a $d/A; ls $d | wc -l; rm -r $d    # 2 (case-sensitive)
$ df -h /nix | tail -1                       # 40G or more available
$ nix eval --raw .#triple                    # aarch64-lfs-linux-gnu
$ ldd --version | head -1                    # the HOST glibc version; write it down for step 6
```

For 0b, also do these checks:

```console
$ nix config show sandbox-fallback           # false
$ nix config show store                      # local
$ d=$(mktemp -d -p /work); touch $d/a $d/A; ls $d | wc -l; rm -r $d   # 1: /work is the Mac folder
```

The last check shows why the store must be in the volume: `/work` is
case-insensitive.

**If it fails (0b):**

- Every build fails, with an error about namespaces or the sandbox: the
  container is not privileged. Check `privileged: true`.
- `uname -m` shows `x86_64`: the Docker VM is not aarch64. This route needs an
  Apple silicon Mac.
- `fatal: detected dubious ownership in repository at '/work'`: the image does
  not have the `safe.directory` line. Build the image again.
