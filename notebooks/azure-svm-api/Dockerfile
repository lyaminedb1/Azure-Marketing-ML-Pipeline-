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
