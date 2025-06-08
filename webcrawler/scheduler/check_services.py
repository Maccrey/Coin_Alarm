#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
서비스 상태 체크 스크립트
- 각 서비스의 상태를 확인하고 로깅
- 문제가 있는 서비스 자동 재시작 (옵션)
"""

import os
import logging
import requests
import psutil
import time
from datetime import datetime
import subprocess

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

# 체크할 서비스 목록
SERVICES = [
    {"name": "news-crawler", "url": "http://news-crawler:5000/health"},
    {"name": "news-cleaner", "url": "http://news-cleaner:5000/health"},
    {"name": "news-writer", "url": "http://news-writer:5000/health"}
]


def check_service(service):
    """
    HTTP 요청으로 서비스 상태 확인
    
    Args:
        service (dict): 서비스 정보
        
    Returns:
        bool: 서비스 정상 여부
    """
    try:
        response = requests.get(service["url"], timeout=5)
        return response.status_code == 200
    except Exception:
        return False


def restart_service(service_name):
    """
    Docker 컨테이너를 실제로 재시작
    """
    logger.info(f"{service_name} 서비스 재시작 시도")
    try:
        result = subprocess.run(
            ["docker", "restart", service_name],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        if result.returncode == 0:
            logger.info(f"{service_name} 서비스 재시작 성공: {result.stdout.strip()}")
            return True
        else:
            logger.error(f"{service_name} 서비스 재시작 실패: {result.stderr.strip()}")
            return False
    except Exception as e:
        logger.error(f"{service_name} 서비스 재시작 중 예외 발생: {e}")
        return False


def get_system_info():
    """
    시스템 리소스 정보 조회
    
    Returns:
        dict: 시스템 정보
    """
    try:
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        return {
            "cpu_percent": cpu_percent,
            "memory_percent": memory.percent,
            "disk_percent": disk.percent
        }
    except Exception as e:
        logger.error(f"시스템 정보 조회 오류: {e}")
        return {}


def main():
    """메인 함수"""
    logger.info("서비스 상태 체크 시작")
    
    # 시스템 리소스 정보 로깅
    system_info = get_system_info()
    if system_info:
        logger.info(f"시스템 상태 - CPU: {system_info['cpu_percent']}%, "
                   f"메모리: {system_info['memory_percent']}%, "
                   f"디스크: {system_info['disk_percent']}%")
    
    # 각 서비스 상태 체크
    for service in SERVICES:
        service_ok = check_service(service)
        if service_ok:
            logger.info(f"{service['name']} 서비스 정상")
        else:
            logger.warning(f"{service['name']} 서비스 응답 없음")
            # 서비스 자동 재시작
            restart_service(service['name'])
    
    logger.info("서비스 상태 체크 완료")


if __name__ == "__main__":
    while True:
        main()
        logger.info("2시간 대기 후 다음 체크 진행")
        time.sleep(60 * 60 * 2)  # 2시간 대기 