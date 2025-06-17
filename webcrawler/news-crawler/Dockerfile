FROM python:3.10-slim

WORKDIR /app

# Install system dependencies for playwright and other packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc python3-dev wget unzip curl && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    playwright install --with-deps

COPY crawler.py .

CMD ["python", "crawler.py"]