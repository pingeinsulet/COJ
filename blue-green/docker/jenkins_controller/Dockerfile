# Use the Jenkins image with JDK 17 as the base image
FROM jenkins/jenkins:jdk21

# Environment variable to skip the Jenkins setup wizard
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

# ARGs for Azure Active Directory (AAD) Integration
ARG CLIENT_ID=your-client-id
ARG CLIENT_SECRET=your-client-secret
ARG TENANT_ID=your-tenant-id
#ARG DATADOG_API_KEY=your-datadog-api-key
#ARG DATA_DOG_API_URL=your-datadog-url

# ENV variables for AAD Integration
ENV CLIENT_ID=${CLIENT_ID} \
    CLIENT_SECRET=${CLIENT_SECRET} \
    TENANT_ID=${TENANT_ID} \
    CASC_JENKINS_CONFIG=/usr/share/jenkins/ref/jenkins.yaml

USER root

# Install necessary packages including git, gosu, and curl (for ECS health check)
RUN apt-get update && apt-get install -y git gosu ca-certificates curl && rm -rf /var/lib/apt/lists/*
RUN apt-get update && apt-get install -y sudo  

# Install Jenkins plugins listed in plugins.txt
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt

# Copy required configuration files to the container
COPY jenkins.yaml /usr/share/jenkins/ref/ 
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Ensure the entrypoint script is executable
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Ensure files and directories are owned by the Jenkins user
RUN sudo chown -R jenkins:jenkins /usr/share/jenkins/ref/jenkins.yaml \
    && sudo chown -R jenkins:jenkins /var/jenkins_home \
    # Replace AAD placeholders in the jenkins.yaml with actual values provided at build time
    && sed -i "s/CLIENT_ID/${CLIENT_ID}/g" /usr/share/jenkins/ref/jenkins.yaml \
    && sed -i "s/CLIENT_SECRET/${CLIENT_SECRET}/g" /usr/share/jenkins/ref/jenkins.yaml \
    && sed -i "s/TENANT_ID/${TENANT_ID}/g" /usr/share/jenkins/ref/jenkins.yaml

# Allow specific directories as safe for Git operations
RUN git config --global --add safe.directory /var/jenkins_home/workspace

# Use the custom entrypoint script
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]