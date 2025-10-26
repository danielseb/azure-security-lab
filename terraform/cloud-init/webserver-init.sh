#!/bin/bash

# Cloud-init script for Web Server VM
# This script installs Docker and runs OWASP Juice Shop

set -e

# Log output
exec > >(tee /var/log/cloud-init-custom.log)
exec 2>&1

echo "=========================================="
echo "Starting Web Server VM initialization"
echo "=========================================="

# Update system
echo "[+] Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install dependencies
echo "[+] Installing dependencies..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https

# Install Docker
echo "[+] Installing Docker..."
# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add azureuser to docker group
usermod -aG docker azureuser

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Wait for Docker to be ready
sleep 5

# Pull and run OWASP Juice Shop
echo "[+] Pulling OWASP Juice Shop image..."
docker pull bkimminich/juice-shop:latest

echo "[+] Starting OWASP Juice Shop container..."
docker run -d \
    --name juiceshop \
    --restart unless-stopped \
    -p 3000:3000 \
    --log-driver json-file \
    --log-opt max-size=10m \
    --log-opt max-file=3 \
    bkimminich/juice-shop:latest

# Wait for Juice Shop to start
echo "[+] Waiting for Juice Shop to start..."
for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null; then
        echo "[+] Juice Shop is running!"
        break
    fi
    echo "Waiting for Juice Shop to start... ($i/30)"
    sleep 10
done

# Install Filebeat for log shipping to SIEM
echo "[+] Installing Filebeat..."
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-8.x.list
apt-get update
apt-get install -y filebeat

# Configure Filebeat to send Docker logs to Elasticsearch
cat > /etc/filebeat/filebeat.yml << EOF
filebeat.inputs:
- type: container
  paths:
    - '/var/lib/docker/containers/*/*.log'
  processors:
    - add_docker_metadata:
        host: "unix:///var/run/docker.sock"

filebeat.config.modules:
  path: \$${path.config}/modules.d/*.yml
  reload.enabled: false

setup.template.settings:
  index.number_of_shards: 1

setup.kibana:
  host: "${siem_ip}:5601"

output.elasticsearch:
  hosts: ["${siem_ip}:9200"]
  protocol: "http"

processors:
  - add_host_metadata:
      when.not.contains.tags: forwarded
  - add_cloud_metadata: ~
  - add_docker_metadata: ~
EOF

# Enable and start Filebeat
systemctl enable filebeat
systemctl start filebeat

# Create MOTD
cat > /etc/motd << 'EOF'
========================================
   Web Server VM - OWASP Juice Shop
========================================

Services:
  - Juice Shop: http://10.0.2.4:3000
  - Docker: running
  - Filebeat: shipping logs to SIEM

Docker Commands:
  docker ps                  # View running containers
  docker logs juiceshop      # View Juice Shop logs
  docker restart juiceshop   # Restart Juice Shop

Juice Shop is configured to send logs to:
  SIEM: ${siem_ip}:9200

========================================
EOF

# Create a status check script
cat > /home/azureuser/check-status.sh << 'EOF'
#!/bin/bash
echo "=== Web Server Status ==="
echo ""
echo "Docker Status:"
systemctl status docker --no-pager | grep Active
echo ""
echo "Juice Shop Container:"
docker ps --filter name=juiceshop --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "Filebeat Status:"
systemctl status filebeat --no-pager | grep Active
echo ""
echo "Juice Shop Health:"
curl -s http://localhost:3000 > /dev/null && echo "✓ Juice Shop is responding" || echo "✗ Juice Shop is not responding"
EOF
chmod +x /home/azureuser/check-status.sh
chown azureuser:azureuser /home/azureuser/check-status.sh

echo "=========================================="
echo "Web Server VM initialization complete!"
echo "=========================================="
echo "Juice Shop URL: http://10.0.2.4:3000"
echo "=========================================="

# Create marker file
touch /var/log/cloud-init-complete