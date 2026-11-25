#!/bin/bash
# Pushes through the github-8529398670 host alias in ~/.ssh/config, which picks the key.
Remote="git@github-8529398670:8529398670/WoWGamePadTweaks.git"
Key="$HOME/.ssh/github-wsu-m1"

ssh-add -D
git init
git config --global --unset user.name 2>/dev/null
git config --global --unset user.email 2>/dev/null
git config user.name "8529398670"
git config user.email "banjo.kazooie.2955@gmail.com"
ssh-add "$Key"

# Count on from the highest numbered commit, so a worded message can't reset it.
LastCommit=$(git log --pretty=%s 2>/dev/null | grep -E '^[0-9]+$' | sort -n | tail -1)
NextCommitNumber=$((${LastCommit:-0}+1))

git add .
git tag -l | xargs git tag -d
# With nothing to commit there is no new number, so no tag is made or moved.
if git diff --cached --quiet; then
	echo "Nothing new to commit, pushing what is already here"
elif [ -n "$1" ]; then
	git commit -m "$1"
	# A numbered message is its own tag; a worded one takes the next number.
	if [[ "$1" =~ ^[0-9]+$ ]]; then
		git tag "v1.0.$1"
	else
		git tag "v1.0.$NextCommitNumber"
	fi
else
	git commit -m "$NextCommitNumber"
	git tag "v1.0.$NextCommitNumber"
fi

# Point origin at the alias whether or not it already exists.
if git remote get-url origin >/dev/null 2>&1; then
	git remote set-url origin "$Remote"
else
	git remote add origin "$Remote"
fi
git push origin --tags --force
git push origin "$(git branch --show-current)"