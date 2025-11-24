#!/bin/bash

echo "=================================================="
echo "Azure Deployment Prerequisites Check"
echo "=================================================="
echo ""

# Check Azure CLI
echo "1. Checking Azure CLI..."
if command -v az &> /dev/null; then
    AZ_VERSION=$(az version --output tsv --query '\"azure-cli\"')
    echo "   ✅ Azure CLI installed: $AZ_VERSION"
else
    echo "   ❌ Azure CLI not found"
    echo "   Install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check Docker
echo ""
echo "2. Checking Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo "   ✅ Docker installed: $DOCKER_VERSION"
    
    # Check if Docker is running
    if docker ps &> /dev/null; then
        echo "   ✅ Docker daemon is running"
    else
        echo "   ❌ Docker daemon is not running"
        echo "   Start Docker Desktop or run: sudo systemctl start docker"
        exit 1
    fi
else
    echo "   ❌ Docker not found"
    echo "   Install: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check Azure login
echo ""
echo "3. Checking Azure login..."
if az account show &> /dev/null; then
    ACCOUNT=$(az account show --query name -o tsv)
    SUBSCRIPTION=$(az account show --query id -o tsv)
    echo "   ✅ Logged in to Azure"
    echo "   Account: $ACCOUNT"
    echo "   Subscription: $SUBSCRIPTION"
else
    echo "   ❌ Not logged in to Azure"
    echo "   Run: az login"
    exit 1
fi

# Check Python
echo ""
echo "4. Checking Python..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo "   ✅ Python installed: $PYTHON_VERSION"
else
    echo "   ❌ Python not found"
    exit 1
fi

# Check model files
echo ""
echo "5. Checking model files..."
if [ -f "./models/svm_conversion_model.pkl" ]; then
    echo "   ✅ SVM model found"
else
    echo "   ❌ SVM model not found"
    echo "   Expected: ./models/svm_conversion_model.pkl"
    exit 1
fi

if [ -f "./models/scaler.pkl" ]; then
    echo "   ✅ Scaler found"
else
    echo "   ❌ Scaler not found"
    exit 1
fi

if [ -f "./models/label_encoders.pkl" ]; then
    echo "   ✅ Label encoders found"
else
    echo "   ❌ Label encoders not found"
    exit 1
fi

echo ""
echo "=================================================="
echo "✅ All prerequisites met!"
echo "=================================================="
echo ""
echo "You're ready to deploy to Azure! 🚀"
echo ""
echo "Next step: Run the deployment script"
echo "  cd scripts"
echo "  ./deploy_step1_container.sh"