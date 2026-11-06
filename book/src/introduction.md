# Introduction

A Nix implementation of the *interesting* half of Linux From Scratch: build a
Linux toolchain from source, use it to build a Nix `stdenv` that contains no
binary from the host, then build a minimal Linux system with that stdenv and
boot it in QEMU.

This is **way A**: do the bootstrap by hand, one derivation at a time, so that
every step is visible. nixpkgs does the same job in
`pkgs/stdenv/linux/default.nix`. Read that file after you finish; you will
recognise every stage.

You write every derivation. Each chapter tells you what to write and how to
check it.

The book has five parts and two appendices. Each step is one chapter. Read
the parts in order: every step uses the results of the steps before it.
This book also teaches Nix. "Nix basics" below gives the minimum that you
need before step 0. Each step then starts with "Nix concepts for this step":
a short explanation of each concept that the step uses for the first time.
Appendix B has the full entry for each concept.

## Linux From Scratch

This book exists because of **Linux From Scratch** (LFS), a project that
Gerard Beekmans started in 1999. The LFS book shows how to build a complete
Linux system from source code, one package at a time, and it explains each
step. Since 1999, a community of editors and contributors has kept it up to
date.

- Website: <https://www.linuxfromscratch.org/>
- The LFS book (current stable version):
  <https://www.linuxfromscratch.org/lfs/view/stable/>
- The version that this book follows, LFS 12.2:
  <https://www.linuxfromscratch.org/lfs/view/12.2/>
- Beyond LFS (BLFS), for the packages after the base system:
  <https://www.linuxfromscratch.org/blfs/>

This book takes from LFS:

- the sequence of the bootstrap: a cross toolchain, temporary tools, then a
  rebuild of each package with the new tools (LFS chapters 5, 6 and 8)
- the package versions (LFS 12.2) and most of the configure flags
- the reason for each step, which the LFS book explains in more detail

This book changes the method. Nix replaces the shared `$LFS` directory and
the chroot: each package is a derivation with its own store path, and each
build runs in the Nix sandbox. Where a derivation differs from LFS, the
chapter or a comment says so. Each step that follows an LFS chapter names it
under "Read first". Read the LFS chapter first: it explains the packages
better than this book does.

This book is not part of the LFS project, and the LFS project does not
endorse it. All credit for the method goes to the LFS editors. Any error here
is the error of this book.

## The big picture

### The problem: tools that make tools

A compiler is a program. To make a program, you need a compiler. So, to make
your first compiler, you need a compiler that somebody else made.

Think of a blacksmith with no hammer. To make a hammer, the blacksmith needs a
hammer. The solution:

1. Borrow a hammer from the neighbour.
2. Make a rough hammer with it.
3. Make a good hammer with the rough hammer.
4. Give back the neighbour's hammer.
5. Make one more good hammer with your good hammer. Now no part of it came
   from the neighbour.

This book does the same with software. The neighbour is the **host**: the
Ubuntu system in your VM or container, and the nixpkgs tools in it. The
hammers are binutils, gcc and glibc.

```
 host tools ──► cross toolchain ──► temporary tools ──► lfsStdenv ──► lfsStdenvFinal ──► bootable system
 (borrowed)     Parts 1 and 2        Part 3, steps 7-8   step 9        step 11            Part 4
                "rough hammer"                          "good hammer"  "made only by you"
```

### Three words first

| Word | What it is | Like |
|---|---|---|
| **binutils** | The assembler and the linker. They turn compiler output into a program file, and join the parts together. | The glue and the screws. |
| **gcc** | The compiler. It turns C code into machine code. | The machine that cuts the parts. |
| **glibc** | The C library. Almost every program uses it to print, open files, and talk to the kernel. | The box of standard parts that every product needs. |

### Part 0 — A room to work in

**What:** an aarch64 Linux machine with Nix: your own machine, a VM or a
container.

**Why:** the checks run Linux programs. macOS cannot run them, and the macOS
disk does not see a difference between `a` and `A`. The Linux kernel source has files whose names
differ only in case. Nix also gives each build a **sandbox**: a closed room
that contains only the things you give to the build. If a build uses
something that you did not give it, the build fails. You see the error at
once, not later.

### Part 1 — A compiler for a machine that does not exist yet

**What:** binutils, a first gcc, and the kernel headers.

**Why:** the host gcc makes programs for the host. You want programs for
*your* system. Your system has its own name: `aarch64-lfs-linux-gnu`. A
compiler that runs on one system and makes programs for a different system is
a **cross compiler**.

