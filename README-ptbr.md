[![🇺🇸 English](https://img.shields.io/badge/lang-English-blue.svg)](README.md) [![🇧🇷 Português](https://img.shields.io/badge/lang-Português-green.svg)](README-ptbr.md) [![🇪🇸 Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README-es.md)

# install-mx

![Capa do install-mx](install-mx-cover.webp)

[![Versão](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/install-mx/releases/tag/v2.0.0)
[![Licença](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-orange.svg)](#requisitos)
[![Plataforma](https://img.shields.io/badge/platform-Linux%20%7C%20BIND9%20%7C%20cPanel-lightgrey.svg)](#requisitos)

**CLI segura para instalação e restauração de registros MX em BIND9 e cPanel.**

O `install-mx.sh` automatiza a troca de registros MX de um domínio em servidores BIND9 / cPanel para provedores modernos de e-mail em nuvem — validando a zona modificada com `named-checkzone`, incrementando o serial SOA automaticamente, preservando backups `chmod 600`, ajustando o roteamento de e-mail no cPanel (`whmapi1 set_mail_routing`) e oferecendo rollback em um comando com `--restore`.

> **Inspiração Histórica:** Reimplementação clean-room em Bash `v2.0.0` inspirada no clássico script `install-mx` (2012, HostGator Toolbox). Substitui provedores obsoletos (Windows Live, GoDaddy antigo, `/etc/init.d/functions`) por provedores modernos de 2026, validação estrita de zona e rollback seguro.

---

## Provedores Suportados

| Provedor | Aliases | Registros MX Instalados |
|---|---|---|
| `google` | `gapps` | `1 smtp.google.com.` (Google Workspace recomendado 2023+) |
| `google-legacy` | — | `1 aspmx.l.google.com.`, `5 alt1/alt2`, `10 alt3/alt4` |
| `microsoft365` | `office365`, `o365`, `m365` | `0 <dominio-com-hifens>.mail.protection.outlook.com.` |
| `zoho` | — | `10 mx.zoho.com.`, `20 mx2.zoho.com.`, `50 mx3.zoho.com.` |
| `zoho-eu` | — | `10 mx.zoho.eu.`, `20 mx2.zoho.eu.`, `50 mx3.zoho.eu.` |
| `cloudflare` | — | `10 route1.mx.cloudflare.net.`, `20 route2...`, `30 route3...` |
| `proton` | `protonmail` | `10 mail.protonmail.ch.`, `20 mailsec.protonmail.ch.` |
| `fastmail` | — | `10 in1-smtp.messagingengine.com.`, `20 in2-smtp.messagingengine.com.` |
| `titan` | — | `10 mx1.titan.email.`, `20 mx2.titan.email.` |
| `custom` | — | Entradas customizadas via `--mx-record "<prio> <fqdn.>"` |

---

## Principais Recursos

- **Validação Obrigatória com `named-checkzone`:** Todas as edições ocorrem primeiro em um arquivo temporário. Se o BIND9 rejeitar a sintaxe da zona, o arquivo original permanece intocado e o erro exato é exibido.
- **Incremento de Serial SOA compatível com RFC:** Localiza o serial estritamente dentro do bloco `SOA` não comentado (sem confundir com timestamps de cabeçalho do cPanel) e incrementa para `YYYYMMDD01` ou `atual + 1`.
- **Backups Automáticos `chmod 600` e `--restore`:** Toda alteração real salva um backup com timestamp em `/var/backups/install-mx/` (diretório `0700`, arquivo `0600`). O `--restore` restaura o último snapshot e incrementa o serial acima da zona atual para garantir propagação aos DNS secundários.
- **Suporte a cPanel e BIND9 Genérico:** Padrão em `/var/named/<dominio>.db` com `whmapi1 set_mail_routing` (`remote` na instalação, `auto` na restauração) e `rndc reload` / `systemctl reload named`. Funciona em qualquer BIND9 via `--zone-file`.
- **Pronto para Automação:** Suporta `--dry-run`, `-o json`, `-q` e `--no-color`.

---

## Requisitos

- Linux com Bash 4.0+ e Python 3
- `named-checkzone` (opcional, recomendado — pacote `bind-utils` / `bind9utils`)
- `rndc` ou `systemctl` (para reload automático do DNS) e `whmapi1` (opcional em servidores cPanel/WHM)

---

## Como Usar

```bash
# Listar todos os provedores suportados
./install-mx.sh --list-providers

# Simular instalação de Google Workspace sem alterar a zona
./install-mx.sh exemplo.com.br google --dry-run

# Instalar MX da Zoho Mail em um servidor cPanel
./install-mx.sh exemplo.com.br zoho

# Instalar Microsoft 365 em um arquivo de zona BIND9 customizado
./install-mx.sh exemplo.com.br microsoft365 --zone-file /etc/bind/zones/db.exemplo.com.br --no-routing

# Instalar registros MX customizados com saída JSON
./install-mx.sh exemplo.com.br custom \
  --mx-record "10 mx1.custom.net." \
  --mx-record "20 mx2.custom.net." \
  -o json

# Restaurar o backup mais recente (incrementando o serial SOA)
./install-mx.sh exemplo.com.br --restore
```

### Opções

| Flag | Descrição |
|---|---|
| `--restore` | Restaura o backup mais recente do `<domínio>` incrementando o serial SOA |
| `--list-providers` | Lista todos os provedores suportados e seus registros MX |
| `--mx-record "<prio host>"` | Registro MX customizado (repetível, obrigatório para `custom`) |
| `--zone-file <caminho>` | Caminho explícito da zona BIND9 (padrão: `/var/named/<domínio>.db`) |
| `--backup-dir <caminho>` | Diretório de backups (padrão: `/var/backups/install-mx`) |
| `--no-routing` | Não atualiza o roteamento de e-mail via `whmapi1 set_mail_routing` |
| `--no-reload` | Não executa `rndc reload` / `systemctl reload named` |
| `--dry-run` | Valida e simula as alterações sem modificar o arquivo de zona |
| `-o, --output <fmt>` | Formato de saída: `table` (padrão) ou `json` |
| `-q, --quiet` | Suprime o banner de cabeçalho |
| `--no-color` | Desativa cores ANSI |
| `-V, --version` | Exibe a versão e encerra |
| `-h, --help` | Exibe a ajuda e encerra |

---

## Execução Direta

Execute diretamente sem clonar o repositório:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sr00t3d/install-mx/main/install-mx.sh) --list-providers
bash <(curl -fsSL https://raw.githubusercontent.com/sr00t3d/install-mx/main/install-mx.sh) exemplo.com.br google --dry-run
```

---

## Exemplo de Saída Real

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

## Autor e Licença

- **Autor:** Percio Castelo — [perciocastelo.com.br](https://perciocastelo.com.br)
- **Página do Projeto:** [perciocastelo.com.br/projetos/br/install-mx.html](https://perciocastelo.com.br/projetos/br/install-mx.html)
- **Licença:** [Apache-2.0](LICENSE)
