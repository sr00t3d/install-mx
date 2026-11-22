[![🇺🇸 English](https://img.shields.io/badge/lang-English-blue.svg)](README.md) [![🇧🇷 Português](https://img.shields.io/badge/lang-Português-green.svg)](README-ptbr.md) [![🇪🇸 Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README-es.md)

# install-mx

![install-mx cover](install-mx-cover.webp)

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/install-mx/releases/tag/v2.0.0)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-orange.svg)](#requirements)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20BIND9%20%7C%20cPanel-lightgrey.svg)](#requirements)

**Safe BIND9 & cPanel MX Provider Installer and Restorer CLI.**

`install-mx.sh` automates switching a domain's MX records on BIND9 / cPanel servers to modern cloud email providers — safely validating the modified zone with `named-checkzone`, bumping the SOA serial automatically, preserving `chmod 600` backups, updating cPanel mail routing (`whmapi1 set_mail_routing`), and offering one-command `--restore`.

> **Historical Inspiration:** Clean-room Bash `v2.0.0` reimplementation inspired by the classic 2012 HostGator Toolbox `install-mx` script. Replaces obsolete providers (Windows Live, legacy GoDaddy, `/etc/init.d/functions`) with 2026 mail providers, strict zone validation, and rollback safety.

---

## Supported Providers

| Provider | Aliases | MX Records Installed |
|---|---|---|
| `google` | `gapps` | `1 smtp.google.com.` (Google Workspace 2023+ recommended) |
| `google-legacy` | — | `1 aspmx.l.google.com.`, `5 alt1/alt2`, `10 alt3/alt4` |
| `microsoft365` | `office365`, `o365`, `m365` | `0 <domain-with-dashes>.mail.protection.outlook.com.` |
| `zoho` | — | `10 mx.zoho.com.`, `20 mx2.zoho.com.`, `50 mx3.zoho.com.` |
| `zoho-eu` | — | `10 mx.zoho.eu.`, `20 mx2.zoho.eu.`, `50 mx3.zoho.eu.` |
| `cloudflare` | — | `10 route1.mx.cloudflare.net.`, `20 route2...`, `30 route3...` |
| `proton` | `protonmail` | `10 mail.protonmail.ch.`, `20 mailsec.protonmail.ch.` |
| `fastmail` | — | `10 in1-smtp.messagingengine.com.`, `20 in2-smtp.messagingengine.com.` |
| `titan` | — | `10 mx1.titan.email.`, `20 mx2.titan.email.` |
| `custom` | — | Custom entries passed via repeatable `--mx-record "<prio> <fqdn.>"` |

---

## Key Features

- **Mandatory `named-checkzone` Validation:** Edits happen in a temporary file first. If BIND9 rejects the zone syntax, the original zone file is never touched and the exact error is printed.
- **RFC-Compliant SOA Serial Bump:** Parses the SOA serial strictly inside the uncommented `SOA` record (never confused by cPanel header timestamps) and bumps it to `YYYYMMDD01` or `current + 1`.
- **Automatic `chmod 600` Backups & `--restore`:** Every live change saves a timestamped backup under `/var/backups/install-mx/` (`0700` dir, `0600` file). `--restore` rolls back the latest snapshot while bumping the SOA serial above the current zone so secondary DNS servers pull the change.
- **cPanel & Generic BIND9 Support:** Defaults to `/var/named/<domain>.db` with optional `whmapi1 set_mail_routing` (`remote` on install, `auto` on restore) and `rndc reload` / `systemctl reload named`. Works on any standalone BIND9 server via `--zone-file`.
- **Automation-Ready:** Supports `--dry-run`, `-o json`, `-q`, and `--no-color`.

---

## Requirements

- Linux with Bash 4.0+ and Python 3
- `named-checkzone` (optional, recommended — part of `bind-utils` / `bind9utils`)
- `rndc` or `systemctl` (for automatic DNS reload) and `whmapi1` (optional, on cPanel/WHM servers)

---

## Usage

```bash
# List all supported providers
./install-mx.sh --list-providers

# Preview Google Workspace MX installation without modifying the zone
./install-mx.sh example.com google --dry-run

# Install Zoho Mail MX records on a cPanel server
./install-mx.sh example.com zoho

# Install Microsoft 365 MX on a custom BIND9 zone file
./install-mx.sh example.com microsoft365 --zone-file /etc/bind/zones/db.example.com --no-routing

# Install custom MX records with JSON output
./install-mx.sh example.com custom \
  --mx-record "10 mx1.custom.net." \
  --mx-record "20 mx2.custom.net." \
  -o json

# Restore the most recent backup (bumping SOA serial)
./install-mx.sh example.com --restore
```

### Options

| Flag | Description |
|---|---|
| `--restore` | Restore the most recent backup for `<domain>` while bumping SOA serial |
| `--list-providers` | List all supported mail providers and their MX records |
| `--mx-record "<prio host>"` | Custom MX record (repeatable, required for `custom`) |
| `--zone-file <path>` | Explicit BIND9 zone file path (default: `/var/named/<domain>.db`) |
| `--backup-dir <path>` | Backup directory (default: `/var/backups/install-mx`) |
| `--no-routing` | Skip `whmapi1 set_mail_routing` update on cPanel |
| `--no-reload` | Skip `rndc reload` / `systemctl reload named` |
| `--dry-run` | Validate and preview changes without modifying the zone file |
| `-o, --output <fmt>` | Output format: `table` (default) or `json` |
| `-q, --quiet` | Suppress header banner |
| `--no-color` | Disable ANSI colors |
| `-V, --version` | Show version and exit |
| `-h, --help` | Show help and exit |

---

## Direct Execution

Run directly without cloning the repository:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sr00t3d/install-mx/main/install-mx.sh) --list-providers
bash <(curl -fsSL https://raw.githubusercontent.com/sr00t3d/install-mx/main/install-mx.sh) example.com google --dry-run
```

---

## Real Output Example

```text
==============================================================================
 install-mx.sh v2.0.0 | BIND9 / cPanel MX Manager | 2026-11-22T01:26:33Z
==============================================================================
[OK] Domain          : example-e2e.com
     Action          : install:zoho
     Zone File       : /tmp/install-mx-e2e/example-e2e.com.db
     named-checkzone : passed
     Backup (0600)   : /tmp/install-mx-bk/example-e2e.com.db.20261122_012633
     cPanel Routing  : skipped
     DNS Reload      : skipped
```

JSON output (`-o json`):

```json
{
  "tool": "install-mx.sh",
  "version": "2.0.0",
  "timestamp": "2026-11-22T01:26:35Z",
  "domain": "example-e2e.com",
  "action": "install:custom",
  "dry_run": false,
  "zone_file": "/tmp/install-mx-e2e/example-e2e.com.db",
  "backup_file": "/tmp/install-mx-bk/example-e2e.com.db.20261122_012635",
  "named_checkzone": "passed",
  "cpanel_routing": "skipped",
  "dns_reload": "skipped"
}
```

---

## Author & License

- **Author:** Percio Castelo — [perciocastelo.com.br](https://perciocastelo.com.br)
- **Project Page:** [perciocastelo.com.br/projetos/en/install-mx.html](https://perciocastelo.com.br/projetos/en/install-mx.html)
- **License:** [Apache-2.0](LICENSE)
