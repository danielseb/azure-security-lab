#!/bin/bash

# Script to set up Azure Storage backend for Terraform state
# This ensures Terraform state is stored securely in Azure

set -e

echo "=========================================="
echo "Setting up Terraform Azure Backend"
echo "=========================================="

# Generate random string for unique storage account name
RANDOM_STRING=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
RESOURCE_GROUP_NAME="terraform-state-rg"
STORAGE_ACCOUNT_NAME="tfstate${RANDOM_STRING}"
CONTAINER_NAME="tfstate"
LOCATION="uksouth"

echo ""
echo "Configuration:"
echo "  Resource Group: $RESOURCE_GROUP_NAME"
echo "  Storage Account: $STORAGE_ACCOUNT_NAME"
echo "  Container: $CONTAINER_NAME"
echo "  Location: $LOCATION"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI is not installed"
    echo "Please install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in to Azure
echo "[+] Checking Azure login status..."
if ! az account show &> /dev/null; then
    echo "You are not logged in to Azure"
    echo "Running: az login"
    az login
fi

# Get current subscription
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
echo ""
echo "Using subscription:"
echo "  Name: $SUBSCRIPTION_NAME"
echo "  ID: $SUBSCRIPTION_ID"
echo ""

# Create resource group
echo "[+] Creating resource group..."
az group create \
    --name "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --tags "Purpose=Terraform-State" "ManagedBy=Script" \
    || echo "Resource group may already exist"

# Create storage account
echo "[+] Creating storage account..."
az storage account create \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --encryption-services blob \
    --https-only true \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --tags "Purpose=Terraform-State" "ManagedBy=Script"

# Get storage account key
echo "[+] Retrieving storage account key..."
ACCOUNT_KEY=$(az storage account keys list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --query '[0].value' -o tsv)

# Create blob container
echo "[+] Creating blob container..."
az storage container create \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --account-key "$ACCOUNT_KEY" \
    --auth-mode key

# Enable versioning on the storage account
echo "[+] Enabling blob versioning..."
az storage account blob-service-properties update \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --enable-versioning true

echo ""
echo "=========================================="
echo "✓ Backend setup complete!"
echo "=========================================="
echo ""
echo "Add this backend configuration to your main.tf:"
echo ""
echo "terraform {"
echo "  backend \"azurerm\" {"
echo "    resource_group_name  = \"$RESOURCE_GROUP_NAME\""
echo "    storage_account_name = \"$STORAGE_ACCOUNT_NAME\""
echo "    container_name       = \"$CONTAINER_NAME\""
echo "    key                  = \"security-lab.tfstate\""
echo "  }"
echo "}"
echo ""
echo "Backend configuration saved to: backend-config.txt"
echo ""

# Save configuration to file
cat > backend-config.txt << EOF
# Terraform Backend Configuration
# Add this to your main.tf file

terraform {
  backend "azurerm" {
    resource_group_name  = "$RESOURCE_GROUP_NAME"
    storage_account_name = "$STORAGE_ACCOUNT_NAME"
    container_name       = "$CONTAINER_NAME"
    key                  = "security-lab.tfstate"
  }
}
EOF

echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Uncomment the backend block in terraform/main.tf"
echo "2. Update it with the values from backend-config.txt"
echo "3. Run: cd terraform && terraform init"
echo ""
echo "=========================================="