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
