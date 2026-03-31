#!/bin/bash
# Custom entrypoint for Jenkins controller: optional hosts overlay, backup dir, then start Jenkins.
# Run as root; exec into jenkins user for jenkins.sh. EFS is mounted at /var/jenkins_home.
set -e

echo "Starting custom entrypoint as user: $(whoami)"

# Optional: overlay hosts from EFS (e.g. for service discovery in same VPC)
if [[ -f /var/jenkins_home/etc/hosts ]]; then
  echo "Appending /var/jenkins_home/etc/hosts to /etc/hosts..."
  cat /var/jenkins_home/etc/hosts >> /etc/hosts
fi

# Ensure backup dir exists on EFS for thinBackup or similar
BACKUP_DIR="/var/jenkins_home/backup"
mkdir -p "$BACKUP_DIR"
chown -R jenkins:jenkins /var/jenkins_home

echo "Starting Jenkins as jenkins user..."
exec gosu jenkins /usr/local/bin/jenkins.sh