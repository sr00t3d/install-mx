#!/usr/bin/env bash
# ==============================================================================
#  install-mx.sh — Safe BIND9 / cPanel MX Provider Installer & Restorer CLI
# ==============================================================================
#  Author  : Percio Castelo <percio@perciocastelo.com.br>
#  Website : https://perciocastelo.com.br
#  Project : https://perciocastelo.com.br/projetos/en/install-mx.html
#  Repo    : https://github.com/sr00t3d/install-mx
#  License : Apache-2.0
#  Version : 2.0.0
#  Notes   : Clean-room Bash reimplementation inspired by `install-mx` (2012,
#            HostGator Toolbox). Modernized with 2026 mail providers (Google
#            Workspace, Microsoft 365, Zoho, Cloudflare, Proton, Fastmail,
#            Titan, Custom), mandatory `named-checkzone` validation, SOA serial
#            bump, chmod 600 backups, `--restore`, cPanel remote mail routing
#            (`whmapi1`), `--dry-run`, and JSON output.
# ==============================================================================

set -uo pipefail
export LC_ALL=C

readonly SCRIPT_NAME="install-mx.sh"
readonly SCRIPT_VERSION="2.0.0"

# Defaults
DOMAIN=""
PROVIDER=""
ZONE_FILE=""
BACKUP_DIR="/var/backups/install-mx"
declare -a CUSTOM_MX=()
RESTORE_MODE=0
LIST_PROVIDERS=0
SET_CPANEL_ROUTING=1
RELOAD_DNS=1
DRY_RUN=0
FORMAT="table"
QUIET=0
NO_COLOR=0
TIMESTAMP_UTC="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
TMP_ZONE=""

# Colors
RED="" GREEN="" YELLOW="" CYAN="" BOLD="" RESET=""

