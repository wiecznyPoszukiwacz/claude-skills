#!/usr/bin/env bash
# branch-preflight — verify repo is ready to branch off.
# Non-destructive except `git fetch --prune --all`. See SKILL.md for contract.
set -u

base="develop"
new_branch=""

while [[ $# -gt 0 ]]; do
	if [[ "$1" == "--base" ]]; then
		[[ $# -ge 2 ]] || { echo "❌ --base requires a value" >&2; exit 2; }
		base="$2"
		shift 2
	elif [[ "$1" == "--new-branch" ]]; then
		[[ $# -ge 2 ]] || { echo "❌ --new-branch requires a value" >&2; exit 2; }
		new_branch="$2"
		shift 2
	elif [[ "$1" == "-h" || "$1" == "--help" ]]; then
		cat <<EOF
Usage: preflight.sh [--base <branch>] [--new-branch <name>]
	--base         base branch to verify (default: develop)
	--new-branch   planned new branch name; verifies it doesn't exist
Exit 0 on OK, non-zero on refusal (reason + fix on stdout).
EOF
		exit 0
	else
		echo "❌ Unknown argument: $1" >&2
		exit 2
	fi
done

fail() {
	echo "❌ $1"
	exit 1
}

command -v git >/dev/null 2>&1 || fail "git CLI not found. Fix: zainstaluj git"

# 1. Sanity repo
[[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]] \
	|| fail "Not inside a git work tree. Fix: cd do katalogu repozytorium"

[[ -n "$(git remote)" ]] \
	|| fail "No git remote configured. Fix: git remote add origin <url>"

git symbolic-ref -q HEAD >/dev/null \
	|| fail "Detached HEAD. Fix: git checkout <branch>"

# 2. No operation in progress
git_dir="$(git rev-parse --git-dir)"
[[ -f "$git_dir/MERGE_HEAD" ]] \
	&& fail "Merge in progress ($git_dir/MERGE_HEAD exists). Fix: git merge --abort  (lub dokończ merge)"
[[ -f "$git_dir/CHERRY_PICK_HEAD" ]] \
	&& fail "Cherry-pick in progress. Fix: git cherry-pick --abort  (lub dokończ)"
[[ -f "$git_dir/REVERT_HEAD" ]] \
	&& fail "Revert in progress. Fix: git revert --abort  (lub dokończ)"
[[ -d "$git_dir/rebase-apply" || -d "$git_dir/rebase-merge" ]] \
	&& fail "Rebase in progress. Fix: git rebase --abort  (lub dokończ)"

# 3. Clean working copy
porcelain="$(git status --porcelain)"
if [[ -n "$porcelain" ]]; then
	untracked_count="$(printf '%s\n' "$porcelain" | grep -c '^??' || true)"
	if [[ "$untracked_count" -gt 0 ]]; then
		fail "Untracked files present. Fix: git add -A && git stash -u  (lub dopisz do .gitignore)"
	fi
	fail "Uncommitted changes present. Fix: git commit -am '...'  (lub git stash)"
fi

stashed="$(git stash list)"
if [[ -n "$stashed" ]]; then
	stash_count="$(printf '%s\n' "$stashed" | wc -l | tr -d ' ')"
	fail "Stash is not empty ($stash_count entries). Fix: git stash pop  (lub git stash drop)"
fi

# 4. Submodules
if git submodule status 2>/dev/null | grep -qE '^[+-]'; then
	fail "Submodules have uncommitted or uninitialized state. Fix: git submodule update --init  (lub commit zmian w submodule)"
fi

# 5. Git LFS
top_level="$(git rev-parse --show-toplevel)"
if [[ -f "$top_level/.gitattributes" ]] && grep -q 'filter=lfs' "$top_level/.gitattributes"; then
	command -v git-lfs >/dev/null 2>&1 \
		|| fail "Repo uses Git LFS but git-lfs is not installed. Fix: zainstaluj git-lfs"
fi

# 6. Upstream of current branch
current="$(git rev-parse --abbrev-ref HEAD)"
upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [[ -n "$upstream" ]]; then
	ahead="$(git rev-list --count "${upstream}..HEAD" 2>/dev/null || echo 0)"
	behind="$(git rev-list --count "HEAD..${upstream}" 2>/dev/null || echo 0)"
	[[ "$ahead" -eq 0 ]] \
		|| fail "Branch '$current' is ahead of '$upstream' by $ahead commits. Fix: git push"
	[[ "$behind" -eq 0 ]] \
		|| fail "Branch '$current' is behind '$upstream' by $behind commits. Fix: git pull --ff-only"
else
	if git log --oneline -1 >/dev/null 2>&1; then
		fail "Branch '$current' has no upstream but has commits. Fix: git push -u origin $current  (lub zdecyduj co z commitami)"
	fi
fi

# 7. Base branch readiness
git fetch --prune --all --quiet \
	|| fail "git fetch failed. Fix: sprawdź połączenie z remote"

git rev-parse --verify "origin/$base" >/dev/null 2>&1 \
	|| fail "Base branch 'origin/$base' does not exist. Fix: sprawdź nazwę brancha bazowego"

# 8. New-branch name collision
if [[ -n "$new_branch" ]]; then
	if git rev-parse --verify "refs/heads/$new_branch" >/dev/null 2>&1; then
		fail "Branch '$new_branch' already exists locally. Fix: wybierz inną nazwę lub usuń lokalny branch"
	fi
	if [[ -n "$(git ls-remote --heads origin "$new_branch")" ]]; then
		fail "Branch '$new_branch' already exists on origin. Fix: wybierz inną nazwę lub usuń zdalny branch"
	fi
fi

# Success report
current_sha="$(git rev-parse --short HEAD)"
base_sha="$(git rev-parse --short "origin/$base")"

printf '✅ branch-preflight: OK\n'
printf '  repo:      %s\n' "$top_level"
printf '  current:   %s @ %s  (upstream: %s)\n' "$current" "$current_sha" "${upstream:--}"
printf '  base:      origin/%s @ %s\n' "$base" "$base_sha"
printf '  new:       %s\n' "${new_branch:--}"