| Step | What it is | Why you need it |
|---|---|---|
| 1 binutils | The glue and screws for your system | gcc gives assembly code. Something must turn it into a program file. |
| 2 gcc stage 1 | A compiler that can compile, but cannot make a full program | A full program needs glibc, and glibc does not exist yet. This gcc is good enough to build glibc. |
| 3 kernel headers | The list of what the kernel can do for a program | glibc must know how to ask the kernel for things, for example "open this file". |

### Part 2 — The standard parts, and a full compiler

**What:** glibc, a sysroot, and a second gcc.

| Step | What it is | Why you need it |
|---|---|---|
| 4 glibc | The box of standard parts, built by gcc stage 1 | Every program that gcc makes needs it. |
| 5 sysroot | One folder that looks like a small Linux system: headers and glibc | gcc looks for headers and libraries in fixed places. The sysroot puts them where gcc looks. |
| 6 gcc stage 2 | A full cross compiler, with C++ | Now glibc exists, so gcc can make complete programs. |

**Milestone 1:** a program made by your compiler runs and prints the version
of *your* glibc. Your rough hammer works.

### Part 3 — Give back the borrowed hammer

**What:** your tools build all the other tools, and then build themselves
again.

**Why:** until now the host built every tool. Your gcc stage 2 is your own
work, but it runs on the host and uses host parts. You want a toolbox in which
nothing comes from the host.

| Step | What it is | Why you need it |
|---|---|---|
| 7 temporary tools | bash, coreutils, make, sed and others, built by *your* compiler | A build needs more than a compiler: a shell, `cp`, `make`. They are **static**: each one carries all its parts inside, and needs nothing from outside to run. |
| 8 native glibc, binutils, gcc | Tools that make programs for the same system they run on | A cross compiler makes programs for a different system. Now you need a compiler that lives on your system. |
| 9 `lfsStdenv` | The tools from steps 7 and 8, packed in the shape that Nix expects | Every nixpkgs recipe uses a **stdenv**: a fixed toolbox with a shell, a compiler and a set of tools. Yours has the same shape, so recipes can use it. |
| 10 first package | GNU hello, built with `lfsStdenv` | A small test before the big job. |
| 11 rebuild | Everything again, built with `lfsStdenv` | The tools from steps 7 and 8 were made by gcc stage 2, and gcc stage 2 was made by the host. A second build removes this link. It is the "one more hammer" of the blacksmith. |
| 12 proof | A check of the full list of parts | `nix path-info -r` lists every package that the final stdenv needs. It must show only your packages. |

**Milestone 2:** a Nix stdenv with no host program in it.

### Part 4 — A computer that starts

**What:** a kernel and a file system, built with your stdenv. They start in
QEMU.

**Why:** a toolbox is not a system. A system must start, give you a shell,
and run programs. QEMU is a program that acts as a computer, so you can start
your system without real hardware.

| Step | What it is | Why you need it |
|---|---|---|
| 13 the rule and the layout | The plan for the image (read only) | It says which files go where, and that everything in the image comes from your stdenv. |
| 14 kernel | The program that controls the hardware and runs all other programs | With no kernel, nothing starts. |
| 15 busybox | One small program that acts as many commands: `init`, `mount`, `ls` | A system needs a first program (`init`) and small tools to start. |
| 16 system tree | `/bin`, `/etc` and the configuration files | Programs look for `/bin/sh`, `/etc/passwd` and others. The tree puts them there. |
| 17 initramfs and first boot | A small box of files that the kernel unpacks into memory when it starts | It is the easiest way to give the kernel a first program. You see your system start. |
| 18 ext4 disk | The same system on a disk image | Files in memory are lost at power-off. Files on a disk stay. |
| 19 self-hosting | gcc *inside* the system compiles a program | The system can make new programs alone. It does not need the host for that. |
| 20 proof for the image | A check of every file in the image | It must show only packages that your stdenv built. |

**Milestone 3:** the system starts from the initramfs. **Milestone 4:** it
starts from its own disk and compiles a program.

## What success looks like

There are four milestones.

| Milestone | After step | Proof |
|---|---|---|
| 1. A binary that your compiler built, linked against your glibc, runs | 6 | It prints the version of *your* glibc, not the host glibc. |
| 2. A Nix `stdenv` with no host binary in it | 12 | `nix path-info -r` of the final stdenv shows only your packages. |
| 3. A minimal system boots in QEMU from an initramfs | 17 | `/proc/version` names your gcc; PID 1 is your busybox. |
| 4. The system boots from its own disk and compiles a program | 19 | `gcc` inside the guest builds a binary that prints `glibc 2.40`. |

