#!/bin/bash

# Script to check the status of the lab deployment
# This helps verify that all VMs and services are running properly

set -e

echo "=========================================="
echo "Checking Lab Deployment Status"
echo "=========================================="
echo ""

# Check if terraform directory exists
if [ ! -d "terraform" ]; then
    echo "Error: terraform directory not found"
    echo "Please run this script from the project root directory"
    exit 1
fi

cd terraform

# Check if terraform state exists
if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
    echo "Error: No Terraform state found"
    echo "Have you deployed the lab? Run: terraform apply"
    exit 1
fi

echo "[+] Getting deployment information..."
echo ""

# Get outputs
ATTACKER_IP=$(terraform output -raw attacker_public_ip 2>/dev/null || echo "Not found")
ATTACKER_PRIVATE_IP=$(terraform output -raw attacker_private_ip 2>/dev/null || echo "Not found")
WEBSERVER_IP=$(terraform output -raw webserver_private_ip 2>/dev/null || echo "Not found")
SIEM_IP=$(terraform output -raw siem_private_ip 2>/dev/null || echo "Not found")

echo "IP Addresses:"
echo "  Attacker (Public): $ATTACKER_IP"
echo "  Attacker (Private): $ATTACKER_PRIVATE_IP"
echo "  Web Server: $WEBSERVER_IP"
echo "  SIEM: $SIEM_IP"
echo ""

if [ "$ATTACKER_IP" == "Not found" ]; then
    echo "Error: Could not retrieve IP addresses"
    echo "The deployment may have failed"
    exit 1
fi

# Check SSH connectivity to attacker VM
echo "[+] Checking SSH connectivity to Attacker VM..."
if timeout 5 ssh -i ~/.ssh/azure_lab_key -o StrictHostKeyChecking=no -o ConnectTimeout=5 azureuser@"$ATTACKER_IP" "echo 'SSH connection successful'" 2>/dev/null; then
    echo "✓ SSH to Attacker VM: OK"
else
    echo "✗ SSH to Attacker VM: Failed"
    echo "  Note: VMs may still be initializing. Wait 5-10 minutes and try again."
fi
echo ""

# Check if we can SSH and verify services from attacker VM
echo "[+] Checking services from Attacker VM..."

# Function to run command on attacker VM
run_on_attacker() {
    ssh -i ~/.ssh/azure_lab_key -o StrictHostKeyChecking=no -o ConnectTimeout=5 azureuser@"$ATTACKER_IP" "$1" 2>/dev/null
}

# Check if cloud-init is complete on attacker
if run_on_attacker "test -f /var/log/cloud-init-complete && echo 'yes' || echo 'no'" | grep -q "yes"; then
    echo "✓ Attacker VM initialization: Complete"
else
    echo "⏳ Attacker VM initialization: In progress..."
fi

# Check Juice Shop
echo ""
echo "[+] Checking Juice Shop..."
if run_on_attacker "curl -s -o /dev/null -w '%{http_code}' http://$WEBSERVER_IP:3000" | grep -q "200"; then
    echo "✓ Juice Shop (Web Server): Accessible"
else
    echo "✗ Juice Shop (Web Server): Not accessible yet"
fi

# Check Elasticsearch
echo ""
echo "[+] Checking Elasticsearch..."
if run_on_attacker "curl -s -o /dev/null -w '%{http_code}' http://$SIEM_IP:9200" | grep -q "200"; then
    echo "✓ Elasticsearch (SIEM): Running"
    
    # Check for indices
    INDEX_COUNT=$(run_on_attacker "curl -s http://$SIEM_IP:9200/_cat/indices?h=index" | wc -l)
    echo "  Indices found: $INDEX_COUNT"
else
    echo "✗ Elasticsearch (SIEM): Not accessible yet"
fi

# Check Kibana
echo ""
echo "[+] Checking Kibana..."
if run_on_attacker "curl -s -o /dev/null -w '%{http_code}' http://$SIEM_IP:5601/api/status" | grep -q "200"; then
    echo "✓ Kibana (SIEM): Running"
else
    echo "✗ Kibana (SIEM): Not accessible yet"
fi

echo ""
echo "=========================================="
echo "Deployment Check Complete"
echo "=========================================="
echo ""
echo "Access Instructions:"
echo ""
echo "1. SSH to Attacker VM:"
echo "   ssh -i ~/.ssh/azure_lab_key azureuser@$ATTACKER_IP"
echo ""
echo "2. From your local machine, forward Juice Shop:"
echo "   ssh -i ~/.ssh/azure_lab_key -L 3000:$WEBSERVER_IP:3000 azureuser@$ATTACKER_IP"
echo "   Then open: http://localhost:3000"
echo ""
echo "3. From your local machine, forward Kibana:"
echo "   ssh -i ~/.ssh/azure_lab_key -L 5601:$SIEM_IP:5601 azureuser@$ATTACKER_IP"
echo "   Then open: http://localhost:5601"
echo ""
echo "If services are not accessible yet, wait 5-10 minutes for"
echo "VMs to complete initialization, then run this script again."
echo ""
echo "=========================================="