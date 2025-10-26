#!/bin/bash

# Cloud-init script for Attacker VM
# This script runs on first boot and installs security testing tools

set -e

# Log output
exec > >(tee /var/log/cloud-init-custom.log)
exec 2>&1

echo "=========================================="
echo "Starting Attacker VM initialization"
echo "=========================================="

# Update system
echo "[+] Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install basic tools
echo "[+] Installing basic tools..."
apt-get install -y \
    curl \
    wget \
    git \
    vim \
    net-tools \
    dnsutils \
    traceroute \
    tcpdump \
    wireshark-common \
    python3 \
    python3-pip \
    unzip

# Install security testing tools
echo "[+] Installing security testing tools..."

# Nmap
apt-get install -y nmap

# Nikto
apt-get install -y nikto

# SQLMap
apt-get install -y sqlmap

# Gobuster
apt-get install -y gobuster

# Hydra
apt-get install -y hydra

# Metasploit dependencies
apt-get install -y \
    build-essential \
    libreadline-dev \
    libssl-dev \
    libpq-dev \
    libsqlite3-dev \
    zlib1g-dev \
    autoconf \
    bison \
    libyaml-dev \
    libgdbm-dev \
    libncurses5-dev \
    automake \
    libtool

# Install additional Python tools
echo "[+] Installing Python security tools..."
pip3 install --upgrade pip
pip3 install requests beautifulsoup4 dnspython

# Install wfuzz
apt-get install -y wfuzz

# Install dirb
apt-get install -y dirb

# Install John the Ripper
apt-get install -y john

# Install hashcat
apt-get install -y hashcat

# Install ZAP (OWASP Zed Attack Proxy) - optional but useful
echo "[+] Installing OWASP ZAP..."
wget -q https://github.com/zaproxy/zaproxy/releases/download/v2.14.0/ZAP_2.14.0_Linux.tar.gz -O /tmp/zap.tar.gz
tar -xzf /tmp/zap.tar.gz -C /opt/
ln -s /opt/ZAP_2.14.0/zap.sh /usr/local/bin/zap
rm /tmp/zap.tar.gz

# Create a tools directory
mkdir -p /opt/tools
chown azureuser:azureuser /opt/tools

# Download SecLists (common wordlists for security testing)
echo "[+] Downloading SecLists..."
git clone https://github.com/danielmiessler/SecLists.git /opt/tools/SecLists
chown -R azureuser:azureuser /opt/tools/SecLists

# Create a welcome message
cat > /etc/motd << 'EOF'
========================================
     Attacker VM - Security Lab
========================================

Available Tools:
  - nmap          Network scanner
  - nikto         Web server scanner
  - sqlmap        SQL injection tool
  - gobuster      Directory/file bruster
  - hydra         Password cracker
  - wfuzz         Web fuzzer
  - dirb          Web content scanner
  - john          Password cracker
  - hashcat       Password cracker
  - zap           OWASP ZAP proxy

Resources:
  - SecLists: /opt/tools/SecLists
  - Tools dir: /opt/tools

Network:
  - Web Server: 10.0.2.4:3000 (Juice Shop)
  - SIEM: 10.0.3.4:5601 (Kibana)

Quick Commands:
  nmap -sV 10.0.2.4
  nikto -h http://10.0.2.4:3000
  sqlmap -u "http://10.0.2.4:3000/rest/products/search?q=test" --batch

========================================
EOF

# Enable and start SSH
systemctl enable ssh
systemctl start ssh

# Configure SSH to allow password-less connections within the lab
cat >> /home/azureuser/.ssh/config << EOF
Host 10.0.*
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
EOF
chown azureuser:azureuser /home/azureuser/.ssh/config
chmod 600 /home/azureuser/.ssh/config

# Create a simple script to test connectivity
cat > /home/azureuser/test-lab.sh << 'EOF'
#!/bin/bash
echo "Testing Lab Connectivity..."
echo ""
echo "Testing Web Server (Juice Shop)..."
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://10.0.2.4:3000 || echo "Failed to connect"
echo ""
echo "Testing SIEM (Elasticsearch)..."
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://10.0.3.4:9200 || echo "Failed to connect"
echo ""
echo "Testing SIEM (Kibana)..."
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://10.0.3.4:5601 || echo "Failed to connect"
echo ""
echo "Done!"
EOF
chmod +x /home/azureuser/test-lab.sh
chown azureuser:azureuser /home/azureuser/test-lab.sh

echo "=========================================="
echo "Attacker VM initialization complete!"
echo "=========================================="

# Create a marker file to indicate initialization is complete
touch /var/log/cloud-init-complete