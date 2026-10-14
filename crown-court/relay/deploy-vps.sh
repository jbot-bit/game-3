#!/usr/bin/env bash
# Run on a NEW Ubuntu server after the operator has approved its cost/account.
# Usage: sudo bash deploy-vps.sh assigned-hostname.bnr.la ADMIN_IPV4
set -euo pipefail
domain=${1:?Supply the server's verified public DNS hostname}
admin_ip=${2:?Supply the operator's current public IPv4 for SSH access}
[[ "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] || { echo 'Invalid DNS hostname'; exit 1; }
[[ "$admin_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo 'Invalid administrator IPv4'; exit 1; }
[[ $(id -u) == 0 ]] || { echo 'Run as root'; exit 1; }
[[ ! -e /opt/crown-court ]] || { echo 'Existing installation found; use an explicit update procedure.'; exit 1; }
source /etc/os-release
[[ "$ID" == ubuntu ]] || { echo 'This installer expects a new Ubuntu server.'; exit 1; }
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
sha256sum --check SHA256SUMS
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y docker.io caddy ufw curl
install -d -m 755 /opt/crown-court/relay
for file in Dockerfile .dockerignore package.json package-lock.json server.mjs THIRD_PARTY_NOTICES.txt; do
    install -m 644 "$file" "/opt/crown-court/relay/$file"
done
systemctl enable --now docker
docker build --pull -t crown-court-relay:family /opt/crown-court/relay
docker run -d --name crown-court-relay --restart unless-stopped \
    --memory 256m --cpus 0.75 --pids-limit 64 \
    --read-only --cap-drop ALL --security-opt no-new-privileges \
    --log-opt max-size=5m --log-opt max-file=2 \
    -p 127.0.0.1:30220:8080 -e TLS_TERMINATED=1 crown-court-relay:family
cat > /etc/caddy/Caddyfile <<EOF
$domain {
    @relay path /rooms /healthz /lobbies
    handle @relay {
        reverse_proxy 127.0.0.1:30220
    }
    handle {
        respond "Crown Court room service" 200
    }
}
EOF
caddy validate --config /etc/caddy/Caddyfile
ufw default deny incoming
ufw default allow outgoing
ufw allow from "$admin_ip" to any port 22 proto tcp comment 'Family game administration'
ufw allow 80/tcp comment 'HTTPS certificate issuance'
ufw allow 443/tcp comment 'Crown Court secure rooms'
ufw --force enable
systemctl enable caddy
systemctl restart caddy
curl --fail --retry 8 --retry-connrefused --retry-delay 2 http://127.0.0.1:30220/healthz
docker image inspect crown-court-relay:family > /opt/crown-court/image-inspect.json
docker inspect crown-court-relay > /opt/crown-court/container-inspect.json
ufw status verbose
printf '\nService prepared. Verify public TLS and game clients at wss://%s/rooms before distribution.\n' "$domain"
