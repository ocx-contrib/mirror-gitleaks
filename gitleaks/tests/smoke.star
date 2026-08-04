# gitleaks/tests/smoke.star — stable across upstream gitleaks releases.
# Asserts the contract (version shape, a real detection with a counted result,
# and the negative control), never help/version prose. See ocx.mirror
# testing-practices.md.
#
# gitleaks is a secret scanner, so its contract is: given a file containing
# something that matches a built-in rule, produce a finding; given one that
# does not, produce none. Both directions are asserted here, on the MACHINE
# report (`--report-format json`) rather than the human-readable stdout, which
# is colorized and would break a plain-substring assertion token by token.
#
# ⚠ EXIT CODE ALONE PROVES NOTHING, IN EITHER DIRECTION. gitleaks inverts the
# usual polarity — it exits 1 when it FINDS leaks (`--exit-code`, default 1)
# and 0 when the tree is clean — so a binary that scanned nothing would exit 0
# and pass a naive "clean run succeeded" check, while a binary that crashed
# might exit non-zero and pass a naive "leaks were found" check. The finding
# COUNT parsed out of the JSON report is the assertion; the exit codes are
# asserted alongside it, in both directions, as a second independent signal.
#
# The subcommand is `dir` — NOT the pre-8.19 `gitleaks detect --no-git
# --source`, which no longer exists on any version in this mirror's range
# (`gitleaks --help` on 8.29.1 and 8.30.1 lists exactly: completion, dir, git,
# stdin, version).
#
# `dir` is also chosen over `git` on purpose. `gitleaks git` shells out to
# `git log -p` and dies without git on PATH, and none of the three container
# images ships git — so the git verb would need a `containers[].setup:` line
# per leg. The bare Linux `os.features` keys claim the artifact requires
# NOTHING of the host, and `dir` is the path that verifies exactly that claim;
# provisioning git into the legs would make them prove less. Measured on the
# real bundle in stock ubuntu:24.04, alpine:3.20 and fedora:40 — git absent in
# all three, every assertion below green in all three.

GITLEAKS = "gitleaks.exe" if ocx.target_platform.os == ocx.os.Windows else "gitleaks"

# A synthetic AWS access key id: the literal `AKIA` prefix plus 16 uppercase
# alphanumerics, which is what the built-in `aws-access-token` rule matches.
# Not a real credential and not AWS's own documentation example (which the
# default config allowlists).
SECRET = "AKIAZ4TYU7X3QWERTYUI"

# ── Tier 1 + 2: liveness on the composed PATH + version SHAPE ───────────────
# The digits are the contract; the banner around them is not.
r_version = ocx.run(GITLEAKS, "version")
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ── Tier 3: a real detection on hermetic input ──────────────────────────────
ocx.mkdir("dirty")
ocx.write_file("dirty/config.txt", 'aws_access_key_id = "' + SECRET + '"\n')

r_dirty = ocx.run(
    GITLEAKS, "dir", "dirty",
    "--no-banner", "--log-level", "error",
    "--report-format", "json", "--report-path", "dirty.json",
)
# Leaks found => non-zero. Measured 1 on 8.29.1 and 8.30.1.
expect.eq(r_dirty.exit_code, 1)

dirty_report = ocx.read_file("dirty.json")
# THE assertion: exactly one finding. A scanner that reported nothing, or that
# flooded the report, fails here even though its exit code above passed.
expect.eq(dirty_report.count("\"RuleID\""), 1)
# The finding is about the secret we planted, in the file we planted it in,
# attributed to the rule that describes it — so a tool that merely echoed its
# argument, or that reported some unrelated hit, cannot pass.
expect.contains(dirty_report, SECRET)
expect.contains(dirty_report, "config.txt")
expect.contains(dirty_report, "aws-access-token")

# ── Negative control — states what would go red ─────────────────────────────
# A tree with nothing secret-shaped must produce ZERO findings. Without this, a
# hypothetical build whose rules matched everything would pass every assertion
# above.
ocx.mkdir("clean")
ocx.write_file("clean/notes.txt", "hello world\nnothing to see here\n")

r_clean = ocx.run(
    GITLEAKS, "dir", "clean",
    "--no-banner", "--log-level", "error",
    "--report-format", "json", "--report-path", "clean.json",
)
# Clean tree => 0. The inverse of the polarity asserted above.
expect.eq(r_clean.exit_code, 0)

clean_report = ocx.read_file("clean.json")
expect.eq(clean_report.count("\"RuleID\""), 0)
expect.eq(clean_report.strip(), "[]")
