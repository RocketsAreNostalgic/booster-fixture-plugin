#!/usr/bin/env bash

set -euo pipefail

fail() {
	printf 'test-release-contract: %s\n' "$*" >&2
	exit 1
}

repo_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
workflow="$repo_root/.github/workflows/release-please.yml"
uploader="$repo_root/scripts/upload-release-assets.sh"

assert_contains() {
	local file=$1
	local expected=$2
	grep -Fq -- "$expected" "$file" \
		|| fail "$(basename -- "$file") is missing: $expected"
}

bash -n "$repo_root/scripts/build-release.sh"
bash -n "$uploader"
bash -n "$0"

assert_contains "$workflow" 'googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7'
assert_contains "$workflow" 'actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd'
assert_contains "$workflow" 'skip-github-release: true'
assert_contains "$workflow" 'git diff --quiet HEAD^ HEAD -- .release-please-manifest.json && manifest_changed=false'
assert_contains "$workflow" 'gh api --paginate --slurp "repos/${GITHUB_REPOSITORY}/releases?per_page=100"'
assert_contains "$workflow" 'select(.tag_name == $tag)'
assert_contains "$workflow" 'git log -1 --format=%H -- .release-please-manifest.json'
assert_contains "$workflow" "'.target_commitish'"
assert_contains "$workflow" 'The published release is not immutable'
assert_contains "$workflow" 'git checkout --detach "${RAN_RELEASE_COMMIT}"'
assert_contains "$workflow" '--target "${RAN_RELEASE_COMMIT}"'
assert_contains "$workflow" '--repo "${GITHUB_REPOSITORY}"'
assert_contains "$workflow" 'RAN_IMMUTABLE_RELEASES_ENABLED'
assert_contains "$workflow" "--jq '.immutable'"
assert_contains "$workflow" 'for delay in 0 2 2 2 2'
assert_contains "$uploader" '--repo "$repository"'
assert_contains "$uploader" "'GitHub asset digest does not match the verified release ZIP.'"

version=$(tr -d '[:space:]' < "$repo_root/version.txt")
output_dir=$(mktemp -d "${TMPDIR:-/tmp}/booster-fixture-contract.XXXXXX")
trap 'rm -rf "$output_dir"' EXIT
bash "$repo_root/scripts/build-release.sh" HEAD "$version" "$output_dir"
archive="$output_dir/booster-fixture-plugin-$version.zip"
[[ -f "$archive" ]] || fail 'the exact-ref build did not produce the expected ZIP.'
unzip -tqq "$archive" >/dev/null || fail 'the exact-ref build produced an invalid ZIP.'

if bash "$repo_root/scripts/build-release.sh" HEAD '999.999.999' "$output_dir" >/dev/null 2>&1; then
	fail 'the builder accepted metadata that disagrees with the requested version.'
fi

bash "$repo_root/tests/upload-release-assets.sh"

printf 'Release workflow and exact-ref archive contract passed.\n'
