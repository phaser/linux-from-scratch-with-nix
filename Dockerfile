# Step 0b of the book: a container replacement for the Step 0a VM: aarch64 Linux + Nix with the sandbox on.
#
# Build (no context needed; the repo is mounted at run time):
#   docker build -t lfs-nix - < Dockerfile
#
# Run from the repo root:
#   docker run --rm -it --privileged \
#     -v lfs-nix-store:/nix \
#     -v "$PWD":/work \
#     lfs-nix
#
# Then, inside the container:
#   nix build .#binutils -o result-binutils -L
#
# --privileged: the Nix sandbox (the "chroot" of this project) needs mount and
#   user namespaces. Without it, every build fails (sandbox-fallback = false).
# lfs-nix-store: a named volume, so the store survives between containers. It is
#   on the Linux side of Docker, so it is case-sensitive (kernel headers need that).
#   On first use Docker copies the image's /nix into it. After you rebuild the
#   image, remove it: docker volume rm lfs-nix-store
# /work: the repo from the Mac. Nix copies the flake into the store, so the
#   case-insensitive macOS file system does not matter. result-* links point
#   into the volume, so they work only inside the container.
#
# Part 4 (QEMU): use -accel tcg -cpu max unless /dev/kvm exists in the container.
# Give the Docker VM 8 CPUs and 16 GB of memory or more, as for the Tart VM.

FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git xz-utils \
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
