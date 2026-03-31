#!/bin/bash
# Custom entrypoint for Jenkins inbound agent: optional hosts overlay, AWS creds from EFS, then start agent.
# EFS is mounted at /var/jenkins_home. JNLP args are passed from ECS task definition (command).
set -e

echo "Starting Jenkins agent entrypoint as user: $(whoami)"

# Optional: overlay hosts from EFS (e.g. for controller DNS in same VPC)
if [[ -f /var/jenkins_home/etc/hosts ]]; then
  echo "Appending /var/jenkins_home/etc/hosts to /etc/hosts..."
  cat /var/jenkins_home/etc/hosts >> /etc/hosts
fi

# AWS credentials: copy from EFS if present (used by agent for ECS/ECR, etc.)
mkdir -p /home/jenkins/.aws
if [[ -f /var/jenkins_home/etc/aws/config && -f /var/jenkins_home/etc/aws/credentials ]]; then
  echo "Copying AWS config/credentials from EFS to /home/jenkins/.aws..."
  cp /var/jenkins_home/etc/aws/config /home/jenkins/.aws/config
  cp /var/jenkins_home/etc/aws/credentials /home/jenkins/.aws/credentials
fi
chown -R jenkins:jenkins /home/jenkins/.aws

echo "Starting Jenkins agent (JNLP)..."
exec gosu jenkins /usr/local/bin/jenkins-agent "$@"