FROM --platform=$BUILDPLATFORM python:3.10-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN apt-get update && \
    apt-get install -y wget unzip curl gnupg && \
    if [ "$(uname -m)" = "x86_64" ]; then \
      wget -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
      apt-get install -y /tmp/chrome.deb && \
      rm /tmp/chrome.deb && \
      CHROMEDRIVER_VERSION=$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json" | \
        python3 -c "import sys, json; print(json.load(sys.stdin)['channels']['Stable']['version'])") && \
      wget -O /tmp/chromedriver.zip "https://storage.googleapis.com/chrome-for-testing-public/${CHROMEDRIVER_VERSION}/linux64/chromedriver-linux64.zip" && \
      unzip /tmp/chromedriver.zip -d /usr/bin && \
      mv /usr/bin/chromedriver-linux64/chromedriver /usr/bin/chromedriver && \
      chmod +x /usr/bin/chromedriver && \
      rm -rf /tmp/chromedriver.zip /usr/bin/chromedriver-linux64; \
    elif [ "$(uname -m)" = "aarch64" ]; then \
      wget -O /tmp/chromium.deb "http://ftp.debian.org/debian/pool/main/c/chromium/chromium_137.0.7151.68-1_arm64.deb" && \
      apt-get install -y /tmp/chromium.deb || true && \
      rm /tmp/chromium.deb; \
      # chromedriver는 selenium-manager 사용 \
    fi

COPY . .

RUN mkdir -p /app/logs

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"] 