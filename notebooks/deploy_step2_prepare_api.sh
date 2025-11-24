#!/bin/bash

echo "=================================================="
echo "STEP 2: Prepare API with Your SVM Model"
echo "=================================================="
echo ""

# Load configuration
if [ ! -f "./azure-config.env" ]; then
    echo " Configuration file not found!"
    exit 1
fi

source ./azure-config.env
echo "✓ Configuration loaded"
echo ""

# Create project structure
echo " Creating project structure..."
mkdir -p azure-svm-api/{models,src}

# Copy model files
echo ""
echo " Copying your SVM model files..."
cp ./models/svm_conversion_model.pkl azure-svm-api/models/
cp ./models/scaler.pkl azure-svm-api/models/
cp ./models/label_encoders.pkl azure-svm-api/models/
cp ./models/feature_columns.json azure-svm-api/models/
cp ./models/model_metadata.json azure-svm-api/models/

echo "  ✓ All model files copied"

# Create Flask API
echo ""
echo "🔧 Creating Flask API..."
cat > azure-svm-api/src/app.py << 'EOFPY'
from flask import Flask, request, jsonify
import pandas as pd
import numpy as np
import joblib
import json
import os
from io import StringIO

app = Flask(__name__)

MODEL_DIR = os.environ.get('MODEL_DIR', '/app/models')

print(f"Loading models from {MODEL_DIR}...")
model = joblib.load(os.path.join(MODEL_DIR, 'svm_conversion_model.pkl'))
scaler = joblib.load(os.path.join(MODEL_DIR, 'scaler.pkl'))
label_encoders = joblib.load(os.path.join(MODEL_DIR, 'label_encoders.pkl'))

with open(os.path.join(MODEL_DIR, 'feature_columns.json'), 'r') as f:
    feature_columns = json.load(f)

print(f"✓ Model loaded successfully!")

def preprocess_input(data):
    df = pd.DataFrame(data)
    for col in ['CustomerID', 'AdvertisingPlatform', 'AdvertisingTool', 'Conversion']:
        if col in df.columns:
            df = df.drop([col], axis=1)
    for col, encoder in label_encoders.items():
        if col in df.columns:
            df[col] = df[col].map(lambda x: encoder.transform([x])[0] if x in encoder.classes_ else -1)
    df = df[feature_columns]
    return df

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'model': 'SVM', 'features': len(feature_columns)}), 200

@app.route('/predict', methods=['POST'])
def predict():
    try:
        if 'csv_data' in request.json:
            csv_string = request.json['csv_data']
            df = pd.read_csv(StringIO(csv_string))
            data = df.to_dict('records')
        else:
            data = request.json
            if not isinstance(data, list):
                data = [data]
        
        X = preprocess_input(data)
        X_scaled = scaler.transform(X)
        predictions = model.predict(X_scaled)
        probabilities = model.predict_proba(X_scaled)
        
        results = []
        for i, (pred, prob) in enumerate(zip(predictions, probabilities)):
            results.append({
                'record_id': i,
                'prediction': int(pred),
                'prediction_label': 'Will Convert' if pred == 1 else 'Will Not Convert',
                'probability_conversion': float(prob[1]),
                'confidence': float(max(prob))
            })
        
        total = len(results)
        conversions = sum(1 for r in results if r['prediction'] == 1)
        
        return jsonify({
            'success': True,
            'predictions': results,
            'summary': {
                'total_records': total,
                'predicted_conversions': conversions,
                'conversion_rate': conversions / total if total > 0 else 0
            }
        }), 200
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 400

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8000))
    app.run(host='0.0.0.0', port=port, debug=False)
EOFPY

echo "  ✓ Flask API created"

# Create requirements.txt
cat > azure-svm-api/requirements.txt << 'EOFREQ'
flask==3.0.0
pandas==2.1.4
numpy==1.26.2
scikit-learn==1.3.2
joblib==1.3.2
gunicorn==21.2.0
EOFREQ

# Create Dockerfile
cat > azure-svm-api/Dockerfile << 'EOFDOCKER'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY models/ /app/models/
COPY src/ /app/

EXPOSE 8000

ENV MODEL_DIR=/app/models
ENV PORT=8000

CMD ["python", "app.py"]
EOFDOCKER

echo "  ✓ Dockerfile created"

echo ""
echo "=================================================="
echo " Step 2 Complete!"
echo "=================================================="
echo ""
echo "API prepared in: azure-svm-api/"
echo ""
echo "Ready for Step 3: Deploy to Azure!"
