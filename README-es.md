[![🇺🇸 English](https://img.shields.io/badge/lang-English-blue.svg)](README.md) [![🇧🇷 Português](https://img.shields.io/badge/lang-Português-green.svg)](README-ptbr.md) [![🇪🇸 Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README-es.md)

# install-mx

[![Versión](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/install-mx/releases/tag/v2.0.0)
[![Licencia](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-orange.svg)](#requisitos)
[![Plataforma](https://img.shields.io/badge/platform-Linux%20%7C%20BIND9%20%7C%20cPanel-lightgrey.svg)](#requisitos)

**CLI segura para instalación y restauración de registros MX en BIND9 y cPanel.**

`install-mx.sh` automatiza el cambio de registros MX de un dominio en servidores BIND9 / cPanel hacia proveedores modernos de correo en la nube — validando la zona modificada con `named-checkzone`, incrementando el serial SOA automáticamente, conservando copias de seguridad `chmod 600`, actualizando el enrutamiento de correo en cPanel (`whmapi1 set_mail_routing`) y ofreciendo restauración en un comando con `--restore`.

> **Inspiración Histórica:** Reimplementación clean-room en Bash `v2.0.0` inspirada en el clásico script `install-mx` (2012, HostGator Toolbox). Sustituye proveedores obsoletos (Windows Live, GoDaddy antiguo, `/etc/init.d/functions`) por proveedores modernos de 2026, validación estricta de zona y rollback seguro.

---

## Proveedores Soportados

| Proveedor | Alias | Registros MX Instalados |
|---|---|---|
| `google` | `gapps` | `1 smtp.google.com.` (Google Workspace recomendado 2023+) |
| `google-legacy` | — | `1 aspmx.l.google.com.`, `5 alt1/alt2`, `10 alt3/alt4` |
| `microsoft365` | `office365`, `o365`, `m365` | `0 <dominio-con-guiones>.mail.protection.outlook.com.` |
| `zoho` | — | `10 mx.zoho.com.`, `20 mx2.zoho.com.`, `50 mx3.zoho.com.` |
| `zoho-eu` | — | `10 mx.zoho.eu.`, `20 mx2.zoho.eu.`, `50 mx3.zoho.eu.` |
| `cloudflare` | — | `10 route1.mx.cloudflare.net.`, `20 route2...`, `30 route3...` |
| `proton` | `protonmail` | `10 mail.protonmail.ch.`, `20 mailsec.protonmail.ch.` |
| `fastmail` | — | `10 in1-smtp.messagingengine.com.`, `20 in2-smtp.messagingengine.com.` |
| `titan` | — | `10 mx1.titan.email.`, `20 mx2.titan.email.` |
| `custom` | — | Entradas personalizadas mediante `--mx-record "<prio> <fqdn.>"` |

---

## Requisitos

- Linux con Bash 4.0+ y Python 3
- `named-checkzone` (opcional, recomendado — paquete `bind-utils` / `bind9utils`)
- `rndc` o `systemctl` (para recarga automática del DNS) y `whmapi1` (opcional en servidores cPanel/WHM)

---

## Uso

```bash
# Listar todos los proveedores soportados
./install-mx.sh --list-providers

# Previsualizar instalación de Google Workspace sin modificar la zona
./install-mx.sh ejemplo.com google --dry-run

# Instalar registros MX de Zoho Mail en un servidor cPanel
./install-mx.sh ejemplo.com zoho

# Instalar Microsoft 365 en un archivo de zona BIND9 personalizado
./install-mx.sh ejemplo.com microsoft365 --zone-file /etc/bind/zones/db.ejemplo.com --no-routing

# Instalar registros MX personalizados con salida JSON
./install-mx.sh ejemplo.com custom \
  --mx-record "10 mx1.custom.net." \
  --mx-record "20 mx2.custom.net." \
  -o json

# Restaurar la copia de seguridad más reciente (incrementando el serial SOA)
./install-mx.sh ejemplo.com --restore
```

---

## Ejecución Directa

Ejecuta directamente sin clonar el repositorio:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sr00t3d/install-mx/main/install-mx.sh) --list-providers
bash <(curl -fsSL https://raw.githubusercontent.com/sr00t3d/install-mx/main/install-mx.sh) ejemplo.com google --dry-run
```

---

## Ejemplo de Salida Real

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

---

## Autor y Licencia

- **Autor:** Percio Castelo — [perciocastelo.com.br](https://perciocastelo.com.br)
- **Página del Proyecto:** [perciocastelo.com.br/projetos/en/install-mx.html](https://perciocastelo.com.br/projetos/en/install-mx.html)
- **Licencia:** [Apache-2.0](LICENSE)
