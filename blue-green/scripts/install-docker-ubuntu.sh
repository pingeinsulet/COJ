#!/usr/bin/env bash
# Install Docker CE (engine, CLI, containerd, buildx, compose) on Ubuntu using Docker's official APT repo.
# Run from repo root: sudo bash scripts/install-docker-ubuntu.sh
# After install: add your user to the docker group (sudo usermod -aG docker $USER) and log out/in.
set -e

# Must run as root (sudo)
if [[ $(id -u) -ne 0 ]]; then
  echo "Run as root: sudo bash scripts/install-docker-ubuntu.sh" >&2
  exit 1
fi

# Prerequisites
apt-get update
apt-get install -y ca-certificates curl

# Docker GPG key (modern keyrings path)
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Docker APT repository
# Docker only provides packages for certain codenames. For newer Ubuntu (e.g. xia/25.04) use noble (24.04 LTS) repo.
DOCKER_SUPPORTED="jammy noble mantic oracular"
DETECTED=$(lsb_release -cs 2>/dev/null || true)
if [ -z "$DETECTED" ]; then
  echo "Could not detect Ubuntu codename. Using noble (24.04 LTS)."
  CODENAME=noble
elif echo "$DOCKER_SUPPORTED" | grep -q "\b$DETECTED\b"; then
  CODENAME="$DETECTED"
else
  echo "Ubuntu '$DETECTED' has no Docker repo yet; using noble (24.04 LTS) packages."
  CODENAME=noble
fi
echo "Using Docker repo codename: $CODENAME"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" > /etc/apt/sources.list.d/docker.list

# Install
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# On many Ubuntu systems Docker fails to start because it expects iptables-legacy but the default is nftables.
if command -v update-alternatives >/dev/null 2>&1; then
  for alt in iptables ip6tables; do
    legacy="/usr/sbin/${alt}-legacy"
    if [ -x "$legacy" ] && update-alternatives --list "$alt" 2>/dev/null | grep -q legacy; then
      update-alternatives --set "$alt" "$legacy" 2>/dev/null || true
    fi
  done
fi

# Start containerd first, then Docker
systemctl enable containerd
systemctl start containerd
systemctl enable docker
systemctl start docker

echo "Docker installed. Add your user to the docker group to run without sudo:"
echo "  sudo usermod -aG docker \$USER"
echo "Then log out and back in (or run: newgrp docker)"
echo ""
docker --version
docker buildx version
