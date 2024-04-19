# emplacetree

A minimal script that deploys and undeploys file trees via symlink or copy
without configuration.

```sh
# Deploy SOURCE tree to DESTINATION via symlink.
# Symlinks to directories in SOURCE are dereferenced recursively.
emplacetree ln SOURCE DESTINATION

# Deploy SOURCE tree to DESTINATION by copying.
# Symlinks to directories in SOURCE are dereferenced recursively.
emplacetree cp SOURCE DESTINATION

# If any node of DESTINATION corresponding to a node in SOURCE has changed, then
# do nothing and report the difference. Otherwise...
# Remove every corresponding node from DESTINATION and prune empty directories
# recursively.
emplacetree rm SOURCE DESTINATION

# List relative paths to leaves in SOURCE.
emplacetree ls SOURCE
```

There is zero configuration involved, beyond choosing whether to symlink or copy
the files. Behaviour is unapologetically opinionated, chosen to be as simple as
I could imagine.

# Why?

I used [stow] and then [xstow] for years to deploy my dotfiles, but kept running
into issues because their behaviour was often more complicated than I needed
(not to mention leading to outstanding bugs). I understand that working with
symlinks requires some care, especially if you want to optimise. However, for
me, this nuance came at the cost of me not being confident that the tool would
do what I wanted, or safely. I have designed this tool to be as minimal as
possible, such that it is able to deploy my [nix]-derived dotfiles and not
necessarily more.

To elaborate, here were my main priorities when designing the tool:
* Deploy `SOURCE` to a `DESTINATION` that may contain additional files not in
  `SOURCE`.
* Refuse to clobber anything. Refuse to delete anything that does not appear in
  `SOURCE`.
* When a conflict does occur, do nothing else.
* Always behave the same, regardless of whether a target directory already
  exists in `DESTINATION`.
* Clearly differentiate between directory-like and leaf-like files. Deployed
  directories should be ordinary directories (never symlinks) owned by the
  current user. Deployed symlinks to leaves should be absolute symlinks.
* Both deploy and undeploy operations should be idempotent.

# Design choices

Since a major goal of this script was to require and allow zero configuration,
some opinionated decisions had to be made. This section attempts to make clear
what those decisions were and why I made them.

> Do we recursively dereference symlinks to directories?

Yes.

In order to deploy alongside an already nonempty `DESTINATION` tree,
clearly we must dereference symlinks to directories sometimes. In order to have
deterministic behaviour that does not depend on whether destination directories
already exist, we must always dereference.

> Relative or absolute symlinks?

Absolute.

Why not? Absolute symlinks are easier to inspect, especially when
`SOURCE` and `DESTINATION` are disjoint. The only time I personally prefer
relative symlinks is when I'm linking within a Git repository. But why would
anyone clone a tree within a Git repository? If you have a good reason, let me
know!

> How to handle conflicts?

Do not clobber, unless the destination is equivalent to its source.

Obviously, we want the default behaviour to avoid clobbering files. One
possibility was to never clobber, even if the destination is semantically
equivalent to the source. I decided instead to proceed successfully if the
destination is equivalent, in order to make the tool idempotent.

> Let the user exclude files?

No.

That would be configuration, and we refuse to support configuration. If you wish
to avoid deploying some files, then you must remove them from the `SOURCE` tree.

> Must the destination root `DESTINATION` exist?

No, create `DESTINATION` if it does not exist.

This avoids treating the root directory as a special case; in general, we create
any path components as necessary. One downside is that it does not prevent you
from making a little typo and deploying the entire tree to a new erroneous path.
On the other hand, such an error is easily corrected by running `emplacetree rm`
on the mistaken root.

# Details

## Definitions

* The _canonical path_ of a given path is obtained by following symlinks in
  every component of the path until no initial segment of the path is a symlink.
  We use the implementation [`realpath -e`][realpath].
* Two paths are _equivalent_ when their canonical paths are equal or they have
  identical contents.
* A _leaf_ is a node whose canonical path is a regular file. That is, it is a
  regular file or a symlink to one and not a directory, symlink to directory,
  nor special file.