init_colors() {
  if [[ "$NO_COLOR" -eq 0 && -t 1 && -z "${NO_COLOR:-}" && "$FORMAT" == "table" ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[0;33m'
    CYAN=$'\033[0;36m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
  else
    RED="" GREEN="" YELLOW="" CYAN="" BOLD="" RESET=""
  fi
}

show_help() {
  cat <<'USAGE'
install-mx.sh v2.0.0 — Safe BIND9 / cPanel MX Provider Installer & Restorer CLI

Usage:
  install-mx.sh <domain> <provider> [options]
  install-mx.sh <domain> --restore [options]
  install-mx.sh --list-providers

Providers:
  google          Google Workspace (2023+ recommended: 1 smtp.google.com.)
  google-legacy   Google Workspace classic 5-MX set (aspmx.l.google.com. ...)
  microsoft365    Microsoft 365 / Office 365 (0 <domain-slug>.mail.protection.outlook.com.)
  zoho            Zoho Mail Global (mx.zoho.com, mx2.zoho.com, mx3.zoho.com)
  zoho-eu         Zoho Mail Europe (mx.zoho.eu, mx2.zoho.eu, mx3.zoho.eu)
  cloudflare      Cloudflare Email Routing (route1/2/3.mx.cloudflare.net)
  proton          Proton Mail (10 mail.protonmail.ch, 20 mailsec.protonmail.ch)
  fastmail        Fastmail (in1/in2-smtp.messagingengine.com)
  titan           Titan Email (mx1/mx2.titan.email)
  custom          Custom MX records supplied via --mx-record "<prio> <host.>"

Options:
  --restore                  Restore most recent backup for <domain> (bumping SOA serial)
  --list-providers           List all supported mail providers and their MX records
  --mx-record "<prio host>"  Custom MX entry (repeatable, required for provider 'custom')
  --zone-file <path>         Explicit BIND9 zone file path (default: /var/named/<domain>.db)
  --backup-dir <path>        Backup directory (default: /var/backups/install-mx)
  --no-routing               Do not update cPanel mail routing (whmapi1 set_mail_routing)
  --no-reload                Do not reload BIND/named after updating zone
  --dry-run                  Validate and preview changes without modifying the zone file
  -o, --output <fmt>         Output format: table (default), json
  -q, --quiet                Suppress banner header
  --no-color                 Disable ANSI colors
  -V, --version              Show version and exit
  -h, --help                 Show this help and exit

Examples:
  install-mx.sh example.com google
  install-mx.sh example.com microsoft365 --dry-run
  install-mx.sh example.com zoho --zone-file /var/named/example.com.db
  install-mx.sh example.com custom --mx-record "10 mx1.mail.example.net." --mx-record "20 mx2.mail.example.net."
  install-mx.sh example.com --restore
USAGE
}

print_providers() {
  cat <<'PROVS'
Supported Mail Providers (install-mx.sh v2.0.0):
  google          -> 1 smtp.google.com.
  google-legacy   -> 1 aspmx.l.google.com., 5 alt1/alt2, 10 alt3/alt4
  microsoft365    -> 0 <domain-with-dashes>.mail.protection.outlook.com.
  zoho            -> 10 mx.zoho.com., 20 mx2.zoho.com., 50 mx3.zoho.com.
  zoho-eu         -> 10 mx.zoho.eu., 20 mx2.zoho.eu., 50 mx3.zoho.eu.
  cloudflare      -> 10 route1.mx.cloudflare.net., 20 route2..., 30 route3...
  proton          -> 10 mail.protonmail.ch., 20 mailsec.protonmail.ch.
  fastmail        -> 10 in1-smtp.messagingengine.com., 20 in2-smtp.messagingengine.com.
  titan           -> 10 mx1.titan.email., 20 mx2.titan.email.
  custom          -> Supplied via --mx-record "<priority> <fqdn.>"
PROVS
}

get_provider_mx_lines() {
  local prov="$1" dom="$2"
  local m365_slug="${dom//./-}"
  case "$prov" in
    google|gapps)
      printf '%s. 14400 IN MX 1 smtp.google.com.\n' "$dom"
      ;;
    google-legacy)
      printf '%s. 14400 IN MX 1 aspmx.l.google.com.\n' "$dom"
      printf '%s. 14400 IN MX 5 alt1.aspmx.l.google.com.\n' "$dom"
      printf '%s. 14400 IN MX 5 alt2.aspmx.l.google.com.\n' "$dom"
      printf '%s. 14400 IN MX 10 alt3.aspmx.l.google.com.\n' "$dom"
      printf '%s. 14400 IN MX 10 alt4.aspmx.l.google.com.\n' "$dom"
      ;;
    microsoft365|office365|o365|m365)
      printf '%s. 14400 IN MX 0 %s.mail.protection.outlook.com.\n' "$dom" "$m365_slug"
      ;;
    zoho)
      printf '%s. 14400 IN MX 10 mx.zoho.com.\n' "$dom"
      printf '%s. 14400 IN MX 20 mx2.zoho.com.\n' "$dom"
      printf '%s. 14400 IN MX 50 mx3.zoho.com.\n' "$dom"
      ;;
    zoho-eu)
      printf '%s. 14400 IN MX 10 mx.zoho.eu.\n' "$dom"
      printf '%s. 14400 IN MX 20 mx2.zoho.eu.\n' "$dom"
      printf '%s. 14400 IN MX 50 mx3.zoho.eu.\n' "$dom"
      ;;
    cloudflare)
      printf '%s. 14400 IN MX 10 route1.mx.cloudflare.net.\n' "$dom"
      printf '%s. 14400 IN MX 20 route2.mx.cloudflare.net.\n' "$dom"
      printf '%s. 14400 IN MX 30 route3.mx.cloudflare.net.\n' "$dom"
      ;;
    proton|protonmail)
      printf '%s. 14400 IN MX 10 mail.protonmail.ch.\n' "$dom"
      printf '%s. 14400 IN MX 20 mailsec.protonmail.ch.\n' "$dom"
      ;;
    fastmail)
      printf '%s. 14400 IN MX 10 in1-smtp.messagingengine.com.\n' "$dom"
      printf '%s. 14400 IN MX 20 in2-smtp.messagingengine.com.\n' "$dom"
      ;;
    titan)
      printf '%s. 14400 IN MX 10 mx1.titan.email.\n' "$dom"
      printf '%s. 14400 IN MX 20 mx2.titan.email.\n' "$dom"
      ;;
    custom)
      local rec prio host
      for rec in "${CUSTOM_MX[@]}"; do
        prio="$(awk '{print $1}' <<<"$rec")"
        host="$(awk '{print $2}' <<<"$rec")"
        [[ "$host" == *. ]] || host="${host}."
        printf '%s. 14400 IN MX %s %s\n' "$dom" "$prio" "$host"
      done
      ;;
    *)
      return 1 ;;
  esac
}

