# Stage 1: Use the official Kaniko image to obtain the executor binary
FROM gcr.io/kaniko-project/executor:latest as kaniko

# Use Jenkins inbound agent as the base image
FROM jenkins/inbound-agent:latest-jdk21

# Switch to root user to install packages
USER root

# Install jq, Git, gosu for user privilege management, curl for downloading files, unzip for extracting files, and gnupg for key management
RUN apt-get update && \
    apt-get install -y jq git gosu curl zip unzip gnupg ca-certificates python3

# Download and install AWS CLI version 2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install

# MongoDB install disabled (repo GPG/SHA1 policy failure in 2026). Re-enable when MongoDB provides updated signing.
# RUN curl -fsSL https://www.mongodb.org/static/pgp/server-6.0.asc | gpg --dearmor | tee /usr/share/keyrings/mongodb.gpg > /dev/null
# RUN echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list
# RUN apt update && apt install mongodb-org -y
# RUN curl -fsSL https://pgp.mongodb.com/server-7.0.asc | gpg --dearmor | tee /usr/share/keyrings/mongodb-server-7.0.gpg > /dev/null
# RUN echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list
# RUN apt update && apt-get install -y mongodb-atlas

# Download and install Terraform
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
RUN echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com jammy main" | tee /etc/apt/sources.list.d/hashicorp.list
# RUN echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg ] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
RUN apt update
RUN apt install -y terraform
# Verify Terraform installation
RUN terraform --version


# Copy the custom entrypoint script into the container and make it executable
COPY jenkins-agent-entrypoint.sh /usr/local/bin/jenkins-agent-entrypoint.sh
RUN chmod +x /usr/local/bin/jenkins-agent-entrypoint.sh

# Set the entrypoint to the custom script, which handles the hosts file and initializes the Jenkins agent
ENTRYPOINT ["/usr/local/bin/jenkins-agent-entrypoint.sh"]