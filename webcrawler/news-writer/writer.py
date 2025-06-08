#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
뉴스 저장 서비스
- 정제된 뉴스를 Supabase에 저장
- 뉴스와 코인의 관계도 저장
"""

import os
import json
import time
import logging
from datetime import datetime
import pytz
import requests
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from dotenv import load_dotenv
import uuid

# 환경 변수 로드
load_dotenv()

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/app/shared/writer.log')
    ]
)
logger = logging.getLogger(__name__)

# 공유 디렉토리
SHARED_DIR = '/app/shared'

# Supabase 설정
SUPABASE_URL = os.environ.get("SUPABASE_URL", "").strip()
SUPABASE_API_KEY = (
    os.environ.get("SUPABASE_API_KEY")
    or os.environ.get("SUPABASE_KEY")
    or ""
).strip()

if not SUPABASE_URL or not SUPABASE_API_KEY:
    logger.error("Supabase 환경 변수가 설정되지 않았습니다.")

# RLS 정책 안내 함수
def check_rls_guide(response):
    if response.status_code == 404:
        logger.error("404 에러: Supabase news 테이블에 RLS가 활성화되어 있고 정책이 없으면 모든 API 접근이 차단됩니다. Supabase 대시보드에서 RLS를 비활성화하거나, 정책을 추가하세요.")
    elif response.status_code in (401, 403):
        logger.error("권한 에러: Supabase news 테이블의 RLS 정책 또는 API Key 권한을 확인하세요.")

# imageUrl, image_url 중 값이 있는 첫 번째를 반환하는 함수
def get_image_url(news):
    for key in ['imageUrl', 'image_url']:
        val = news.get(key)
        if val is not None and str(val).strip() != '':
            return val
    return ''

def save_to_supabase(news_list):
    """
    뉴스를 Supabase에 저장
    
    Args:
        news_list (list): 저장할 뉴스 리스트
        
    Returns:
        bool: 성공 여부
    """
    if not news_list:
        logger.warning("저장할 뉴스가 없습니다.")
        return False
    
    if not SUPABASE_URL or not SUPABASE_API_KEY:
        logger.error("Supabase 연결 정보가 없습니다.")
        return False
    
    logger.info(f"Supabase에 {len(news_list)}개 뉴스 저장 시작")
    
    try:
        # Supabase REST API 호출 (news 테이블에 저장)
        url = f"{SUPABASE_URL}/rest/v1/news"
        
        headers = {
            "apikey": SUPABASE_API_KEY,
            "Authorization": f"Bearer {SUPABASE_API_KEY}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates"
        }
        
        for news in news_list:
            try:
                # 관련 코인 정보 추출
                related_coins = news.pop('related_coins', [])
                
                # news_hash를 id로 사용
                news_hash = news.pop('news_hash', None)
                if not news_hash:
                    logger.warning(f"news_hash 없음: {news['title']}")
                    continue
                
                # 뉴스 데이터 구성
                news_data = {
                    "id": news_hash,
                    "title": news.get('title', ''),
                    "content": news.get('content', ''),
                    "url": news.get('url', ''),
                    "source": news.get('source', ''),
                    "published_at": news.get('published_at', datetime.now(pytz.timezone('Asia/Seoul')).isoformat()),
                    "created_at": datetime.now().isoformat(),
                    "image_url": get_image_url(news),
                    "related_coins": related_coins
                }
                # content, image_url 값이 비었을 때 경고 로그 추가
                if not news_data["content"]:
                    logger.warning(f"content 필드가 비어 있음: {news_data['title']}")
                if not news_data["image_url"]:
                    logger.warning(f"image_url 필드가 비어 있음: {news_data['title']}")
                
                # 추가: 요청 정보 로그
                logger.info(f"뉴스 저장 요청 데이터: {news_data}")
                logger.info(f"뉴스 저장 요청 URL: '{url}'")
                logger.info(f"뉴스 저장 요청 헤더: {headers}")
                
                # 뉴스 저장 API 호출
                response = requests.post(
                    url,
                    headers=headers,
                    json=news_data
                )
                
                # 추가: 응답 정보 로그
                logger.info(f"뉴스 저장 응답 코드: {response.status_code}")
                logger.info(f"뉴스 저장 응답 본문: {response.text}")
                check_rls_guide(response)
                
                if response.status_code not in (201, 200):
                    logger.error(f"뉴스 저장 실패: {response.status_code}, {response.text}")
                    continue
                
                logger.info(f"뉴스 저장 성공: {news_data['title']}")
                
                # 관련 코인 저장 (news_coins 테이블)
                if related_coins:
                    for coin_symbol in related_coins:
                        coin_data = {
                            'news_id': news_hash,
                            'coin_symbol': coin_symbol,
                            'created_at': datetime.now().isoformat()
                        }
                        
                        coin_response = requests.post(
                            f"{SUPABASE_URL}/rest/v1/news_coins",
                            headers=headers,
                            json=coin_data
                        )
                        
                        if coin_response.status_code not in (201, 200):
                            logger.warning(f"코인 관계 저장 실패: {coin_response.status_code}, {coin_response.text}")
                        else:
                            logger.info(f"코인 관계 저장 성공: {news_hash} - {coin_symbol}")
            
            except Exception as e:
                logger.error(f"개별 뉴스 저장 오류: {e}")
                continue
        
        logger.info("Supabase 저장 완료")
        return True
        
    except Exception as e:
        logger.error(f"Supabase 저장 오류: {e}")
        return False


def process_news_file(file_path):
    """
    정제된 뉴스 파일 처리
    
    Args:
        file_path (str): 파일 경로
    """
    logger.info(f"파일 처리: {file_path}")
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            news_list = json.load(f)
        
        logger.info(f"읽기 완료: {len(news_list)}개 뉴스")
        
        # Supabase에 저장
        success = save_to_supabase(news_list)
        
        if success:
            # 처리 완료된 파일 이동 또는 처리 표시
            processed_file = file_path.replace('cleaned_news_', 'processed_news_')
            os.rename(file_path, processed_file)
            logger.info(f"파일 처리 완료: {processed_file}")
            # 처리 완료된 파일 즉시 삭제
            try:
                os.remove(processed_file)
                logger.info(f"파일 삭제 완료: {processed_file}")
            except Exception as e:
                logger.error(f"파일 삭제 오류: {processed_file}, {e}")
        
    except Exception as e:
        logger.error(f"파일 처리 오류: {file_path}, {e}")


def main():
    """메인 함수"""
    logger.info("뉴스 저장 서비스 시작")
    
    # Supabase 연결 정보 확인
    if not SUPABASE_URL or not SUPABASE_API_KEY:
        logger.error("Supabase 환경 변수가 설정되지 않았습니다.")
    
    # 기존 파일 처리
    for file_name in os.listdir(SHARED_DIR):
        if file_name.startswith('cleaned_news_') and file_name.endswith('.json'):
            file_path = os.path.join(SHARED_DIR, file_name)
            process_news_file(file_path)
    
    logger.info("뉴스 저장 서비스 종료")


if __name__ == "__main__":
    main() 