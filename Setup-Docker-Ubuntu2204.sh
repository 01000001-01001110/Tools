#!/bin/bash

# Set log file
LOG_FILE="/var/log/docker_setup.log"

# Create log file and set permissions
sudo touch $LOG_FILE
sudo chmod 666 $LOG_FILE

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

log "Starting Docker and Docker Compose setup."

# Update and upgrade the system
log "Updating and upgrading the system..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y >> $LOG_FILE 2>&1
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y >> $LOG_FILE 2>&1

# Install necessary prerequisites
log "Installing prerequisites..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https ca-certificates curl software-properties-common >> $LOG_FILE 2>&1

# Add Docker’s official GPG key
log "Adding Docker's official GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg >> $LOG_FILE 2>&1

# Set up the stable Docker repository
log "Setting up the Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package database with Docker packages from the newly added repository
log "Updating package database..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y >> $LOG_FILE 2>&1

# Install Docker
log "Installing Docker..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io >> $LOG_FILE 2>&1

# Install Docker Compose
log "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose >> $LOG_FILE 2>&1

# Apply executable permissions to the Docker Compose binary
log "Applying executable permissions to Docker Compose binary..."
sudo chmod +x /usr/local/bin/docker-compose >> $LOG_FILE 2>&1

# Verify the installation
log "Verifying Docker installation..."
docker --version >> $LOG_FILE 2>&1
log "Docker version: $(docker --version)"
log "Verifying Docker Compose installation..."
docker-compose --version >> $LOG_FILE 2>&1
log "Docker Compose version: $(docker-compose --version)"

# Enable Docker to start on boot
log "Enabling Docker to start on boot..."
sudo systemctl enable docker >> $LOG_FILE 2>&1

# Add the current user to the Docker group
log "Adding the current user to the Docker group..."
sudo usermod -aG docker $USER >> $LOG_FILE 2>&1

# Refresh the group membership without logging out and back in
log "Refreshing group membership..."
newgrp docker <<EOF
echo "Docker setup complete!" | tee -a $LOG_FILE
EOF

# Ensure no automatic reboots
log "Configuring the system to not automatically reboot..."
sudo bash -c 'cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "0";
APT::Periodic::Unattended-Upgrade "0";
EOF' >> $LOG_FILE 2>&1

# Print a message indicating the setup is complete
log "Setup complete! No need for user input during the process."

# Print final message
log "System configured to not automatically reboot. Please restart manually when convenient."
