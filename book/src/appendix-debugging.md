# Appendix A — Debugging a build

```console
$ nix build .#<name> -L            # stream the full log
$ nix log .#<name>                 # the log of the last failed build
$ nix build .#<name> --keep-failed # keep the build directory under /tmp
$ nix develop .#<name>             # a shell with the build environment
```

In `nix develop`, run the phases by hand: `unpackPhase`, `cd` into the source,
then `configurePhase`, `buildPhase`. Change a flag and run the phase again.
This takes seconds instead of a full rebuild. Note that `nix develop` runs
outside the sandbox: host files such as `/usr/include` are visible there.

When you change a `configureFlag`, every later step rebuilds. That is the
dependency graph doing its job. Reach milestone 1 before you optimise
anything.