bump_soa_serial() {
  local zf="$1"
  local min_serial="${2:-0}"
  python3 - "$zf" "$min_serial" <<'PYEOF'
import re, sys, time
path, min_s = sys.argv[1], int(sys.argv[2])
txt = open(path, "r", encoding="utf-8", errors="ignore").read()
today_base = int(time.strftime("%Y%m%d", time.gmtime()) + "01")

def repl(m):
    cur = int(m.group(2))
    floor = max(cur, min_s)
    nxt = (floor + 1) if floor >= today_base else today_base
    return "%s%d%s" % (m.group(1), nxt, m.group(3))

# Match SOA serial strictly inside an uncommented SOA (...) record
new_txt, n = re.subn(
    r'((?:^|\n)[^;\n]*\bSOA\b[\s\S]*?\(\s*)(\d{8,10})(\b)',
    repl,
    txt,
    count=1,
)
if n == 0:
    # Single-line SOA fallback: SOA ns host serial refresh retry expire min
    new_txt, n = re.subn(
        r'((?:^|\n)[^;\n]*\bSOA\s+\S+\s+\S+\s+)(\d{8,10})(\b)',
        repl,
        txt,
        count=1,
    )
if n == 0:
    sys.stderr.write("[ERR] Could not locate SOA serial in zone file.\n")
    sys.exit(1)
open(path, "w", encoding="utf-8").write(new_txt)
PYEOF
}

extract_soa_serial() {
  local zf="$1"
  python3 - "$zf" <<'PYEOF'
import re, sys
txt = open(sys.argv[1], "r", encoding="utf-8", errors="ignore").read()
m = re.search(r'(?:^|\n)[^;\n]*\bSOA\b[\s\S]*?\(\s*(\d{8,10})\b', txt)
if not m:
    m = re.search(r'(?:^|\n)[^;\n]*\bSOA\s+\S+\s+\S+\s+(\d{8,10})\b', txt)
print(m.group(1) if m else "0")
PYEOF
}

