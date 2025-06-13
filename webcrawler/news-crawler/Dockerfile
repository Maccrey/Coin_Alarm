FROM --platform=$BUILDPLATFORM python:3.10-slim

WORKDIR /app

COPY requirements.txt .
RUN apt-get update && \
    apt-get install -y gcc python3-dev wget unzip curl ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    pip install --no-cache-dir -r requirements.txt && \
    python -m playwright install --with-deps

COPY . .

RUN mkdir -p /app/logs

ENV TZ=Asia/Seoul
RUN ln -snf /usr/share/zoneinfo/Asia/Seoul /etc/localtime && echo "Asia/Seoul" > /etc/timezone

CMD ["python", "crawler.py"]