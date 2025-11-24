#!/bin/bash

echo "=================================================="
echo "STEP 4: Deploy Azure Function"
echo "=================================================="
echo ""

source ./azure-config.env

echo "✓ Configuration loaded"
echo "  API Endpoint: $API_ENDPOINT"
echo ""

echo " Creating storage account..."
az storage account create \
    --name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard_LRS \
    --output table

echo "✓ Storage account created"

echo ""
echo " Getting storage credentials..."
STORAGE_CONNECTION=$(az storage account show-connection-string \
    --name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --query connectionString -o tsv)

STORAGE_KEY=$(az storage account keys list \
    --account-name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --query [0].value -o tsv)

echo "✓ Credentials retrieved"

echo ""
echo " Creating blob containers..."
az storage container create \
    --name input-data \
    --account-name $STORAGE_ACCOUNT \
    --account-key $STORAGE_KEY \
    --output table

az storage container create \
    --name output-results \
    --account-name $STORAGE_ACCOUNT \
    --account-key $STORAGE_KEY \
    --output table

echo "✓ Containers created"

echo ""
echo " Creating Function App files..."
mkdir -p azure-function
cd azure-function

cat > function_app.py << 'EOFPY'
import logging
import azure.functions as func
import requests
import json
import os

API_ENDPOINT = os.environ.get('API_ENDPOINT', '')

app = func.FunctionApp()

@app.blob_trigger(arg_name="myblob", 
                  path="input-data/{name}",
                  connection="AzureWebJobsStorage")
@app.blob_output(arg_name="outputblob",
                 path="output-results/{name}.json",
                 connection="AzureWebJobsStorage")
def BlobTriggerConversionPrediction(myblob: func.InputStream, outputblob: func.Out[str]):
    logging.info(f"Processing: {myblob.name}")
    
    try:
        csv_content = myblob.read().decode('utf-8')
        logging.info(f"CSV read ({len(csv_content)} chars)")
        
        api_url = f"{API_ENDPOINT}/predict"
        logging.info(f"Calling: {api_url}")
        
        response = requests.post(
            api_url,
            json={"csv_data": csv_content},
            headers={"Content-Type": "application/json"},
            timeout=120
        )
        
        response.raise_for_status()
        predictions = response.json()
        
        result = {
            "blob_name": myblob.name,
            "processing_status": "success",
            "predictions": predictions
        }
        
        outputblob.set(json.dumps(result, indent=2))
        
        if 'summary' in predictions:
            s = predictions['summary']
            logging.info(f"✓ Processed {myblob.name}")
            logging.info(f"  Records: {s.get('total_records', 0)}")
            logging.info(f"  Conversions: {s.get('predicted_conversions', 0)}")
        
    except Exception as e:
        logging.error(f"Error: {str(e)}")
        error_result = {
            "blob_name": myblob.name,
            "processing_status": "error",
            "error": str(e)
        }
        outputblob.set(json.dumps(error_result, indent=2))
        raise
EOFPY

cat > host.json << 'EOFJSON'
{
  "version": "2.0",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "maxTelemetryItemsPerSecond": 20
      }
    }
  },
  "extensionBundle": {
    "id": "Microsoft.Azure.Functions.ExtensionBundle",
    "version": "[4.*, 5.0.0)"
  }
}
EOFJSON

cat > requirements.txt << 'EOFREQ'
azure-functions==1.18.0
requests==2.31.0
EOFREQ

echo "✓ Function files created"

echo ""
echo "⚡ Creating Function App..."
cd ..
az functionapp create \
    --resource-group $RESOURCE_GROUP \
    --name $FUNCTION_APP \
    --storage-account $STORAGE_ACCOUNT \
    --consumption-plan-location $LOCATION \
    --runtime python \
    --runtime-version 3.11 \
    --functions-version 4 \
    --os-type Linux \
    --output table

echo "✓ Function App created"

echo ""
echo "⚙️  Configuring settings..."
az functionapp config appsettings set \
    --name $FUNCTION_APP \
    --resource-group $RESOURCE_GROUP \
    --settings \
        "AzureWebJobsStorage=$STORAGE_CONNECTION" \
        "API_ENDPOINT=$API_ENDPOINT" \
    --output table

echo "✓ Settings configured"

echo ""
echo "📦 Deploying function code..."
cd azure-function
func azure functionapp publish $FUNCTION_APP --python

echo ""
echo "=================================================="
echo " Step 4 Complete!"
echo "=================================================="
echo ""
echo "Function App: $FUNCTION_APP"
echo "Storage Account: $STORAGE_ACCOUNT"
echo ""
echo "Containers:"
echo "  • input-data (upload CSV here)"
echo "  • output-results (predictions appear here)"
echo ""
echo "Ready to test!"
