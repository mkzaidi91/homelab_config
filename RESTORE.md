# Disaster Recovery / Restore Procedure

Rebuilds this stack from scratch if the `iso` host is lost. Assumes this git repo is
intact and a recent backup exists on TrueNAS at `/mnt/Iso/Backup/homelab/<DATE>/`.

## What git has vs. the NAS backup

| git | NAS backup |
|---|---|
| `docker-compose.yml` | `.env` (encrypted, env.gpg) |
| `backup.sh` | App config/data (appdata.tar.gz) |
| This file | Named Docker volumes (portainer, guacamole) |

Media libraries (`/mnt/nas/*`) aren't backed up — they live on the NAS directly.

## Steps

1. Provision a fresh Ubuntu host, install Docker + Compose, create the `iso` user.

2. Clone the repo:

        git clone https://github.com/mkzaidi91/homelab_config.git ~/homelab-config
        ln -s ~/homelab-config/docker-compose.yml ~/docker-compose.yml

3. Generate a new SSH key, add its public key to the `isobackup` user on TrueNAS
   (Credentials -> Local Users -> edit isobackup -> SSH Public Key).

   NOTE: the TrueNAS GUI field has been observed to silently strip the `ssh-ed25519`
   prefix/comment from a pasted key. Verify with
   `sudo cat /mnt/Iso/Backup/.ssh/authorized_keys` on the TrueNAS shell; if broken,
   write it directly:

        echo "ssh-ed25519 AAAA...yourkey... comment" | sudo tee /mnt/Iso/Backup/.ssh/authorized_keys
        sudo chown isobackup:homelab_backup /mnt/Iso/Backup/.ssh/authorized_keys
        sudo chmod 600 /mnt/Iso/Backup/.ssh/authorized_keys

   Test:

        ssh isobackup@192.168.1.100 echo ok

4. Pull the latest backup:

        LATEST=$(ssh isobackup@192.168.1.100 "ls -1 /mnt/Iso/Backup/homelab | sort | tail -1")
        mkdir -p ~/restore/$LATEST
        rsync -avz isobackup@192.168.1.100:/mnt/Iso/Backup/homelab/$LATEST/ ~/restore/$LATEST/

5. Restore `.env` (needs the backup passphrase, saved outside this host):

        gpg --batch --yes --passphrase "<your-saved-passphrase>" \
            -o ~/homelab-config/.env -d ~/restore/$LATEST/env.gpg
        chmod 600 ~/homelab-config/.env

6. Restore app config/data:

        sudo tar -xzf ~/restore/$LATEST/appdata.tar.gz -C /home/iso

7. Restore named Docker volumes:

        for vol in iso_portainer_data iso_guacamole_postgres_data iso_guacd_drive iso_guacd_record; do
          docker volume create "$vol"
          docker run --rm -v "${vol}:/data" -v ~/restore/$LATEST:/backup \
            alpine sh -c "tar -xzf /backup/${vol}.tar.gz -C /data"
        done

8. Confirm `/mnt/nas/*` and `/mnt/mediadrive` are mounted correctly on the new host.

9. Start the stack:

        cd ~ && docker compose up -d

10. Spot-check Vaultwarden unlocks, Nextcloud files are present, Pi-hole resolves,
    Sonarr/Radarr/Prowlarr/qBittorrent configs are intact (force-recreate
    Gluetun-dependent containers if they throw socket errors on first start).

## Notes

- Backups run nightly via root's crontab, keeping a 7-day rolling window on the NAS.
- The backup passphrase is NOT in git or on the NAS — keep it in a password manager.
  Losing it makes `.env` backups unrecoverable.
- Periodically test-decrypt `.env.gpg` and spot-check a tarball to confirm backups
  are actually valid.
