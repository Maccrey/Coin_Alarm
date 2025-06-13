#!/bin/bash
set -e

echo "[진단] curl 버전:"
curl --version

echo "[진단] wget 버전:"
wget --version || echo "wget 없음"

echo "[진단] 인증서 파일:"
ls -l /etc/ssl/certs/ca-certificates.crt || ls -l /etc/ssl/cert.pem || echo "인증서 파일 없음"

echo "[진단] 네트워크 상태:"
curl -I https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json || echo "네트워크 연결 실패"

# 크롬/크롬드라이버 설치 (x86_64/mac/win 환경 전용)
echo "크롬/크롬드라이버 설치 스크립트 시작..."
ARCH=$(uname -m)
echo "시스템 아키텍처: $ARCH"

# 고정 버전 (예: 125.0.6422.60, 필요시 수정)
CHROME_VERSION="125.0.6422.60"

if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then
  echo "x86_64 환경: Chrome for Testing 및 ChromeDriver 설치"
  rm -f /usr/bin/chromedriver /usr/bin/google-chrome || true
  rm -rf /opt/chrome-linux64 /opt/chromedriver-linux64 || true

  # Chrome for Testing 다운로드 및 설치
  wget -O /tmp/chrome-linux64.zip "https://storage.googleapis.com/chrome-for-testing-public/$CHROME_VERSION/linux64/chrome-linux64.zip"
  unzip -q /tmp/chrome-linux64.zip -d /opt/
  ln -sf /opt/chrome-linux64/chrome-linux64/chrome /usr/bin/google-chrome

  # ChromeDriver 다운로드 및 설치
  wget -O /tmp/chromedriver-linux64.zip "https://storage.googleapis.com/chrome-for-testing-public/$CHROME_VERSION/linux64/chromedriver-linux64.zip"
  unzip -q /tmp/chromedriver-linux64.zip -d /opt/
  ln -sf /opt/chromedriver-linux64/chromedriver-linux64/chromedriver /usr/bin/chromedriver

  chmod +x /usr/bin/google-chrome /usr/bin/chromedriver
  echo "Chrome/ChromeDriver x86_64 설치 완료"
else
  echo "ARM64(또는 지원하지 않는) 환경입니다. 이 스크립트는 x86_64(mac, win) 환경에서만 동작합니다."
fi 