* A _directory-like_ node is path whose canonical path is a directory, i.e. a
  directory or symlink to one.
* Given a path `R/P` inside a tree, where `R` is `SOURCE` or `DESTINATION`, we
  call `P` the _relative path_.
* For a pair `(SOURCE/P, DESTINATION/P)`, we call the former the _source_ and
  the latter the _destination_.

## Safety checks (`emplace check SOURCE DESTINATION`)

All commands run the following checks before proceeding:
* If `SOURCE` or `DESTINATION` exists but is not directory-like, then abort with
  status `4`.
* If the destination of any directory-like source exists but is not a directory,
  then abort with status `3`.
* If the destination of any leaf exists but is not equivalent to its source,
  then abort with status `2`.

## `emplacetree ln SOURCE DESTINATION`

Symlink `DESTINATION` leaves to `SOURCE` leaves.

* For every directory-like source `SOURCE/P` that does not already exist, create
  the directory `DESTINATION/P` as the current user.
* For every source leaf `SOURCE/P`, create a symlink pointing from
  `DESTINATION/P` to `SOURCE/P`.

## `emplacetree cp SOURCE DESTINATION`

Copy `SOURCE` leaves to `DESTINATION` leaves.

* For every directory-like source `SOURCE/P` that does not already exist, create
  the directory `DESTINATION/P` as the current user.
* For every source leaf `SOURCE/P`, copy `SOURCE/P` to `DESTINATION/P`. Preserve
  mode, but set the destination's ownership to the current user and group.

## `emplacetree rm SOURCE DESTINATION`

Remove the largest partial embedding of `SOURCE` from `DESTINATION`.

* For every source leaf `SOURCE/P`, remove `DESTINATION/P`.
* For every directory-like source `SOURCE/P`, remove `DESTINATION/P` if and only
  if it is empty.

## `emplacetree ls SOURCE`

List leaves.

* Report the relative paths of all leaves in `SOURCE` in a `\n`-delimited list.
* No path in the list is empty.

Tip: If you desire full paths instead, then do something like
```sh
emplacetree ls SOURCE | rargs echo SOURCE/{}
```

# Installation

Dependencies:
* [bash]
* [GNU Coreutils][coreutils]
* [GNU Diffutils][diffutils]
* [fd]

The preferred use is as a [nix] flake. Therefore, the file `emplacetree.sh` is
written under the assumption that you build the script using [nixpkgs
`writeShellApplication`][nixpkgs-writeshellapp]. However, one should be able to
run the script with [bash], assuming you have the dependencies in your path.

# Alternatives

* [stow]
* [xstow]
* [`cp -LR`][cp]
* [home-manager]
* [chemzoi]

# Bugs

* The script is technically not atomic.

---
[stow]: https://github.com/aspiers/stow
[xstow]: https://github.com/majorkingleo/xstow
[nix]: https://nixos.org/
[cp]: https://www.gnu.org/software/coreutils/manual/html_node/cp-invocation.html
[readlink]: https://www.gnu.org/software/coreutils/manual/html_node/readlink-invocation.html
[fd]: https://github.com/sharkdp/fd
[home-manager]: https://github.com/nix-community/home-manager
[chemzoi]: https://www.chezmoi.io/
[ln]: https://www.gnu.org/software/coreutils/manual/html_node/ln-invocation.html
[rmdir]: https://www.gnu.org/software/coreutils/manual/html_node/rmdir-invocation.html
[test]: https://www.gnu.org/software/coreutils/manual/html_node/test-invocation.html
[coreutils]: https://www.gnu.org/software/coreutils/
[nixpkgs-writeshellapp]: https://nixos.org/manual/nixpkgs/stable/#trivial-builder-writeShellApplication
[bash]: https://www.gnu.org/software/bash/
[realpath]: https://www.gnu.org/software/coreutils/manual/html_node/realpath-invocation.html
[diffutils]: https://www.gnu.org/software/diffutils/diffutils.html
