# Booster Fixture Plugin

Disposable public plugin fixture for RAN Booster release-integration tests.
Each published release contains one exact WordPress ZIP for the shared GitHub
Release Updater contract.

## Release contract

The repository-owned builder accepts an immutable Git ref and exact version:

```sh
release_version=0.2.0
bash scripts/build-release.sh "v$release_version" "$release_version"
```

It creates `build/booster-fixture-plugin-<version>.zip`. The ZIP contains
exactly one `booster-fixture-plugin/` root and the three allowlisted runtime
files. GitHub's asset digest and the updater's local re-hash bind its bytes; no
sidecar is published.

Release Please owns version and tag creation. Phase 0 workflow experiments use
only disposable fixture versions and GitHub releases. They must never replace
a conflicting existing asset, write directly to a live WordPress site, or
require a stored personal access token.

The `v0.3.0` fixture exercises packaging in the same workflow that creates the
Release Please tag and release.

The `v0.4.0` fixture exercises packaging in a separate workflow triggered
after the Release Please workflow completes.

The `v0.5.0` fixture confirms the selected direct handoff profile.

The `v0.6.0` fixture confirms its non-persisted checkout credential boundary.