## Nix basics

Read this section before step 0. Each item has a longer entry in
[Appendix B](appendix-nix-concepts.md).

### The store and derivations

Nix keeps each package in its own directory in `/nix/store`:

```
/nix/store/k4pypqqp5gavw9ywipn4pabs2n5vhxv4-lfs-final-bash-5.2.32
           \______________________________/ \__________________/
            a hash of all inputs of the build     the name
```

A store path never changes after the build. If one input changes (a flag, a
source file, the compiler), the hash changes, and Nix builds a new path.

A **derivation** is the recipe for one store path: the builder, the
arguments, the environment and the inputs. Nix works in two phases:

| Phase | What happens | Command |
|---|---|---|
| Evaluation | Nix runs your `.nix` code and writes the recipe, a `.drv` file. Nothing is built. | `nix eval --raw .#binutils.drvPath` |
| Build | Nix runs the recipe in the **sandbox** and makes the store path. | `nix build .#binutils` |

The sandbox is an isolated directory. A build sees only the store paths that
it declares, and it has no network. This book uses the sandbox as the LFS
chroot.

### The Nix language in ten lines

Every `.nix` file of this book is one function. Try the lines in `nix repl`:

```nix
{ a = 1; b = "x"; }                  # an attribute set
x: x + 1                             # a function with one argument
{ a, b ? 2 }: a + b                  # a function that takes a set; b has a default
(x: x + 1) 41                        # a call: 42. No parentheses around the argument.
let a = 1; in a + 1                  # local names: 2
{ inherit a; }                       # the same as { a = a; }
{ a = 1; } // { a = 2; b = 3; }      # merge: { a = 2; b = 3; }. The right side wins.
"${pkg}/bin"                         # interpolation: the store path of pkg, plus "/bin"
'' two
    lines ''                         # a multi-line string
import ./file.nix                    # the value of the file
```

Interpolation of a package does two things: it gives the store path, and it
makes the package an input of the build.

### A package

A package file is a function of the packages that it needs. It returns a
derivation:

```nix
{ stdenv, fetchurl }:                       # the arguments

stdenv.mkDerivation rec {
    pname = "hello";
    version = "2.12.3";
    src = fetchurl {                        # a download with a known hash
        url = "mirror://gnu/hello/hello-${version}.tar.gz";
        hash = "sha256-…";
    };
    configureFlags = [ "--disable-nls" ];   # added to ./configure
}
```

`stdenv.mkDerivation` runs the phases of a GNU package: unpack, patch,
`./configure --prefix=$out`, `make`, `make install`, and a fixup. `$out` is
the store path of the result. `stdenv` is the **standard environment**: a
shell, the basic tools (coreutils, sed, make and others) and a C compiler.
Part 3 builds your own stdenv.

You call a package file with `callPackage`:

```nix
hello = pkgs.callPackage ./hello { };
```

`callPackage` gives each argument with the same name from nixpkgs. You can
replace an argument: `callPackage ./hello { stdenv = lfsStdenv; }`. Step 10
does that.

### Flakes

`flake.nix` is the entry point of the repo. It has `inputs` (here only
nixpkgs) and `outputs` (here `legacyPackages.aarch64-linux.*`). `flake.lock`
pins nixpkgs to one revision. `.#binutils` means "the attribute `binutils` of
the flake in this directory".

A flake sees only the files that git tracks. After you write a new file, run
`git add <file>`. A commit is not necessary.

### The commands of each step

| Command | What it does |
|---|---|
| `nix build .#x -o result-x -L` | Builds `x`, shows the log (`-L`), and makes the link `result-x` to the store path. |
| `nix log ./result-x` | Shows the log of the last build of `x`. Also works after a failed build, with the `.drv` path. |
| `nix eval --raw .#x.drvPath` | Evaluates only. Shows the `.drv` file. |
| `nix path-info -r ./result-x` | The **closure**: `x` and each store path that it refers to, also indirectly. |
| `nix why-depends ./result-x <path>` | Shows the chain of references from `x` to `<path>`. |

Nix finds references by a scan of the output for the hashes of other store
paths. The closure is the main proof of this book: when a closure has no host
path, no host program is left in it.

## How to read each step

Each step has the same parts:

