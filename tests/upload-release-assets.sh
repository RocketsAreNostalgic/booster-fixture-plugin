#!/usr/bin/env bash

set -euo pipefail

project_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$(mktemp -d "${TMPDIR:-/tmp}/booster-fixture-uploader-test.XXXXXX")
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
mkdir -p "$temporary/bin" "$temporary/state"

cat > "$temporary/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

require_repository() {
	local found=false
	local argument
	for argument in "$@"; do
		if [[ "$found" == true ]]; then
			[[ "$argument" == "$GITHUB_REPOSITORY" ]] || exit 3
			return
		fi
		[[ "$argument" == '--repo' ]] && found=true
	done
	exit 3
}

require_repository "$@"
printf '%s\n' "$*" >> "$FAKE_GH_CALLS"
case "${1:-} ${2:-}" in
	'release view')
		if [[ "$*" == *'.assets[].name'* ]]; then
			if [[ -n "${FAKE_GH_NAMES:-}" ]]; then
				printf '%s\n' "$FAKE_GH_NAMES"
			elif [[ -f "$FAKE_GH_ASSET" ]]; then
				basename "$FAKE_GH_ASSET"
			fi
		elif [[ "$*" == *'.digest'* ]]; then
			if [[ -n "${FAKE_GH_DIGEST:-}" ]]; then
				printf '%s\n' "$FAKE_GH_DIGEST"
			else
				printf 'sha256:%s\n' "$(shasum -a 256 "$FAKE_GH_ASSET" | awk '{ print $1 }')"
			fi
		else
			exit 4
		fi
		;;
	'release upload')
		cp "$4" "$FAKE_GH_ASSET"
		printf 'upload\n' >> "$FAKE_GH_UPLOADS"
		;;
	'release download')
		destination=''
		while [[ $# -gt 0 ]]; do
			if [[ "$1" == '--dir' ]]; then
				destination=$2
				break
			fi
			shift
		done
		[[ -n "$destination" ]] || exit 5
		cp "$FAKE_GH_ASSET" "$destination/$(basename "$FAKE_GH_ASSET")"
		;;
	*)
		exit 2
		;;
esac
EOF
chmod +x "$temporary/bin/gh"

archive="$temporary/booster-fixture-plugin-1.2.3.zip"
export FAKE_GH_ASSET="$temporary/state/$(basename "$archive")"
export FAKE_GH_CALLS="$temporary/state/calls"
export FAKE_GH_UPLOADS="$temporary/state/uploads"
export GITHUB_REPOSITORY='RocketsAreNostalgic/booster-fixture-plugin'
export PATH="$temporary/bin:$PATH"

printf 'first' > "$archive"
bash "$project_root/scripts/upload-release-assets.sh" v1.2.3 "$archive"
cmp "$archive" "$FAKE_GH_ASSET"
bash "$project_root/scripts/upload-release-assets.sh" v1.2.3 "$archive"
[[ $(wc -l < "$FAKE_GH_UPLOADS" | tr -d '[:space:]') == 1 ]]

export FAKE_GH_NAMES='unexpected.json'
if bash "$project_root/scripts/upload-release-assets.sh" v1.2.3 "$archive" 2>/dev/null; then
	printf 'release containing an unexpected asset was accepted.\n' >&2
	exit 1
fi
export FAKE_GH_NAMES=$'booster-fixture-plugin-1.2.3.zip\nbooster-fixture-plugin-1.2.3.zip'
if bash "$project_root/scripts/upload-release-assets.sh" v1.2.3 "$archive" 2>/dev/null; then
	printf 'duplicate release ZIP names were accepted.\n' >&2
	exit 1
fi
unset FAKE_GH_NAMES

printf 'conflict' > "$archive"
if bash "$project_root/scripts/upload-release-assets.sh" v1.2.3 "$archive" 2>/dev/null; then
	printf 'conflicting release ZIP bytes were accepted.\n' >&2
	exit 1
fi
printf 'first' > "$archive"

export FAKE_GH_DIGEST='sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
if bash "$project_root/scripts/upload-release-assets.sh" v1.2.3 "$archive" 2>/dev/null; then
	printf 'conflicting GitHub asset digest was accepted.\n' >&2
	exit 1
fi
unset FAKE_GH_DIGEST

if GITHUB_REPOSITORY='' bash "$project_root/scripts/upload-release-assets.sh" v1.2.3 "$archive" 2>/dev/null; then
	printf 'missing repository binding was accepted.\n' >&2
	exit 1
fi

[[ $(wc -l < "$FAKE_GH_CALLS" | tr -d '[:space:]') -ge 6 ]]
printf 'Release asset uploader characterization passed.\n'
