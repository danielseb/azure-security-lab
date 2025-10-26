#!/bin/bash

# Cloud-init script for SIEM VM
# This script installs Elasticsearch and Kibana (lightweight ELK stack)

set -e

# Log output
exec > >(tee /var/log/cloud-init-custom.log)
exec 2>&1

echo "=========================================="
echo "Starting SIEM VM initialization"
echo "=========================================="

# Update system
echo "[+] Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install dependencies
echo "[+] Installing dependencies..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    wget

# Install Java (required for Elasticsearch)
echo "[+] Installing Java..."
apt-get install -y openjdk-11-jdk

# Add Elastic repository
echo "[+] Adding Elastic repository..."
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-8.x.list

# Update package lists
apt-get update

# Install Elasticsearch
echo "[+] Installing Elasticsearch..."
apt-get install -y elasticsearch

# Configure Elasticsearch
echo "[+] Configuring Elasticsearch..."
cat > /etc/elasticsearch/elasticsearch.yml << EOF
cluster.name: security-lab-cluster
node.name: siem-node-1
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
network.host: 10.0.3.4
http.port: 9200
discovery.type: single-node

# Disable security for lab environment (NOT for production!)
xpack.security.enabled: false
xpack.security.enrollment.enabled: false
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false
EOF

# Set JVM heap size (use half of available RAM)
cat > /etc/elasticsearch/jvm.options.d/heap.options << EOF
-Xms2g
-Xmx2g
EOF

# Enable and start Elasticsearch
echo "[+] Starting Elasticsearch..."
systemctl daemon-reload
systemctl enable elasticsearch
systemctl start elasticsearch

# Wait for Elasticsearch to start
echo "[+] Waiting for Elasticsearch to start..."
for i in {1..30}; do
    if curl -s http://localhost:9200 > /dev/null; then
        echo "[+] Elasticsearch is running!"
        break
    fi
    echo "Waiting for Elasticsearch to start... ($i/30)"
    sleep 10
done

# Install Kibana
echo "[+] Installing Kibana..."
apt-get install -y kibana

# Configure Kibana
echo "[+] Configuring Kibana..."
cat > /etc/kibana/kibana.yml << EOF
server.port: 5601
server.host: "10.0.3.4"
elasticsearch.hosts: ["http://10.0.3.4:9200"]
logging.appenders.file.type: file
logging.appenders.file.fileName: /var/log/kibana/kibana.log
logging.appenders.file.layout.type: json
logging.root.appenders: [default, file]
EOF

# Enable and start Kibana
echo "[+] Starting Kibana..."
systemctl daemon-reload
systemctl enable kibana
systemctl start kibana

# Wait for Kibana to start
echo "[+] Waiting for Kibana to start..."
for i in {1..60}; do
    if curl -s http://localhost:5601/api/status > /dev/null 2>&1; then
        echo "[+] Kibana is running!"
        break
    fi
    echo "Waiting for Kibana to start... ($i/60)"
    sleep 10
done

# Create a simple index pattern setup script
cat > /home/azureuser/setup-kibana.sh << 'EOF'
#!/bin/bash
# This script creates a default index pattern in Kibana

echo "Setting up Kibana index pattern..."

# Wait for Kibana to be fully ready
sleep 30

# Create index pattern (filebeat-*)
curl -X POST "http://localhost:5601/api/saved_objects/index-pattern/filebeat-*" \
  -H 'kbn-xsrf: true' \
  -H 'Content-Type: application/json' \
  -d '{
    "attributes": {
      "title": "filebeat-*",
      "timeFieldName": "@timestamp"
    }
  }'

echo ""
echo "Index pattern created!"
echo "You can now view logs in Kibana at http://10.0.3.4:5601"
EOF
chmod +x /home/azureuser/setup-kibana.sh
chown azureuser:azureuser /home/azureuser/setup-kibana.sh

# Run the setup script in the background
su - azureuser -c "/home/azureuser/setup-kibana.sh" &

# Create MOTD
cat > /etc/motd << 'EOF'
========================================
        SIEM VM - ELK Stack
========================================

Services:
  - Elasticsearch: http://10.0.3.4:9200
  - Kibana: http://10.0.3.4:5601

Status Commands:
  sudo systemctl status elasticsearch
  sudo systemctl status kibana

Check Elasticsearch:
  curl http://localhost:9200
  curl http://localhost:9200/_cat/indices?v

Check Kibana:
  curl http://localhost:5601/api/status

View Logs:
  sudo journalctl -u elasticsearch -f
  sudo journalctl -u kibana -f

Elasticsearch Logs:
  /var/log/elasticsearch/

Kibana Logs:
  /var/log/kibana/

Data Directory:
  /var/lib/elasticsearch/

========================================
Access Kibana from your local machine:
  ssh -i ~/.ssh/azure_lab_key -L 5601:10.0.3.4:5601 azureuser@<attacker-ip>
  Then open: http://localhost:5601
========================================
EOF

# Create a status check script
cat > /home/azureuser/check-siem-status.sh << 'EOF'
#!/bin/bash
echo "=== SIEM Status ==="
echo ""
echo "Elasticsearch Status:"
systemctl status elasticsearch --no-pager | grep Active
echo ""
echo "Kibana Status:"
systemctl status kibana --no-pager | grep Active
echo ""
echo "Elasticsearch Health:"
curl -s http://localhost:9200/_cluster/health?pretty
echo ""
echo "Indices:"
curl -s http://localhost:9200/_cat/indices?v
echo ""
echo "Kibana Status:"
curl -s http://localhost:5601/api/status | grep -o '"level":"[^"]*"' || echo "Kibana not ready yet"
EOF
chmod +x /home/azureuser/check-siem-status.sh
chown azureuser:azureuser /home/azureuser/check-siem-status.sh

# Optimize Elasticsearch for lab use
cat > /etc/sysctl.d/99-elasticsearch.conf << EOF
vm.max_map_count=262144
EOF
sysctl -w vm.max_map_count=262144

echo "=========================================="
echo "SIEM VM initialization complete!"
echo "=========================================="
echo "Elasticsearch: http://10.0.3.4:9200"
echo "Kibana: http://10.0.3.4:5601"
echo "=========================================="

# Create marker file
touch /var/log/cloud-init-complete