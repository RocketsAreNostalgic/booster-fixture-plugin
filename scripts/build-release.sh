#!/usr/bin/env bash

set -euo pipefail

fail() {
	printf 'build-release: %s\n' "$*" >&2
	exit 1
}

repo_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ref=${1:-HEAD}
expected_version=${2:-}
output_dir=${3:-"$repo_root/build"}

[[ "$expected_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] \
	|| fail 'expected version must be an exact release version.'

commit=$(git -C "$repo_root" rev-parse --verify "$ref^{commit}") \
	|| fail 'release ref does not resolve to a commit.'
[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || fail 'release commit is invalid.'

plugin_source=$(git -C "$repo_root" show "$commit:booster-fixture-plugin.php") \
	|| fail 'plugin source is missing at the release ref.'
header_version=$(
	printf '%s\n' "$plugin_source" \
		| sed -nE 's/^[[:space:]]*\*[[:space:]]*Version:[[:space:]]*([^[:space:]]+).*/\1/p'
)
version_source=$(git -C "$repo_root" show "$commit:version.txt") \
	|| fail 'version source is missing at the release ref.'
version_source=$(printf '%s' "$version_source" | tr -d '[:space:]')
marker_source=$(git -C "$repo_root" show "$commit:fixture-marker.txt") \
	|| fail 'fixture marker is missing at the release ref.'
marker_version=$(printf '%s\n' "$marker_source" | sed -nE 's/^booster-fixture-plugin ([^[:space:]]+)$/\1/p')
[[ "$header_version" == "$expected_version" ]] \
	|| fail 'plugin header version does not match the expected version.'
[[ "$version_source" == "$expected_version" ]] \
	|| fail 'version source does not match the plugin header.'
[[ "$marker_version" == "$expected_version" ]] \
	|| fail 'fixture marker version does not match the plugin header.'
printf '%s\n' "$plugin_source" \
	| grep -Fqx ' * Update URI: https://github.com/RocketsAreNostalgic/booster-fixture-plugin' \
	|| fail 'plugin Update URI is invalid.'

mkdir -p "$output_dir"
output_dir=$(CDPATH='' cd -- "$output_dir" && pwd)
archive_name="booster-fixture-plugin-$expected_version.zip"
temporary_dir=$(mktemp -d "${TMPDIR:-/tmp}/booster-fixture-plugin-release.XXXXXX")
trap 'rm -rf "$temporary_dir"' EXIT

archive="$temporary_dir/$archive_name"
git -C "$repo_root" archive \
	--format=zip \
	--prefix=booster-fixture-plugin/ \
	--output="$archive" \
	"$commit" \
	README.md \
	booster-fixture-plugin.php \
	fixture-marker.txt

unzip -tqq "$archive" >/dev/null || fail 'release ZIP is invalid.'
expected_paths=$'booster-fixture-plugin/\nbooster-fixture-plugin/README.md\nbooster-fixture-plugin/booster-fixture-plugin.php\nbooster-fixture-plugin/fixture-marker.txt'
actual_paths=$(unzip -Z1 "$archive")
[[ "$actual_paths" == "$expected_paths" ]] \
	|| fail 'release ZIP does not match the exact runtime allowlist.'
if zipinfo -l "$archive" | awk '$1 ~ /^l/ { found = 1 } END { exit !found }'; then
	fail 'release ZIP must not contain symbolic links.'
fi

archived_version=$(
	unzip -p "$archive" booster-fixture-plugin/booster-fixture-plugin.php \
		| sed -nE 's/^[[:space:]]*\*[[:space:]]*Version:[[:space:]]*([^[:space:]]+).*/\1/p'
)
[[ "$archived_version" == "$expected_version" ]] \
	|| fail 'archived plugin version does not match the expected version.'

archive_size=$(wc -c < "$archive" | tr -d '[:space:]')
archive_sha256=$(shasum -a 256 "$archive" | awk '{ print $1 }')
[[ "$archive_size" =~ ^[1-9][0-9]*$ ]] || fail 'release ZIP size is invalid.'
[[ "$archive_sha256" =~ ^[0-9a-f]{64}$ ]] || fail 'release ZIP digest is invalid.'

mv -f "$archive" "$output_dir/$archive_name"

printf 'Built %s\n' "$output_dir/$archive_name"
printf 'Commit %s\n' "$commit"
printf 'SHA-256 %s\n' "$archive_sha256"
