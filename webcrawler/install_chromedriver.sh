#!/bin/bash
set -e

ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
  echo "ARM64 환경: ARM64용 chromedriver 설치"
  CHROMEDRIVER_VERSION=$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json" | \
    python3 -c "import sys, json; print(json.load(sys.stdin)['channels']['Stable']['version'])")
  wget -O /tmp/chromedriver.zip "https://storage.googleapis.com/chrome-for-testing-public/${CHROMEDRIVER_VERSION}/linux-arm64/chromedriver-linux-arm64.zip"
  unzip /tmp/chromedriver.zip -d /usr/bin
  mv /usr/bin/chromedriver-linux-arm64/chromedriver /usr/bin/chromedriver
  chmod +x /usr/bin/chromedriver
  rm -rf /tmp/chromedriver.zip /usr/bin/chromedriver-linux-arm64
elif [ "$ARCH" = "x86_64" ]; then
  echo "x86_64 환경: x86_64용 chromedriver 설치"
  CHROMEDRIVER_VERSION=$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json" | \
    python3 -c "import sys, json; print(json.load(sys.stdin)['channels']['Stable']['version'])")
  wget -O /tmp/chromedriver.zip "https://storage.googleapis.com/chrome-for-testing-public/${CHROMEDRIVER_VERSION}/linux64/chromedriver-linux64.zip"
  unzip /tmp/chromedriver.zip -d /usr/bin
  mv /usr/bin/chromedriver-linux64/chromedriver /usr/bin/chromedriver
  chmod +x /usr/bin/chromedriver
  rm -rf /tmp/chromedriver.zip /usr/bin/chromedriver-linux64
else
  echo "지원하지 않는 아키텍처: $ARCH"
  exit 1
fi 