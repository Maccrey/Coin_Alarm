#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
스케줄러 서비스
- 3시간마다 크롤링/정제/저장 파이프라인 전체 실행
- 각 서비스를 순차적으로 실행하여 end-to-end 파이프라인 구성
"""

import os
import time
import subprocess
import logging
from datetime import datetime
import pytz

# 공유 디렉토리 (항상 절대경로로 고정)
SHARED_DIR = os.path.abspath(os.environ.get('SHARED_DIR', './shared'))
os.makedirs(SHARED_DIR, exist_ok=True)

# 로깅 설정 (SHARED_DIR 기반)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.join(SHARED_DIR, 'scheduler.log'))
    ]
)
logger = logging.getLogger(__name__)

CRAWLER_CMD = ["python3", "webcrawler/news-crawler/crawler.py"]
CLEANER_CMD = ["python3", "webcrawler/news-cleaner/cleaner.py"]
WRITER_CMD = ["python3", "webcrawler/news-writer/writer.py"]


def run_step(cmd, step_name):
    """
    각 단계별 서브프로세스 실행 및 robust 예외 처리
    """
    logger.info(f"[{step_name}] 실행 시작: {cmd}")
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        logger.info(f"[{step_name}] 실행 완료 (stdout):\n{result.stdout}")
        if result.stderr:
            logger.warning(f"[{step_name}] stderr:\n{result.stderr}")
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"[{step_name}] 실행 실패: {e}\nstdout:\n{e.stdout}\nstderr:\n{e.stderr}")
        return False
    except Exception as e:
        logger.error(f"[{step_name}] 예외 발생: {e}")
        return False

def main_loop():
    """
    크롤러 → 클리너 → writer 순차 실행, writer 끝나면 2시간 대기 후 반복
    """
    logger.info("=== 뉴스 파이프라인 순차 실행 스케줄러 시작 ===")
    while True:
        # 1. 크롤러 실행
        if not run_step(CRAWLER_CMD, "크롤러"):  # 실패해도 다음 단계로 진행
            logger.warning("크롤러 단계에서 오류 발생. 다음 단계로 진행합니다.")
        time.sleep(2)
        # 2. 클리너 실행
        if not run_step(CLEANER_CMD, "클리너"):
            logger.warning("클리너 단계에서 오류 발생. 다음 단계로 진행합니다.")
        time.sleep(2)
        # 3. writer 실행
        if not run_step(WRITER_CMD, "writer"):
            logger.warning("writer 단계에서 오류 발생. 다음 반복으로 진행합니다.")
        logger.info("=== 저장 완료. 2시간 대기 후 재시작 ===")
        time.sleep(60 * 60 * 2)  # 2시간 대기

if __name__ == "__main__":
    main_loop() 