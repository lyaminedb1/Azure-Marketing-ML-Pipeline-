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
