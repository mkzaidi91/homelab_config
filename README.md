# Homelab Config

Docker Compose configuration for a self-hosted homelab running 35+ services across media, productivity, monitoring, and security — with all secrets externalized to environment variables and every service tracked under version control.

## Architecture
- **Reverse proxy & tunneling:** Cloudflare Tunnel (Cloudflared) + Nginx Proxy Manager handle external access without exposing ports directly to the internet.
- **Networking:** all services run on a shared Docker bridge network (`homelab_network`); a separate `cloudflare_bridge` network isolates the tunnel.
- **Dashboard:** [Homepage](https://github.com/gethomepage/homepage) provides a unified landing page with live widget stats pulled from each service's API.
- **Secrets:** no credentials are committed to this repo. Every password, token, and API key is referenced via `${VARIABLE}` / `{{HOMEPAGE_VAR_VARIABLE}}` syntax and resolved from a local, gitignored `.env` file at runtime.

## Stack

| Category | Services |
|---|---|
| Infrastructure | Proxmox, Cloudflared, Nginx Proxy Manager, Portainer, Gluetun, Pi-hole |
| Media | Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent, LazyLibrarian, TubeArchivist, Seerr |
| Productivity | Nextcloud, Syncthing, Actual Budget, Guacamole, IT-Tools, Draw.io, Excalidraw, Stirling PDF |
| Monitoring | Netdata, Grafana, InfluxDB, Pulse, Uptime Kuma, Dozzle |
| Security | Vaultwarden, Frigate |
| Management | Watchtower (auto-updates), Portainer (container management) |

## Setup

1. Clone this repo:
```bash
   git clone https://github.com/mkzaidi91/homelab_config.git
   cd homelab_config
```
2. Copy `.env.example` to `.env` and fill in real values for every variable (see below).
3. Bring the stack up:
```bash
   docker compose up -d
```
4. Validate config any time with:
```bash
   docker compose config --quiet
```

## Secrets management

This repo never contains real credentials. Every sensitive value — API keys, database passwords, VPN tokens, tunnel tokens — lives in a local `.env` file that is explicitly gitignored. Compose files reference these via `${VARIABLE_NAME}` substitution, and Homepage's dashboard configs use the equivalent `{{HOMEPAGE_VAR_VARIABLE_NAME}}` syntax with `env_file` passed into the container at runtime.

Before committing any change to a compose or dashboard config file, run:
```bash
grep -i -E "key:|password:|secret:|token:" <changed-file>
```
to confirm nothing sensitive was left inline.

## Notes

- Every service is set to restart automatically (`restart: unless-stopped` or `always`) so the full stack recovers on its own after a host reboot.
- `docker-compose.yml` and the Homepage config files are symlinked from their runtime locations back into this repo, so there is a single source of truth — no manual copy step between "what's running" and "what's tracked."

## License

MIT
