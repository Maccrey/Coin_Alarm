#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
스케줄러 서비스
- 3시간마다 크롤링/정제/저장 파이프라인 전체 실행
- 각 서비스를 순차적으로 실행하여 end-to-end 파이프라인 구성
"""

import time
import subprocess
import logging
import os

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/app/shared/scheduler.log')
    ]
)
logger = logging.getLogger(__name__)

def run_service(service_name, script_path):
    """
    서비스 실행
    
    Args:
        service_name (str): 서비스 이름
        script_path (str): 실행할 스크립트 경로
    """
    logger.info(f"{service_name} 실행 시작")
    
    try:
        result = subprocess.run(
            ["python", script_path],
            capture_output=True,
            text=True
        )
        
        if result.stdout:
            logger.info(f"{service_name} 출력:\n{result.stdout}")
        
        if result.returncode == 0:
            logger.info(f"{service_name} 실행 완료 (성공)")
        else:
            logger.error(f"{service_name} 실행 실패 (코드: {result.returncode})")
            if result.stderr:
                logger.error(f"{service_name} 오류:\n{result.stderr}")
                
    except Exception as e:
        logger.error(f"{service_name} 실행 중 예외 발생: {e}")

def execute_pipeline():
    """뉴스 파이프라인 전체 실행"""
    logger.info("=== 뉴스 파이프라인 전체 실행 시작 ===")
    
    # 1. 뉴스 크롤링
    run_service("news-crawler", "/app/news-crawler/crawler.py")
    
    # 2. 뉴스 정제
    run_service("news-cleaner", "/app/news-cleaner/cleaner.py")
    
    # 3. 뉴스 저장
    run_service("news-writer", "/app/news-writer/writer.py")
    
    logger.info("=== 뉴스 파이프라인 전체 실행 완료 ===")

def main():
    """메인 함수"""
    logger.info("스케줄러 서비스 시작")
    
    # 초기 실행
    execute_pipeline()
    
    # 3시간마다 반복 실행
    while True:
        logger.info("3시간 휴면 상태로 대기 후 다음 실행")
        time.sleep(60 * 60 * 3)  # 3시간 대기
        execute_pipeline()

if __name__ == "__main__":
    main() 