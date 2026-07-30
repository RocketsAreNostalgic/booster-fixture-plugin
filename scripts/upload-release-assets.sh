#!/usr/bin/env bash

set -euo pipefail

fail() {
	printf 'upload-release-assets: %s\n' "$*" >&2
	exit 1
}

tag=${1:-}
shift || true
[[ -n "$tag" ]] || fail 'release tag is required.'
(( $# > 0 )) || fail 'at least one asset is required.'

existing_names=$(gh release view "$tag" --json assets --jq '.assets[].name')
temporary_dir=$(mktemp -d "${TMPDIR:-/tmp}/booster-fixture-upload.XXXXXX")
trap 'rm -rf "$temporary_dir"' EXIT

for asset in "$@"; do
	[[ -f "$asset" ]] || fail "asset does not exist: $asset"
	name=$(basename "$asset")

	if grep -Fqx "$name" <<< "$existing_names"; then
		gh release download "$tag" --pattern "$name" --dir "$temporary_dir"
		cmp "$asset" "$temporary_dir/$name" \
			|| fail "published asset conflicts with local build: $name"
		printf 'Verified existing %s\n' "$name"
		continue
	fi

	gh release upload "$tag" "$asset"
	printf 'Uploaded %s\n' "$name"
done
