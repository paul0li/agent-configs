#!/usr/bin/env bash
# One git worktree per task, each branched from the latest base and running its own Docker stack
# on host ports no other worktree uses. Settings live in .worktree.conf at the repo root.
#
#   scripts/worktree.sh new      feat/login      # new branch from origin/<base> → ../<prefix>-login
#   scripts/worktree.sh checkout feat/login      # a branch that exists, here or on origin
#   scripts/worktree.sh sync                     # bring origin/<base> into the current branch
#   scripts/worktree.sh rm       feat/login      # stop its stack, remove the folder, delete the
#                                                # branch if it's merged
#   scripts/worktree.sh list                     # every worktree with its branch and ports
#
# Works with bash 3.2 (macOS) and later. Run it from any checkout of the repo.
set -euo pipefail

usage() {
  sed -n '5,10p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

# The main checkout is the first entry of `git worktree list`, wherever this runs from.
main=$(git worktree list --porcelain | awk 'NR == 1 { sub(/^worktree /, ""); print; exit }')
here=$(git rev-parse --show-toplevel)

# Defaults, overridden by .worktree.conf (a shell file: KEY=value lines).
WT_PREFIX=$(basename "$main")
WT_LADDER="dev staging main"
WT_TYPES="feat fix chore refactor test ci docs experiment"
WT_PORTS=""
WT_PORT_ALIASES=""
WT_SLOT_MAX=99
conf="$main/.worktree.conf"
# shellcheck source=/dev/null
[[ -f $conf ]] && source "$conf"
# Working branches start from the first rung; hotfixes from the last unless the conf says
# otherwise (WT_HOTFIX_BASE= turns them off).
WT_BASE=${WT_LADDER%% *}
WT_HOTFIX_BASE=${WT_HOTFIX_BASE-${WT_LADDER##* }}

# Where a working branch's PR lands, so the branch it starts from and keeps up with.
base_of() {
  local branch=$1 type=${1%%/*} t
  if [[ -n $WT_HOTFIX_BASE && $type == hotfix ]]; then
    echo "$WT_HOTFIX_BASE"
    return
  fi
  for t in $WT_TYPES; do
    if [[ $type == "$t" ]]; then
      echo "$WT_BASE"
      return
    fi
  done
  echo "unknown branch type '$type' in $branch; use one of: $WT_TYPES${WT_HOTFIX_BASE:+ hotfix}" >&2
  exit 2
}

folder_for() {
  local description=${1#*/}
  echo "$(dirname "$main")/$WT_PREFIX-${description//\//-}"
}

port_names() {
  local entry
  for entry in $WT_PORTS; do echo "${entry%%:*}"; done
}

# Every port already claimed: listening right now, written in a worktree's .env, or a default.
ports_in_use() {
  local tree name entry
  lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR > 1 { sub(/.*:/, "", $9); print $9 }' || true
  git worktree list --porcelain | sed -n 's/^worktree //p' | while read -r tree; do
    [[ -f $tree/.env ]] || continue
    for name in $(port_names); do
      sed -nE "s/^$name=([0-9]+)\$/\\1/p" "$tree/.env"
    done
  done
  # The defaults belong to the main checkout even when its stack is down.
  for entry in $WT_PORTS; do echo "${entry#*:}"; done
}

# The first slot from 1 up where base+slot is free for every port in WT_PORTS.
pick_slot() {
  local used slot entry free
  used=$(ports_in_use | sort -u)
  for slot in $(seq 1 "$WT_SLOT_MAX"); do
    free=1
    for entry in $WT_PORTS; do
      if grep -qx "$((${entry#*:} + slot))" <<<"$used"; then
        free=0
        break
      fi
    done
    if [[ $free == 1 ]]; then
      echo "$slot"
      return
    fi
  done
  echo "no slot from 1 to $WT_SLOT_MAX has every port free" >&2
  exit 1
}

# Set KEY=value in a .env file, replacing the line if the key is already there.
set_env() {
  local file=$1 key=$2 value=$3
  if [[ -f $file ]] && grep -q "^$key=" "$file"; then
    sed -i.bak "s/^$key=.*/$key=$value/" "$file" && rm "$file.bak"
  else
    echo "$key=$value" >>"$file"
  fi
}

# Bring the local base branch up to origin too, so the main checkout isn't stale. Only a
# fast-forward: local commits, or edits in the way, leave it as it is, with a warning.
update_local_base() {
  local base=$1
  if [[ $(git -C "$main" symbolic-ref --quiet --short HEAD || true) == "$base" ]]; then
    git -C "$main" merge --ff-only --quiet "origin/$base" ||
      echo "warning: couldn't fast-forward $base in $main to origin/$base; left as is" >&2
  elif git -C "$main" show-ref --verify --quiet "refs/heads/$base" &&
    git -C "$main" merge-base --is-ancestor "$base" "origin/$base" 2>/dev/null; then
    git -C "$main" branch --force "$base" "origin/$base" >/dev/null
  fi
}

has_compose() {
  local dir=$1 file
  for file in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do
    [[ -f $dir/$file ]] && return 0
  done
  return 1
}

cmd_new() {
  local branch=$1 base folder
  base=$(base_of "$branch")
  folder=$(folder_for "$branch")
  [[ -e $folder ]] && { echo "$folder already exists" >&2; exit 1; }
  git -C "$main" fetch origin
  update_local_base "$base"
  git -C "$main" worktree add "$folder" -b "$branch" "origin/$base"
  git -C "$folder" branch --unset-upstream 2>/dev/null || true  # push creates its own upstream
  echo "from origin/$base at $(git -C "$main" log -1 --format='%h %s' "origin/$base")"
  prepare "$branch" "$folder"
}

cmd_checkout() {
  local branch=$1 folder
  folder=$(folder_for "$branch")
  [[ -e $folder ]] && { echo "$folder already exists" >&2; exit 1; }
  git -C "$main" fetch origin
  if git -C "$main" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$main" worktree add "$folder" "$branch"
  elif git -C "$main" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    git -C "$main" worktree add --track -b "$branch" "$folder" "origin/$branch"
  else
    echo "no branch $branch here or on origin; to start one: scripts/worktree.sh new $branch" >&2
    exit 1
  fi
  prepare "$branch" "$folder"
}

# Copy the git-ignored files into the new worktree and give it its own ports.
prepare() {
  local branch=$1 folder=$2 path slot entry name alias target
  if [[ -f $main/.worktreeinclude ]]; then
    grep -vE '^[[:space:]]*(#|$)' "$main/.worktreeinclude" | while read -r path; do
      if [[ -f $main/$path ]]; then
        mkdir -p "$(dirname "$folder/$path")"
        cp "$main/$path" "$folder/$path"
        echo "copied $path"
      fi
    done
  fi

  echo
  echo "Ready: $folder on $branch"
  echo "  cd $folder"
  if [[ -n $WT_PORTS ]]; then
    slot=$(pick_slot)
    for entry in $WT_PORTS; do
      name=${entry%%:*}
      set_env "$folder/.env" "$name" "$((${entry#*:} + slot))"
      echo "  $name=$((${entry#*:} + slot))"
    done
    for alias in $WT_PORT_ALIASES; do
      target=${alias#*=}
      for entry in $WT_PORTS; do
        [[ ${entry%%:*} == "$target" ]] && set_env "$folder/.env" "${alias%%=*}" "$((${entry#*:} + slot))"
      done
    done
  fi
  if has_compose "$folder"; then
    echo "  docker compose up --build"
  fi
  echo "  set -a; source .env; set +a    # before tools that run outside Docker"
  echo "Remove it once merged: scripts/worktree.sh rm $branch"
}

# Bring origin/<base> into the branch checked out here, so work builds on current code.
cmd_sync() {
  local branch base
  branch=$(git symbolic-ref --quiet --short HEAD) || { echo "not on a branch" >&2; exit 1; }
  base=$(base_of "$branch")
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "uncommitted changes: commit or stash them, then sync" >&2
    exit 1
  fi
  git fetch origin "$base"
  if git merge-base --is-ancestor "origin/$base" HEAD; then
    echo "$branch already has origin/$base"
    return
  fi
  echo "merging $(git rev-list --count "HEAD..origin/$base") commit(s) from origin/$base"
  git merge --no-edit "origin/$base"
}

cmd_rm() {
  local branch=$1 folder
  folder=$(folder_for "$branch")
  [[ -d $folder ]] || { echo "$folder does not exist" >&2; exit 1; }
  [[ $folder == "$main" ]] && { echo "refusing to remove the main checkout" >&2; exit 1; }
  [[ $folder == "$here" ]] && { echo "you are inside $folder; run this from another checkout" >&2; exit 1; }
  # Volumes outlive `git worktree remove`: stop the stack first or its database is orphaned.
  if has_compose "$folder" && command -v docker >/dev/null; then
    if ! (cd "$folder" && docker compose down -v); then
      echo "couldn't stop $folder's stack. Start Docker and run this again, so its volumes go too" >&2
      exit 1
    fi
  fi
  git -C "$main" worktree remove "$folder"
  if ! git -C "$main" branch -d "$branch"; then
    echo "kept $branch: not merged. Delete it with git branch -D $branch if you're done with it" >&2
  fi
  git -C "$main" worktree list
}

cmd_list() {
  local tree branch name ports
  git worktree list --porcelain | sed -n 's/^worktree //p' | while read -r tree; do
    branch=$(git -C "$tree" symbolic-ref --quiet --short HEAD 2>/dev/null || echo "(detached)")
    ports=""
    for name in $(port_names); do
      if [[ -f $tree/.env ]] && grep -q "^$name=" "$tree/.env"; then
        ports="$ports $(grep "^$name=" "$tree/.env" | tail -1)"
      fi
    done
    [[ $tree == "$main" ]] && ports=" (defaults)"
    echo "$tree  [$branch]$ports"
  done
}

[[ $# -ge 1 ]] || usage
case $1 in
  new | checkout | rm)
    [[ $# -eq 2 && $2 == */* ]] || { echo "usage: scripts/worktree.sh $1 <type>/<description>" >&2; exit 2; }
    "cmd_$1" "$2"
    ;;
  sync | list)
    [[ $# -eq 1 ]] || usage
    "cmd_$1"
    ;;
  *) usage ;;
esac
