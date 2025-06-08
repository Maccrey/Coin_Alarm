#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
뉴스 정제 서비스
- 중복 뉴스 제거
- 광고성 뉴스 필터링
- 뉴스 내용 정제
"""

import os
import json
import time
import logging
import hashlib
from datetime import datetime
import pytz
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import re

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/app/shared/cleaner.log')
    ]
)
logger = logging.getLogger(__name__)

# 공유 디렉토리
SHARED_DIR = '/app/shared'

# 광고성 키워드 (필터링 대상)
AD_KEYWORDS = [
    '스폰서', '광고', '파트너십', '보도자료', '홍보',
    '이벤트', '프로모션', '제휴', '할인', '공시', 
    '기획', 'PR', '쿠폰', '사은품', '소개', '스폰서드'
]

# 짧은 뉴스 길이 기준 (필터링 대상)
MIN_CONTENT_LENGTH = 200


def clean_text(text):
    """
    텍스트 정제
    
    Args:
        text (str): 정제할 텍스트
        
    Returns:
        str: 정제된 텍스트
    """
    if not text:
        return ""
    
    # HTML 태그 제거
    text = re.sub(r'<[^>]*>', '', text)
    
    # 연속된 공백 및 줄바꿈 정리
    text = re.sub(r'\s+', ' ', text)
    
    # 앞뒤 공백 제거
    text = text.strip()
    
    return text


def is_ad_content(title, content):
    """
    광고성 컨텐츠 여부 확인 (임시 비활성화)
    Args:
        title (str): 뉴스 제목
        content (str): 뉴스 내용
    Returns:
        bool: 광고성 컨텐츠면 True, 아니면 False
    """
    return False


def get_news_hash(title, url):
    """
    뉴스 해시값 생성 (중복 확인용)
    
    Args:
        title (str): 뉴스 제목
        url (str): 뉴스 URL
        
    Returns:
        str: 해시값
    """
    # 제목과 URL 기반으로 해시 생성
    key = f"{title}|{url}".encode('utf-8')
    return hashlib.md5(key).hexdigest()


def process_news_file(file_path):
    """
    뉴스 파일 처리
    
    Args:
        file_path (str): 뉴스 파일 경로
        
    Returns:
        list: 정제된 뉴스 리스트
    """
    logger.info(f"파일 처리: {file_path}")
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            news_list = json.load(f)
        
        logger.info(f"읽기 완료: {len(news_list)}개 뉴스")
        
        # 뉴스 정제 및 중복 제거
        unique_news = {}
        for news in news_list:
            try:
                title = clean_text(news.get('title', ''))
                content = clean_text(news.get('content', ''))
                url = news.get('url', '')
                
                # 필수 필드 확인
                if not title or not url:
                    logger.warning(f"필수 필드 누락: {news}")
                    continue
                
                # 광고성 컨텐츠 필터링
                if is_ad_content(title, content):
                    logger.info(f"광고성 컨텐츠 필터링: {title}")
                    continue
                
                # 해시값으로 중복 확인
                news_hash = get_news_hash(title, url)
                
                # 정제된 뉴스 생성
                cleaned_news = {
                    'title': title,
                    'content': content,
                    'url': url,
                    'source': news.get('source', ''),
                    'published_at': news.get('published_at', datetime.now(pytz.timezone('Asia/Seoul')).isoformat()),
                    'related_coins': news.get('related_coins', []),
                    'crawled_at': news.get('crawled_at', datetime.now().isoformat()),
                    'news_hash': news_hash,
                    'imageUrl': news.get('imageUrl', '')
                }
                
                # 이미 있는 해시면 건너뛰기
                if news_hash in unique_news:
                    logger.info(f"중복 뉴스 제거: {title}")
                    continue
                
                # 중복 없는 뉴스 추가
                unique_news[news_hash] = cleaned_news
                
            except Exception as e:
                logger.error(f"뉴스 정제 오류: {e}")
                continue
        
        # 해시값을 키로 하는 딕셔너리에서 값만 리스트로 변환
        cleaned_news_list = list(unique_news.values())
        logger.info(f"정제 완료: {len(cleaned_news_list)}개 뉴스")
        
        return cleaned_news_list
        
    except Exception as e:
        logger.error(f"파일 처리 오류: {file_path}, {e}")
        return []


def save_cleaned_news(news_list, original_file):
    """
    정제된 뉴스 저장
    
    Args:
        news_list (list): 정제된 뉴스 리스트
        original_file (str): 원본 파일 이름
    """
    if not news_list:
        logger.warning("저장할 뉴스가 없습니다.")
        return
    
    # 원본 파일 이름에서 타임스탬프 부분 추출
    base_name = os.path.basename(original_file)
    timestamp = "".join(filter(str.isdigit, base_name))
    
    output_file = os.path.join(SHARED_DIR, f'cleaned_news_{timestamp}.json')
    
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(news_list, f, ensure_ascii=False, indent=2)
        logger.info(f"정제된 뉴스 저장 완료: {output_file}")
    except Exception as e:
        logger.error(f"파일 저장 오류: {e}")


def main():
    """메인 함수"""
    logger.info("뉴스 정제 서비스 시작")
    
    # 기존 파일 처리
    for file_name in os.listdir(SHARED_DIR):
        if file_name.startswith('crawled_news_') and file_name.endswith('.json'):
            file_path = os.path.join(SHARED_DIR, file_name)
            cleaned_news = process_news_file(file_path)
            save_cleaned_news(cleaned_news, file_path)
    
    logger.info("뉴스 정제 서비스 종료")


if __name__ == "__main__":
    main() 