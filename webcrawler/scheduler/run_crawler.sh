#!/bin/bash

# 뉴스 크롤링 작업 실행 스크립트
# 2시간마다 cron에 의해 실행됨

echo "---------------------------------------------------"
echo "뉴스 크롤링 작업 시작: $(date)"
echo "---------------------------------------------------"

# 각 서비스 상태 체크
echo "서비스 상태 확인 중..."
curl -s http://news-crawler:5000/health || echo "news-crawler 서비스에 연결할 수 없습니다."
curl -s http://news-cleaner:5000/health || echo "news-cleaner 서비스에 연결할 수 없습니다."
curl -s http://news-writer:5000/health || echo "news-writer 서비스에 연결할 수 없습니다."

# 크롤링 작업 트리거
echo "크롤링 작업 시작..."
curl -s -X POST http://news-crawler:5000/api/start-crawling || echo "크롤링 작업 트리거 실패"

echo "---------------------------------------------------"
echo "뉴스 크롤링 작업 완료: $(date)"
echo "---------------------------------------------------" 