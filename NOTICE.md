# NOTICE

This repository packages and redistributes upstream software published by the
[gitleaks](https://github.com/gitleaks/gitleaks) project. The Apache-2.0
license in [`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It
does **not** cover any upstream-derived asset — each package's redistributed
bytes carry their own license, recorded below.

Each package's logo in this repository reproduces the **upstream project's own
mark** at 512 px, unmodified apart from scaling, solely to identify the
software being mirrored. No endorsement or affiliation is implied, and no
trademark right is claimed.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `gitleaks` | `ghcr.io/ocx-contrib/gitleaks/gitleaks` | `MIT` |

---

## `gitleaks`

Upstream: <https://github.com/gitleaks/gitleaks>
Published to `ghcr.io/ocx-contrib/gitleaks/gitleaks`.

| Component | SPDX | Holder |
|---|---|---|
| gitleaks (`gitleaks`) | **MIT** | Copyright (c) 2019 Zachary Rice |

The MIT License grants redistribution of the software in source and binary form
without restriction, on the single condition that the copyright notice and the
permission notice accompany all copies or substantial portions of the software.
That condition is met by construction: upstream's `LICENSE` file ships **inside
every mirrored archive**, at the archive root beside the binary, and is
republished unmodified as part of the bundle content.

The published binaries statically link third-party Go modules under permissive
licenses, enumerated in the `go.mod`/`go.sum` of the tagged upstream source for
each mirrored version.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle.
