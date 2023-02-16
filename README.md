# hfi-root

This is the top level repo for the paper ``HFI'' . This repo will download and
build all tools used in the paper such as modified compilers, gem5 simulator
etc.

All original code written as part of this project (and pulled in through
Makefile as described below) are available under the MIT license. This applies
to both code written from scratch and any code changes to existing projects
(which may have their own licenses).

## Build Instructions

**Requirements** - This repo has been tested on Ubuntu 22.04.1 LTS.

**Note** - Do not use an existing machine; our setup installs/modifies packages
on the machine and has been well tested on a fresh Ubuntu Install. Use a fresh
VM or machine.


To build the repo, run

```bash
# Need make to run the scripts
sudo apt-get install make
# This installs required packages on the system.
# Only need to run once per system.
make bootstrap
# Download all sub-repos and build the world
make
```

For incremental builds after the first one, you can just use

```bash
make
```

To get the latest source of this repo and sub-repos, you can use

```bash
make pull
```

## Test Instructions

After building the repo, you can reproduce the tests we perform in the paper as follows.

### Gem5 sanity tests

Runs HFI tests on the gem5 simulator, to ensure it works as expected.

```bash
make test-gem5
```
