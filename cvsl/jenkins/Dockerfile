# Base Jenkins image
FROM jenkins/jenkins:2.510

ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false
ENV CASC_JENKINS_CONFIG /var/jenkins_home/casc.yaml

# Switch to root to install dependencies
USER root

COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
COPY casc.yaml /var/jenkins_home/casc.yaml

# Install useful tools and curl for downloading CLI
RUN apt-get update && \
    apt-get install -y sudo vim curl wget gnupg2 software-properties-common apt-transport-https ca-certificates dnsutils

# Set root password (for debugging use only)
RUN echo 'root:abc123' | chpasswd

# Allow jenkins user to sudo without password
RUN echo "jenkins ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Add Docker repository and install docker CLI
RUN curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli

# Add docker group and add jenkins user to it
RUN groupadd docker && usermod -aG docker jenkins

# Switch back to Jenkins user
USER jenkins