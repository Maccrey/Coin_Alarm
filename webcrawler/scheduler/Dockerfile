FROM python:3.9-slim

WORKDIR /app

# 필요한 패키지 설치
RUN apt-get update && apt-get install -y \
    cron \
    gcc \
    python3-dev \
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