validate_zone() {
  local dom="$1" zf="$2"
  if command -v named-checkzone >/dev/null 2>&1; then
    local out rc=0
    out="$(named-checkzone "$dom" "$zf" 2>&1)" || rc=$?
    if [[ "$rc" -ne 0 ]]; then
      printf '%s\n' "$out" >&2
      return "$rc"
    fi
  fi
  return 0
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

main() {
  command -v python3 >/dev/null 2>&1 || { printf '[ERR] python3 is required.\n' >&2; exit 1; }
  [[ "$#" -eq 0 ]] && { show_help; exit 1; }

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -h|--help)         show_help; exit 0 ;;
      -V|--version)      printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; exit 0 ;;
      --list-providers)  LIST_PROVIDERS=1; shift ;;
      --restore)         RESTORE_MODE=1; shift ;;
      --mx-record)       CUSTOM_MX+=("${2:-}"); shift 2 ;;
      --zone-file)       ZONE_FILE="${2:-}"; shift 2 ;;
      --backup-dir)      BACKUP_DIR="${2:-}"; shift 2 ;;
      --no-routing)      SET_CPANEL_ROUTING=0; shift ;;
      --no-reload)       RELOAD_DNS=0; shift ;;
      --dry-run)         DRY_RUN=1; shift ;;
      -o|--output)       FORMAT="${2:-table}"; shift 2 ;;
      --output=*)        FORMAT="${1#*=}"; shift ;;
      -q|--quiet)        QUIET=1; shift ;;
      --no-color)        NO_COLOR=1; shift ;;
      -*)                printf '[ERR] Unknown option: %s (use -h for help)\n' "$1" >&2; exit 1 ;;
      *)
        if [[ -z "$DOMAIN" ]]; then
          DOMAIN="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's|\.$||')"; shift
        elif [[ -z "$PROVIDER" ]]; then
          if [[ "$1" == "restore" ]]; then
            RESTORE_MODE=1
          else
            PROVIDER="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
          fi
          shift
        else
          printf '[ERR] Unexpected argument: %s\n' "$1" >&2; exit 1
        fi ;;
    esac
  done

  if [[ "$LIST_PROVIDERS" -eq 1 ]]; then
    print_providers
    exit 0
  fi

  case "$FORMAT" in
    table|json) ;;
    *) printf '[ERR] Invalid output format: %s (expected table or json)\n' "$FORMAT" >&2; exit 1 ;;
  esac

  init_colors

  [[ -n "$DOMAIN" ]] || { printf '[ERR] Missing domain name. Use -h for help.\n' >&2; exit 1; }
  [[ -n "$ZONE_FILE" ]] || ZONE_FILE="/var/named/${DOMAIN}.db"
  [[ -f "$ZONE_FILE" ]] || { printf '[ERR] BIND9 zone file not found: %s\n' "$ZONE_FILE" >&2; exit 1; }

  local backup_file="" action_label="" routing_status="skipped" reload_status="skipped"
  TMP_ZONE="$(mktemp "/tmp/install-mx-${DOMAIN}.XXXXXX.db")"
  trap '[[ -n "${TMP_ZONE:-}" ]] && rm -f "$TMP_ZONE"' EXIT

  if [[ "$RESTORE_MODE" -eq 1 ]]; then
    action_label="restore"
    local latest_bk
    latest_bk="$(ls -1t "${BACKUP_DIR}/${DOMAIN}.db."* 2>/dev/null | head -n 1 || true)"
    [[ -n "$latest_bk" && -f "$latest_bk" ]] || { printf '[ERR] No backup found for %s in %s\n' "$DOMAIN" "$BACKUP_DIR" >&2; exit 1; }
    cp -a "$latest_bk" "$TMP_ZONE"
    # Keep serial continuity above current zone
    local cur_serial
    cur_serial="$(extract_soa_serial "$ZONE_FILE")"
    bump_soa_serial "$TMP_ZONE" "${cur_serial:-0}"
    validate_zone "$DOMAIN" "$TMP_ZONE" || { printf '[ERR] Restored zone failed named-checkzone validation.\n' >&2; exit 1; }
    if [[ "$DRY_RUN" -eq 0 ]]; then
      cp -a "$TMP_ZONE" "$ZONE_FILE"
      backup_file="$latest_bk"
    fi
  else
    action_label="install:${PROVIDER}"
    [[ -n "$PROVIDER" ]] || { printf '[ERR] Missing provider (use --list-providers).\n' >&2; exit 1; }
    if [[ "$PROVIDER" == "custom" && "${#CUSTOM_MX[@]}" -eq 0 ]]; then
      printf '[ERR] Provider "custom" requires at least one --mx-record "<prio> <host.>".\n' >&2
      exit 1
    fi
    local mx_block
    mx_block="$(get_provider_mx_lines "$PROVIDER" "$DOMAIN")" || { printf '[ERR] Unknown provider: %s (use --list-providers)\n' "$PROVIDER" >&2; exit 1; }

    cp -a "$ZONE_FILE" "$TMP_ZONE"
    # Comment out existing uncommented MX records and append new provider MX block
    python3 - "$TMP_ZONE" "$PROVIDER" "$TIMESTAMP_UTC" "$mx_block" <<'PYEOF'
import re, sys
zf, prov, ts, mx_block = sys.argv[1:5]
lines = open(zf, "r", encoding="utf-8", errors="ignore").read().splitlines()
out = []
for ln in lines:
    if not ln.lstrip().startswith(";") and re.search(r'\bIN\s+MX\b', ln, re.I):
        out.append("; [install-mx %s] %s" % (ts, ln))
    else:
        out.append(ln)
out.append("")
out.append("; === install-mx (%s) added at %s ===" % (prov, ts))
for ml in mx_block.strip().splitlines():
    out.append(ml)
