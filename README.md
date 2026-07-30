# Booster Fixture Plugin

Disposable public plugin fixture for RAN Booster release-integration tests.
Each published release contains the exact ZIP and manifest required by the
shared GitHub Release Updater contract.

## Release contract

The repository-owned builder accepts an immutable Git ref and exact version:

```sh
bash scripts/build-release.sh HEAD 0.2.0
```

It creates `build/booster-fixture-plugin-<version>.zip` and the matching JSON
manifest. The manifest `zip_sha256` binds the ZIP; no separate checksum asset
is required. The ZIP contains exactly one `booster-fixture-plugin/` root and
the three allowlisted runtime files.

Release Please owns version and tag creation. Phase 0 workflow experiments use
only disposable fixture versions and GitHub releases. They must never replace
a conflicting existing asset, write directly to a live WordPress site, or
require a stored personal access token.
