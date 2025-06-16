FROM python:3.9-slim

WORKDIR /app

# Install build tools for psutil etc.
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc python3-dev curl gpg lsb-release cron && \
    rm -rf /var/lib/apt/lists/*

# Docker CLI 설치
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# 크론 설정 파일 복사 및 권한 설정
COPY crontab /etc/cron.d/news-cron
RUN chmod 0644 /etc/cron.d/news-cron && crontab /etc/cron.d/news-cron

# 스크립트 실행 권한 설정
RUN chmod +x /app/run_crawler.sh

# 크론 서비스 및 로깅 실행
CMD ["bash", "-c", "cron && tail -f /app/shared/scheduler.log"]

CMD ["python", "main.py"] 