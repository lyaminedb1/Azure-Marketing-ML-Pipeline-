#!/bin/bash

echo "=================================================="
echo "STEP 3: Deploy Container to Azure"
echo "=================================================="
echo ""

source ./azure-config.env
echo "✓ Configuration loaded"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Registry: $CONTAINER_REGISTRY"
echo ""

echo " Creating Azure Container Registry..."
echo "This takes 2-3 minutes..."
az acr create \
    --resource-group $RESOURCE_GROUP \
    --name $CONTAINER_REGISTRY \
    --sku Basic \
    --admin-enabled true \
    --location $LOCATION \
    --output table

if [ $? -ne 0 ]; then
    echo " Failed to create registry. The name might be taken."
    echo "Try: elyamine123-acr or elyamineml-acr"
    exit 1
fi

echo "✓ Container registry created"

echo ""
echo " Getting registry credentials..."
ACR_USERNAME=$(az acr credential show --name $CONTAINER_REGISTRY --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name $CONTAINER_REGISTRY --query passwords[0].value -o tsv)
ACR_LOGIN_SERVER=$(az acr show --name $CONTAINER_REGISTRY --query loginServer -o tsv)

echo "✓ Credentials retrieved"

echo ""
echo " Building Docker image..."
echo "This takes 3-5 minutes..."
cd azure-svm-api
docker build -t $IMAGE_NAME:$IMAGE_TAG .

if [ $? -ne 0 ]; then
    echo " Docker build failed"
    exit 1
fi

echo "✓ Docker image built"

echo ""
echo " Pushing image to Azure..."
docker tag $IMAGE_NAME:$IMAGE_TAG $ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG
az acr login --name $CONTAINER_REGISTRY
docker push $ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG

echo "✓ Image pushed"

echo ""
echo " Creating Container Apps environment..."
cd ..
az containerapp env create \
    --name $CONTAINER_APP_ENV \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --output table

echo ""
echo " Deploying Container App..."
az containerapp create \
    --name $CONTAINER_APP \
    --resource-group $RESOURCE_GROUP \
    --environment $CONTAINER_APP_ENV \
    --image $ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG \
    --registry-server $ACR_LOGIN_SERVER \
    --registry-username $ACR_USERNAME \
    --registry-password $ACR_PASSWORD \
    --target-port 8000 \
    --ingress external \
    --cpu 1.0 \
    --memory 2.0Gi \
    --min-replicas 1 \
    --max-replicas 3 \
    --output table

echo ""
echo " Getting API URL..."
APP_URL=$(az containerapp show \
    --name $CONTAINER_APP \
    --resource-group $RESOURCE_GROUP \
    --query properties.configuration.ingress.fqdn -o tsv)

echo "API_ENDPOINT=https://$APP_URL" >> azure-config.env

echo ""
echo "=================================================="
echo " Step 3 Complete!"
echo "=================================================="
echo ""
echo " Your API is live!"
echo ""
echo "API URL: https://$APP_URL"
echo ""
echo "Testing..."
sleep 5
curl -s https://$APP_URL/health | python3 -m json.tool
echo ""
echo ""
echo "Ready for Step 4!"
