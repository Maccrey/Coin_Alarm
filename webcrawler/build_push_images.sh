#!/bin/bash

# 도커 이미지 빌드 및 푸시 스크립트
# 이 스크립트는 각 서비스의 도커 이미지를 빌드하고 Docker Hub에 푸시합니다.

# 사용법: ./build_push_images.sh [Docker Hub 사용자명]
# 예: ./build_push_images.sh yourusername

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Docker Hub 사용자명
DOCKER_USERNAME=${1:-"yourusername"}

# 이미지 태그 (날짜 기준)
TAG=$(date +%Y%m%d)

# 서비스 목록
SERVICES=("news-crawler" "news-cleaner" "news-writer" "scheduler" "logger")

echo -e "${BLUE}==== 암호화폐 뉴스 크롤링 시스템 도커 이미지 빌드 및 푸시 ====${NC}"
echo -e "${BLUE}Docker Hub 사용자명: ${DOCKER_USERNAME}${NC}"
echo -e "${BLUE}이미지 태그: ${TAG}${NC}"
echo

# 각 서비스별 이미지 빌드 및 푸시
for SERVICE in "${SERVICES[@]}"; do
    echo -e "${GREEN}== ${SERVICE} 이미지 빌드 중... ==${NC}"
    
    # 이미지 빌드
    docker build -t ${DOCKER_USERNAME}/coin-alarm-${SERVICE}:${TAG} ./${SERVICE}
    docker tag ${DOCKER_USERNAME}/coin-alarm-${SERVICE}:${TAG} ${DOCKER_USERNAME}/coin-alarm-${SERVICE}:latest
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}== ${SERVICE} 이미지 빌드 완료 ==${NC}"
        
        # 이미지 푸시
        echo -e "${GREEN}== ${SERVICE} 이미지 Docker Hub에 푸시 중... ==${NC}"
        docker push ${DOCKER_USERNAME}/coin-alarm-${SERVICE}:${TAG}
        docker push ${DOCKER_USERNAME}/coin-alarm-${SERVICE}:latest
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}== ${SERVICE} 이미지 푸시 완료 ==${NC}"
        else
            echo -e "${RED}== ${SERVICE} 이미지 푸시 실패 ==${NC}"
        fi
    else
        echo -e "${RED}== ${SERVICE} 이미지 빌드 실패 ==${NC}"
    fi
    
    echo
done

echo -e "${BLUE}==== 모든 이미지 빌드 및 푸시 완료 ====${NC}"
echo -e "${BLUE}시놀로지에서 사용할 docker-compose.synology.yml 파일을 준비합니다.${NC}"

# 시놀로지용 docker-compose 파일 생성
cat > docker-compose.synology.yml << EOF
version: "3"

services:
  # 뉴스 크롤링 서비스
  news-crawler:
    image: ${DOCKER_USERNAME}/coin-alarm-news-crawler:latest
    container_name: news-crawler
    volumes:
      - ./shared:/app/shared
    environment:
      - PYTHONUNBUFFERED=1
    networks:
      - crawler-network
    restart: unless-stopped

  # 뉴스 정제 서비스
  news-cleaner:
    image: ${DOCKER_USERNAME}/coin-alarm-news-cleaner:latest
    container_name: news-cleaner
    volumes:
      - ./shared:/app/shared
    environment:
      - PYTHONUNBUFFERED=1
    depends_on:
      - news-crawler
    networks:
      - crawler-network
    restart: unless-stopped

  # 뉴스 저장 서비스
  news-writer:
    image: ${DOCKER_USERNAME}/coin-alarm-news-writer:latest
    container_name: news-writer
    volumes:
      - ./shared:/app/shared
    environment:
      - PYTHONUNBUFFERED=1
      - SUPABASE_URL=\${SUPABASE_URL}
      - SUPABASE_API_KEY=\${SUPABASE_API_KEY}
    env_file:
      - ./.env
    depends_on:
      - news-cleaner
    networks:
      - crawler-network
    restart: unless-stopped

  # 스케줄러 서비스
  scheduler:
    image: ${DOCKER_USERNAME}/coin-alarm-scheduler:latest
    container_name: scheduler
    volumes:
      - ./shared:/app/shared
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - PYTHONUNBUFFERED=1
    depends_on:
      - news-crawler
      - news-cleaner
      - news-writer
    networks:
      - crawler-network
    restart: unless-stopped

  # 로깅 서비스
  logger:
    image: ${DOCKER_USERNAME}/coin-alarm-logger:latest
    container_name: logger
    volumes:
      - ./shared:/app/shared
      - ./logs:/app/logs
    ports:
      - "5001:5000"
    environment:
      - PYTHONUNBUFFERED=1
    networks:
      - crawler-network
    restart: unless-stopped

networks:
  crawler-network:
    driver: bridge

volumes:
  shared:
EOF

echo -e "${GREEN}docker-compose.synology.yml 파일이 생성되었습니다.${NC}"
echo -e "${BLUE}시놀로지 설치 방법:${NC}"
echo -e "1. 시놀로지에 Docker 패키지를 설치합니다."
echo -e "2. 다음 디렉토리를 생성합니다: /volume1/docker/coin-alarm-crawler"
echo -e "3. 다음 파일들을 해당 디렉토리에 업로드합니다:"
echo -e "   - docker-compose.synology.yml (파일명을 docker-compose.yml로 변경)"
echo -e "   - .env (SUPABASE_URL과 SUPABASE_API_KEY 설정)"
echo -e "4. 다음 디렉토리를 생성합니다:"
echo -e "   - /volume1/docker/coin-alarm-crawler/shared"
echo -e "   - /volume1/docker/coin-alarm-crawler/logs"
echo -e "5. 시놀로지 Docker 앱에서 이미지를 내려받고 컨테이너를 실행합니다."
echo -e "   또는 SSH로 접속하여 다음 명령어를 실행합니다:"
echo -e "   cd /volume1/docker/coin-alarm-crawler && docker-compose up -d" 