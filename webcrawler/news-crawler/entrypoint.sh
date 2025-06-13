#!/bin/bash
set -e

echo "Entrypoint 스크립트 시작..."
echo "Selenium은 /usr/bin/google-chrome, /usr/bin/chromedriver를 사용합니다."

# chromedriver 및 chrome 설치
bash /app/install_chromedriver.sh

echo "프로그램 실행: $@"
# 인자로 받은 명령 실행
exec "$@"
