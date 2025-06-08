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

def run_docker_command(container_name, command):
    """
    도커 컨테이너에서 명령어 실행
    
    Args:
        container_name (str): 컨테이너 이름
        command (str): 실행할 명령어
    """
    logger.info(f"{container_name} 컨테이너에서 '{command}' 실행 시작")
    
    try:
        result = subprocess.run(
            ["docker", "exec", container_name, "python", command],
            capture_output=True,
            text=True
        )
        
        if result.stdout:
            logger.info(f"{container_name} 출력:\n{result.stdout}")
        
        if result.returncode == 0:
            logger.info(f"{container_name} 실행 완료 (성공)")
        else:
            logger.error(f"{container_name} 실행 실패 (코드: {result.returncode})")
            if result.stderr:
                logger.error(f"{container_name} 오류:\n{result.stderr}")
                
    except Exception as e:
        logger.error(f"{container_name} 실행 중 예외 발생: {e}")

def execute_pipeline():
    """뉴스 파이프라인 전체 실행"""
    logger.info("=== 뉴스 파이프라인 전체 실행 시작 ===")
    
    # 1. 뉴스 크롤링
    run_docker_command("news-crawler", "/app/crawler.py")
    
    # 2. 뉴스 정제
    run_docker_command("news-cleaner", "/app/cleaner.py")
    
    # 3. 뉴스 저장
    run_docker_command("news-writer", "/app/writer.py")
    
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