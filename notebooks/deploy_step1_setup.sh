#!/bin/bash

echo "=================================================="
echo "STEP 1: Setup Azure Project Structure"
echo "=================================================="
echo ""

# Configuration
echo " Configuration Variables:"
echo ""
echo "Please choose UNIQUE names (globally unique across Azure):"
echo ""
read -p "Resource Group Name (e.g., marketing-ml-rg): " RESOURCE_GROUP
read -p "Container Registry Name (lowercase, no spaces, e.g., elyamine-acr): " CONTAINER_REGISTRY
read -p "Storage Account Name (lowercase, no spaces, e.g., elyaminestorage): " STORAGE_ACCOUNT
read -p "Azure Region (e.g., westeurope, eastus): " LOCATION

echo ""
echo "You entered:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Registry: $CONTAINER_REGISTRY"
echo "  Storage: $STORAGE_ACCOUNT"
echo "  Location: $LOCATION"
echo ""
read -p "Is this correct? (y/n): " CONFIRM

if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "Cancelled. Please run again."
    exit 1
fi

# Save configuration
echo ""
echo " Saving configuration..."
cat > ./azure-config.env << EOFCONFIG
RESOURCE_GROUP=$RESOURCE_GROUP
LOCATION=$LOCATION
CONTAINER_REGISTRY=$CONTAINER_REGISTRY
STORAGE_ACCOUNT=$STORAGE_ACCOUNT
CONTAINER_APP=marketing-prediction-api
FUNCTION_APP=${STORAGE_ACCOUNT}function
CONTAINER_APP_ENV=marketing-ml-env
IMAGE_NAME=marketing-conversion-api
IMAGE_TAG=latest
EOFCONFIG

echo "✓ Configuration saved to azure-config.env"

# Create resource group
echo ""
echo " Creating resource group..."
az group create \
    --name $RESOURCE_GROUP \
    --location $LOCATION \
    --output table

echo ""
echo "=================================================="
echo " Step 1 Complete!"
echo "=================================================="
echo ""
echo "Configuration saved. Ready for next step!"
