#!/usr/bin/env bash

set -euo pipefail

fail() {
	printf 'upload-release-assets: %s\n' "$*" >&2
	exit 1
}

[[ $# -eq 2 ]] || fail 'expected <tag> <zip>.'
tag=$1
archive=$2
name=$(basename -- "$archive")
repository=${GITHUB_REPOSITORY:-}

[[ "$tag" =~ ^v[0-9A-Za-z][0-9A-Za-z.-]*$ ]] || fail 'release tag is invalid.'
[[ -f "$archive" && "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*\.zip$ ]] \
	|| fail 'release ZIP is invalid.'
[[ "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] \
	|| fail 'GITHUB_REPOSITORY is invalid.'

assets=$(gh release view "$tag" --repo "$repository" --json assets --jq '.assets[].name')
asset_count=0
zip_count=0
expected_count=0
while IFS= read -r asset; do
	[[ -n "$asset" ]] || continue
	asset_count=$((asset_count + 1))
	if [[ "$asset" == *.zip ]]; then
		zip_count=$((zip_count + 1))
		[[ "$asset" == "$name" ]] && expected_count=$((expected_count + 1))
	fi
done <<< "$assets"

if [[ $expected_count -eq 0 ]]; then
	[[ $asset_count -eq 0 ]] || fail 'release already contains unexpected assets.'
	gh release upload "$tag" "$archive" --repo "$repository"
fi
if [[ $expected_count -ne 0 ]]; then
	[[ $expected_count -eq 1 && $zip_count -eq 1 && $asset_count -eq 1 ]] \
		|| fail 'release contains ambiguous assets.'
fi

temporary_dir=$(mktemp -d "${TMPDIR:-/tmp}/booster-fixture-upload.XXXXXX")
trap 'rm -rf "$temporary_dir"' EXIT
gh release download "$tag" --repo "$repository" --pattern "$name" --dir "$temporary_dir"
cmp -s "$archive" "$temporary_dir/$name" \
	|| fail 'an existing release ZIP has different bytes.'

local_digest=$(shasum -a 256 "$archive" | awk '{ print $1 }')
remote_digest=$(
	gh release view "$tag" \
		--repo "$repository" \
		--json assets \
		--jq ".assets[] | select(.name == \"$name\") | .digest"
)
[[ "$remote_digest" == "sha256:$local_digest" ]] \
	|| fail 'GitHub asset digest does not match the verified release ZIP.'
