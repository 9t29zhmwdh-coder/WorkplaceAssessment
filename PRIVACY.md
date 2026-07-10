# Privacy Policy — WorkplaceAssessment

## Summary

WorkplaceAssessment runs entirely on the machine you execute it on. It never sends data anywhere — not to a server, not to the maintainer, not even to `localhost`.

## What the Script Reads From the Scanned Machine

To produce a report, the script reads (but never modifies):

- Hostname, logged-in username, Windows edition and a **partial** product key (last 5 characters, same as Windows' own activation UI shows)
- Local administrator group membership
- Installed remote-access tools (by matching installed-program names against a known-tool list)
- Pending-reboot and uptime state, disk free space, battery charge/wear, Secure Boot and TPM status
- Autostart registry entries (only entries matching suspicious patterns are recorded, not the full list)

None of this is collected, aggregated, or transmitted by the tool itself. It is written to a local JSON/HTML file and nothing else happens to it.

## What I (the Maintainer) Collect

**Nothing.** There is no telemetry, no analytics, no crash reporting, and no phone-home behavior anywhere in this script. I have no visibility into who runs it, on what machine, or with what results.

## Storage

- Reports are written to `output/` next to the script, as plain JSON and a self-contained HTML file
- No settings, cache, or state are written anywhere else on the system (no registry keys, no `%LOCALAPPDATA%` entries)
- Nothing syncs to the cloud

## Your Responsibility When Using This Tool

Because reports contain machine and account identifiers (see above), you are responsible for handling exported reports according to your own organization's data-handling policies if you use this tool in a work environment. This repository's `.gitignore` excludes the `output/` directory specifically so generated reports are never accidentally committed to a public or shared repository.

## Data Retention

The tool itself retains nothing between runs beyond the report files it writes, which you fully control (move, archive, or delete them as needed).

## Contact

Security issues: see [SECURITY.md](SECURITY.md)

**Last updated: 2026-07-10**