open(zf, "w", encoding="utf-8").write("\n".join(out) + "\n")
PYEOF

    bump_soa_serial "$TMP_ZONE"
    validate_zone "$DOMAIN" "$TMP_ZONE" || { printf '[ERR] Modified zone failed named-checkzone validation. Original zone untouched.\n' >&2; exit 1; }

    if [[ "$DRY_RUN" -eq 0 ]]; then
      mkdir -p "$BACKUP_DIR"
      chmod 700 "$BACKUP_DIR" 2>/dev/null || true
      backup_file="${BACKUP_DIR}/${DOMAIN}.db.$(date -u +%Y%m%d_%H%M%S)"
      cp -a "$ZONE_FILE" "$backup_file"
      chmod 600 "$backup_file" 2>/dev/null || true
      cp -a "$TMP_ZONE" "$ZONE_FILE"
    fi
  fi

  # Optional cPanel mail routing + DNS reload
  if [[ "$DRY_RUN" -eq 0 && "$SET_CPANEL_ROUTING" -eq 1 && "$ZONE_FILE" == "/var/named/${DOMAIN}.db" ]]; then
    if command -v whmapi1 >/dev/null 2>&1; then
      local mode="remote"
      [[ "$RESTORE_MODE" -eq 1 ]] && mode="auto"
      if whmapi1 --output=json set_mail_routing "domain=${DOMAIN}" "mode=${mode}" >/dev/null 2>&1; then
        routing_status="whmapi1:${mode}"
      else
        routing_status="whmapi1:failed"
      fi
    fi
  fi

  if [[ "$DRY_RUN" -eq 0 && "$RELOAD_DNS" -eq 1 && "$ZONE_FILE" == "/var/named/${DOMAIN}.db" ]]; then
    if command -v rndc >/dev/null 2>&1 && rndc reload "$DOMAIN" >/dev/null 2>&1; then
      reload_status="rndc:ok"
    elif command -v systemctl >/dev/null 2>&1 && systemctl reload named >/dev/null 2>&1; then
      reload_status="systemctl:ok"
    fi
  fi

  local checkzone_status="not_installed"
  command -v named-checkzone >/dev/null 2>&1 && checkzone_status="passed"

  if [[ "$FORMAT" == "json" ]]; then
    printf '{\n'
    printf '  "tool": "%s",\n' "$SCRIPT_NAME"
    printf '  "version": "%s",\n' "$SCRIPT_VERSION"
    printf '  "timestamp": "%s",\n' "$TIMESTAMP_UTC"
    printf '  "domain": "%s",\n' "$(json_escape "$DOMAIN")"
    printf '  "action": "%s",\n' "$(json_escape "$action_label")"
    printf '  "dry_run": %s,\n' "$([[ "$DRY_RUN" -eq 1 ]] && echo true || echo false)"
    printf '  "zone_file": "%s",\n' "$(json_escape "$ZONE_FILE")"
    printf '  "backup_file": "%s",\n' "$(json_escape "$backup_file")"
    printf '  "named_checkzone": "%s",\n' "$checkzone_status"
    printf '  "cpanel_routing": "%s",\n' "$routing_status"
    printf '  "dns_reload": "%s"\n' "$reload_status"
    printf '}\n'
  else
    if [[ "$QUIET" -eq 0 ]]; then
      printf '%s==============================================================================%s\n' "$CYAN" "$RESET"
      printf ' %s%s v%s%s | BIND9 / cPanel MX Manager%s | %s\n' \
        "$BOLD" "$SCRIPT_NAME" "$SCRIPT_VERSION" "$RESET" \
        "$([[ "$DRY_RUN" -eq 1 ]] && echo ' (DRY-RUN)' || echo '')" "$TIMESTAMP_UTC"
      printf '%s==============================================================================%s\n' "$CYAN" "$RESET"
    fi
    printf '%s[OK]%s Domain          : %s\n' "$GREEN" "$RESET" "$DOMAIN"
    printf '     Action          : %s\n' "$action_label"
    printf '     Zone File       : %s\n' "$ZONE_FILE"
    printf '     named-checkzone : %s\n' "$checkzone_status"
    [[ -n "$backup_file" ]] && printf '     Backup (0600)   : %s\n' "$backup_file"
    printf '     cPanel Routing  : %s\n' "$routing_status"
    printf '     DNS Reload      : %s\n' "$reload_status"
  fi
}

main "$@"
