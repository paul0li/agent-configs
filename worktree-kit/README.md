# worktree-kit

`worktree.sh` gives each task its own git worktree, so several branches can be open and running
at once without stashing or stepping on each other:

- one worktree per branch, in a folder next to the main checkout (`../<prefix>-<description>`),
  branched from the latest `origin/<base>`;
- the git-ignored files listed in `.worktreeinclude` (e.g. `.env`) copied into it;
- the host ports in `WT_PORTS` shifted for it and written to its `.env`, so its Docker stack
  doesn't clash with the main checkout's or another worktree's.

Nothing in the script is project-specific: everything comes from `.worktree.conf` at the repo
root (see `worktree.conf.example` for every key and its default).

## Commands

```bash
scripts/worktree.sh new      feat/login   # new branch from origin/<base> -> ../<prefix>-login
scripts/worktree.sh checkout feat/login   # a branch that exists, here or on origin
scripts/worktree.sh sync                  # bring origin/<base> into the current branch
scripts/worktree.sh rm       feat/login   # stop its stack, remove the folder, delete the branch if merged
scripts/worktree.sh list                  # every worktree with its branch and ports
```

Branches are `<type>/<description>`, with a type from `WT_TYPES` (or `hotfix`). Run it from any
checkout of the repo.

## Install in a project

1. Copy `worktree.sh` to `scripts/worktree.sh` (its messages refer to that path) and make it
   executable: `git add --chmod=+x scripts/worktree.sh`.
2. Copy `worktree.conf.example` to `.worktree.conf` and `worktreeinclude.example` to
   `.worktreeinclude` at the repo root, and edit them.
3. Force LF line endings, since bash on Windows misreads CRLF. In `.gitattributes`:

   ```
   *.sh             text eol=lf
   /.worktree.conf  text eol=lf
   /.worktreeinclude text eol=lf
   ```

## Requirements

- bash 3.2 or later (macOS's bash works; on Windows, run it in Git Bash).
- git, plus the usual `sed`, `awk`, `grep` and `seq` (all in Git Bash).
- Optional: `docker` with `docker compose`. `rm` runs `docker compose down -v` in the worktree
  when it has a compose file and docker is installed, so its volumes don't outlive it; if that
  fails, `rm` stops without removing anything.
- Optional: `lsof`, to also skip ports something is listening on right now. Without it (as in
  Git Bash), ports are picked from the ones written in the worktrees' `.env` files and the
  defaults.
