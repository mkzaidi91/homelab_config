#!/bin/bash
set -euo pipefail

DATE=$(date +%Y%m%d)
STAGE="/home/iso/backup-stage/$DATE"
REMOTE_USER="isobackup"
REMOTE_HOST="192.168.1.100"
REMOTE_PATH="/mnt/Iso/Backup/homelab"
KEEP_DAYS=7
SSH_KEY="/home/iso/.ssh/id_ed25519"
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=accept-new"

mkdir -p "$STAGE"

gpg --batch --yes --passphrase-file /home/iso/.backup-passphrase \
    -c -o "$STAGE/env.gpg" /home/iso/homelab-config/.env

tar -czf "$STAGE/appdata.tar.gz" --exclude='jellyfin/config/data/data/introskipper' \
  -C /home/iso \
  actual-budget/data \
  grafana/data \
  guacamole-init \
  homepage/config \
  homelab-config/homepage \
  influxdb/data influxdb/config \
  jellyfin/config \
  lazylibrarian/config \
  nextcloud/data nextcloud/db \
  npm/data npm/letsencrypt \
  pihole/config pihole/dnsmasq \
  prowlarr/config \
  qbittorrent/config \
  radarr/config \
  jellyseerr/config \
  sonarr/config \
  syncthing/data syncthing/config \
  threadfin/conf \
  uptime-kuma \
  vaultwarden || { ec=$?; [ $ec -eq 1 ] || exit $ec; }

for vol in iso_portainer_data iso_guacamole_postgres_data iso_guacd_drive iso_guacd_record; do
  docker run --rm \
    -v "${vol}:/data:ro" \
    -v "$STAGE:/backup" \
    alpine tar -czf "/backup/${vol}.tar.gz" -C /data .
done

ssh $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${REMOTE_PATH}/${DATE}"
rsync -avz -e "ssh $SSH_OPTS" "$STAGE/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/${DATE}/"

rm -rf "$STAGE"
ssh $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" \
  "find ${REMOTE_PATH} -maxdepth 1 -type d -mtime +${KEEP_DAYS} -exec rm -rf {} +"

echo "Backup complete: $DATE"
