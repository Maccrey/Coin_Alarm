#!/bin/bash
set -e

# chromedriver 설치
/app/install_chromedriver.sh

# supervisord 실행
exec "$@" 