- **Nix concepts for this step**: at the start. Each concept that the step
  uses for the first time, with a short explanation, and a link to its entry
  in [Appendix B — Nix concepts](appendix-nix-concepts.md). Then the links to
  the concepts of earlier steps that the step uses again.
- **Do**: what to build or write.
- **Verify**: commands with the expected result as a comment. Run all of them.
  Do not continue to the next step if one check fails.
- **If it fails**: the most likely causes.

## The code layout

Each part of the book has its own directory. Each component has its own
directory with a `default.nix`. The `default.nix` at the top of a directory
collects its components.

```
flake.nix                   wires the directories into the flake
lfs-toolchain/  steps 1-6   binutils/ gcc-stage1/ linux-headers/ glibc/ sysroot/ gcc-stage2/
lfs-temp/       steps 7-8   lib.nix (the helper), one directory per tool, glibc/ binutils/ gcc/
lfs-stdenv/     steps 9-10  default.nix (lfsStdenv), hello/
lfs-final/      step 11     one directory per package, default.nix (the stage stdenvs)
lfs-stdenv-final/ step 11   default.nix (lfsStdenvFinal, stage 4)
lfs-distro/     steps 14-18 default.nix (busybox), kernel/ sysenv/ etc/ init/ initrd/ root-image/
```

Step 0 writes `flake.nix` and the start of `lfs-toolchain/default.nix`.
Create the other directories when you reach their part. `flake.nix` exposes everything under
`legacyPackages.aarch64-linux`:

| Directory | How `flake.nix` imports it | Attributes the checks use |
|---|---|---|
| `lfs-toolchain/` | Merged at the top (step 0) | `binutils`, `gccStage1`, `headers`, `glibc`, `sysroot`, `gccStage2`, `toolchain` |
| `lfs-temp/` | As `temp` | `temp.gnumake` ... `temp.tools`, `temp.glibc`, `temp.binutils`, `temp.gcc` |
| `lfs-stdenv/` | Merged at the top | `lfsStdenv`, `hello` |
| `lfs-final/` | As `final` | `final.glibc` ... `final.patchelf`, `final.lfsStdenvFinalGlibc`, `final.lfsStdenvFinalToolchain` |
| `lfs-stdenv-final/` | At the top, with `helloFinal` (step 11, stage 4) | `lfsStdenvFinal`, `helloFinal` |
| `lfs-distro/` | Merged at the top | `kernel`, `busybox`, `sysenv`, `etc`, `init`, `initrd`, `rootImage` |

On an aarch64-linux machine, `.#binutils` is short for
`.#legacyPackages.aarch64-linux.binutils`.

## Conventions

- Run every command **in your Linux environment of step 0** (the VM, the
  container or the machine), in the repo directory.
- The prompt shows where a command runs. `$` is the environment of step 0,
  which has Nix. `#` is the QEMU guest of steps 17 to 19, which has no Nix.
- Some commands need the absolute path of the repo. They use `/work`, which is
  the path in the container of route 0b. On another route, use the path of
  your repo.
- Give every build its own out-link with `-o`, so the results of earlier steps
  stay available:

  ```console
  $ nix build .#binutils -o result-binutils
  ```

- Set these variables once per shell. Later steps add more.

  ```console
  $ T=aarch64-lfs-linux-gnu
  $ B=$PWD/result-binutils/tools/bin
  ```

- Name every derivation with a prefix that tells where it belongs:

  | Prefix | Built by | Steps |
  |---|---|---|
  | `lfs-` | The host stdenv (cross tools, sysroot) | 1 to 6 |
  | `lfs-temp-` | Your cross compiler (temporary tools) | 7 and 8 |
  | `lfs-final-` | Your own stdenv | 11 to 20 |

  The checks in step 12 use these prefixes with `grep`.

## Status

- Steps 0 to 11 were done again from the book text, in a new container and an
  empty store (November 2026). Each check gave the expected result. The full
  run takes about 2.5 hours. The gcc builds take the most time: about 15,
  20, 17 and 30 minutes (steps 2, 6, 8 and 11).
- Steps 12 to 20 are not built yet.
- Part 4 uses nixpkgs for tools that run during the build (kernel build
  tools, `makeInitrd`, `make-ext4-fs.nix`, QEMU), and for the busybox recipe.
  Everything inside the image is built by your stdenv. Step 20 checks this.
- The configure flags come from LFS. The LFS book targets x86_64; this book
  targets aarch64. Where a derivation diverges from LFS, a comment or the
  chapter says so.
