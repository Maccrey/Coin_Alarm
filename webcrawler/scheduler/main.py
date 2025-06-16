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
from datetime import datetime, timedelta
import pytz
import json
import fcntl

# 공유 디렉토리 (항상 절대경로로 고정)
SHARED_DIR = os.path.abspath(os.environ.get('SHARED_DIR', './shared'))
os.makedirs(SHARED_DIR, exist_ok=True)
STATUS_FILE = os.path.join(SHARED_DIR, 'pipeline_status.json')
LOCK_FILE = os.path.join(SHARED_DIR, 'scheduler.lock')

# 로깅 설정 (SHARED_DIR 기반)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.join(SHARED_DIR, 'scheduler.log'))
    ]
)
logger = logging.getLogger('scheduler')

CRAWLER_CMD = ["python3", "webcrawler/news-crawler/crawler.py"]
CLEANER_CMD = ["python3", "webcrawler/news-cleaner/cleaner.py"]
WRITER_CMD = ["python3", "webcrawler/news-writer/writer.py"]


def update_status(status, step=None):
    """파이프라인 상태를 JSON 파일에 robust하게 기록 (3회 재시도, .fail 처리)"""
    now = datetime.now(pytz.timezone('Asia/Seoul'))
    data = {
        'status': status,
        'step': step,
        'timestamp': now.isoformat()
    }
    if status == 'waiting':
        next_run = now + timedelta(hours=4)
        data['next_run'] = next_run.isoformat()
    for attempt in range(1, 4):
        try:
            with open(STATUS_FILE, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            break
        except Exception as e:
            logger.error(f"상태 파일 업데이트 실패 (시도 {attempt}회차): {e}")
            if attempt < 3:
                time.sleep(2)
            else:
                fail_file = STATUS_FILE + '.fail'
                try:
                    os.rename(STATUS_FILE, fail_file)
                    logger.info(f"상태 파일 .fail로 이동: {fail_file}")
                except Exception as e2:
                    logger.error(f".fail 이동도 실패: {STATUS_FILE} → {fail_file}, 오류: {e2}")


def run_step(cmd, step_name):
    """
    각 단계별 서브프로세스 robust 실행 (3회 재시도, 한글 로그)
    """
    logger.info(f"[{step_name}] 실행 시작: {cmd}")
    update_status('running', step_name)
    for attempt in range(1, 4):
        try:
            result = subprocess.run(cmd, check=True, capture_output=True, text=True)
            logger.info(f"[{step_name}] 실행 완료 (stdout):\n{result.stdout}")
            if result.stderr:
                logger.warning(f"[{step_name}] stderr:\n{result.stderr}")
            return True
        except subprocess.CalledProcessError as e:
            logger.error(f"[{step_name}] 실행 실패 (시도 {attempt}회차): {e}\nstdout:\n{e.stdout}\nstderr:\n{e.stderr}")
            if attempt < 3:
                time.sleep(2)
            else:
                return False
        except Exception as e:
            logger.error(f"[{step_name}] 예외 발생 (시도 {attempt}회차): {e}")
            if attempt < 3:
                time.sleep(2)
            else:
                return False


def main_loop():
    """
    크롤러 → 클리너 → writer robust 순차 실행, writer 끝나면 4시간 대기 후 반복
    """
    logger.info("=== 뉴스 파이프라인 순차 실행 스케줄러 시작 ===")
    # 락 파일로 중복 실행 방지
    with open(LOCK_FILE, 'w') as lock_fp:
        try:
            fcntl.flock(lock_fp, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            logger.error("[중복 실행] 이미 다른 스케줄러 인스턴스가 실행 중입니다. 종료합니다.")
            return
        while True:
            logger.info("[스케줄러] 파이프라인 실행 시작")
            # 1. 크롤러 실행
            if not run_step(CRAWLER_CMD, "크롤러"):
                logger.warning("크롤러 단계에서 오류 발생. 다음 단계로 진행합니다.")
            time.sleep(2)
            # 2. 클리너 실행
            if not run_step(CLEANER_CMD, "클리너"):
                logger.warning("클리너 단계에서 오류 발생. 다음 단계로 진행합니다.")
            time.sleep(2)
            # 3. writer 실행
            if not run_step(WRITER_CMD, "writer"):
                logger.warning("writer 단계에서 오류 발생. 다음 반복으로 진행합니다.")
            logger.info("=== 파이프라인 1회 실행 완료. 4시간 대기 후 재시작 ===")
            update_status('waiting')
            logger.info("[스케줄러] 4시간 대기 진입")
            time.sleep(60 * 60 * 4)

if __name__ == "__main__":
    main_loop() 