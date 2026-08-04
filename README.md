# mirror-gitleaks

OCX mirror for [gitleaks](https://github.com/gitleaks/gitleaks), the hardcoded-
secret scanner. One repository, one spec directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [gitleaks](https://github.com/gitleaks/gitleaks) | [`gitleaks/mirror.yml`](gitleaks/mirror.yml) | `ghcr.io/ocx-contrib/gitleaks/gitleaks` | [`ocx.sh/gitleaks/gitleaks`](https://index.ocx.sh/gitleaks/gitleaks) | `MIT` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

The GitHub org is the project's own brand, so the org names the namespace and
the tool names the package: `gitleaks/gitleaks`.

## Layout

```
mirror-base.yml         repo-wide policy every spec inherits via `extends:`
gitleaks/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. Logos are **not** — each
package carries its own, because a repo-root `logo.*` sits in no workflow's
`paths:` filter, so replacing it would publish nothing until some unrelated
edit happened to fire.

⚠️ `extends:` is a **shallow** merge of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it, and
nothing reds — the legs simply stop existing, and every `os.features` claim
goes back to being asserted rather than verified. Restate a block in full or
not at all. `gitleaks/mirror.yml` does not restate it at all, which removes the
trap structurally.

## Platforms

`gitleaks` publishes five platform entries: both Linux arches, both macOS
arches and `windows/amd64`.

Upstream's Linux binaries are Go builds with cgo disabled. That is a claim
until measured, so both declared arches were byte-measured at **both ends** of
the mirrored range, 8.29.1 and 8.30.1: all four are `statically linked`, with
zero `PT_INTERP` and zero `DT_NEEDED`. `os.features` states what an artifact
requires *of the host*, so both Linux keys are **bare** — `+libc.glibc` would
be a false requirement that hid the package from every musl host it in fact
runs on. The `alpine:3.20` container leg on both arches in `mirror-base.yml` is
what turns that claim into evidence; the measurement transcript is recorded
above the `assets:` block in `gitleaks/mirror.yml`.

### Arch tokens, and what is not mirrored

Upstream's asset names use `x64` and `x32`, **not** `amd64`/`386` — and `x32`
here means 32-bit x86, not the x86-64 x32 ABI. Every asset pattern is anchored
at both ends so an `_x64` pattern can never reach `_x32`, `_arm64`, `_armv6` or
`_armv7`.

Upstream also ships `linux_x32`, `linux_armv6`, `linux_armv7`, `windows_x32`
and (through 8.30.0) `windows_armv6`/`windows_armv7`. None of those maps to an
OCX `Architecture` — ocx expresses `amd64` and `arm64` only — so none is
mirrored.

### `windows/arm64` is deliberately excluded

Upstream flipped Windows ARM from an `armv6` + `armv7` pair to a single `arm64`
asset **exactly at v8.30.1**:

| Release | Windows ARM assets |
|---|---|
| v8.29.1 | `windows_armv6.zip`, `windows_armv7.zip` |
| v8.30.0 | `windows_armv6.zip`, `windows_armv7.zip` |
| v8.30.1 | `windows_arm64.zip` |

So `^gitleaks_.*_windows_arm64\.zip$` matches **zero** assets on two of the
three in-range releases — and a declared platform that resolves no asset does
not red. It boots a real `windows-11-arm` runner and reports SUCCESS having
tested nothing. `versions.min` is not lifted to 8.30.1 either: exactly one
release carries the new shape, and lifting the floor would reduce the mirrored
range to a single version. The key is pre-written, commented, in both
`gitleaks/mirror.yml` and `mirror-base.yml`; uncomment both together once a
second release ships `windows_arm64.zip`.

Resolution was verified **both ways on every in-range release** (8.29.1,
8.30.0, 8.30.1): each declared pattern matches exactly one asset, every time,
and every asset name embeds the version of the tag carrying it. A pattern
matching zero would be silently skipped rather than reported, so this check is
not optional.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `gitleaks/mirror.yml` | hand | yes — see below |
| `gitleaks/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `gitleaks/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec gitleaks/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## The binaries claim

`gitleaks/metadata.json` declares `binaries: ["gitleaks"]` by hand, and
`gitleaks/mirror.yml` sets `bin_scan: "off"` — forced, not preferred. The scan
only inspects an interface-visible `${installPath}/<dir>` PATH entry, and
gitleaks' archives are **flat**: `gitleaks(.exe)`, `LICENSE` and `README.md`
sit at the archive root with no subdirectory to point one at. With nothing to
inspect the scan would pass green whatever the archive contained, so `auto` and
`verify` both fail spec load at exit 65 rather than offer a hollow check. The
hand-written list is what the error message itself directs, and it is short and
stable — `gitleaks` is the only mode-0755 entry; the other two are 0644 data.

## The smoke test

A secret scanner's contract is bidirectional: a file containing something
secret-shaped must produce a finding, and a file containing nothing must
produce none. `gitleaks/tests/smoke.star` writes both into the test scratch
sandbox, scans each with `gitleaks dir`, and asserts the finding **count**
parsed from the JSON report — not the colorized human-readable output.

Exit codes are asserted alongside the counts, in both directions, but they are
deliberately not the assertion. gitleaks inverts the usual polarity — it exits
**1** when it finds leaks and **0** when the target is clean — so a binary that
scanned nothing would exit 0 and pass a naive "the clean run succeeded" check,
and a binary that crashed might exit non-zero and pass a naive "leaks were
found" check. The report is also asserted to name the planted secret, the file
it was planted in, and the `aws-access-token` rule, so a tool that merely
echoed its argument could not pass.

The subcommand is `dir`. The pre-8.19 spelling `gitleaks detect --no-git
--source <dir>` no longer exists on any version in this mirror's range.

`dir` is also chosen over `git` deliberately. `gitleaks git` shells out to
`git log -p` and exits 1 without git on `PATH`, and none of `ubuntu:24.04`,
`alpine:3.20` or `fedora:40` ships git — so the git verb would need a
`containers[].setup:` line on every leg. It is not used: the bare Linux
`os.features` keys claim the artifact requires **nothing** of the host, and the
`dir` path is what verifies that claim, so provisioning git into the legs would
make them prove less. The bundle was measured in all three stock images with
git absent — version, one finding on the dirty tree with exit 1, zero findings
on the clean tree with exit 0, in every one. That `gitleaks git` needs git is a
consumer-side fact with no declarable home in the spec (`os.features` carries
libc only); it is recorded in `gitleaks/CATALOG.md`.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; each
package's redistribution license is recorded in [`NOTICE.md`](NOTICE.md). The
logo reproduces upstream's own mark, unmodified apart from scaling, solely to
identify the software being mirrored.
