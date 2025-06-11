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


def clean_news(news_list):
    """
    뉴스 정제 로직
    
    Args:
        news_list (list): 원본 뉴스 리스트
        
    Returns:
        list: 정제된 뉴스 리스트
    """
    logger.info(f"정제 시작: {len(news_list)}개 뉴스")
    
    cleaned_list = []
    unique_hashes = set()
    
    for news in news_list:
        try:
            # 기본 텍스트 정제
            title = clean_text(news.get("title", ""))
            content = clean_text(news.get("content", ""))
            
            # 너무 짧은 컨텐츠 필터링
            if len(content) < MIN_CONTENT_LENGTH:
                logger.info(f"짧은 내용 필터링: {title[:30]}...")
                continue
                
            # 광고성 키워드 필터링
            is_ad = False
            for keyword in AD_KEYWORDS:
                if keyword in title or keyword in content[:100]:
                    logger.info(f"광고성 필터링: {title[:30]}..., 키워드: {keyword}")
                    is_ad = True
                    break
                    
            if is_ad:
                continue
                
            # 해시값으로 중복 체크
            news_hash = get_news_hash(title, news.get("url", ""))
            if news_hash in unique_hashes:
                logger.info(f"중복 필터링: {title[:30]}...")
                continue
                
            unique_hashes.add(news_hash)
            
            # 정제된 뉴스 추가
            cleaned_news = {
                "title": title,
                "content": content,
                "url": news.get("url", ""),
                "imageUrl": news.get("imageUrl", ""),
                "published_at": news.get("published_at", ""),
                "source": news.get("source", ""),
                "hash": news_hash,
                "cleaned_at": datetime.now(pytz.timezone("Asia/Seoul")).strftime("%Y-%m-%d %H:%M:%S"),
                "related_coins": news.get("related_coins", [])
            }
            
            cleaned_list.append(cleaned_news)
            
        except Exception as e:
            logger.error(f"뉴스 정제 오류: {str(e)}")
            continue
    
    logger.info(f"정제 완료: {len(cleaned_list)}개 정제됨, {len(news_list) - len(cleaned_list)}개 필터링됨")
    return cleaned_list


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
        # 정제 로직 수행
        cleaned_news_list = clean_news(news_list)
        # 정제된 파일명 생성
        base_name = os.path.basename(file_path)
        timestamp = datetime.now(pytz.timezone("Asia/Seoul")).strftime("%Y%m%d%H%M%S")
        cleaned_file_path = os.path.join(SHARED_DIR, f'cleaned_news_{timestamp}.json')
        # 파일 저장
        with open(cleaned_file_path, 'w', encoding='utf-8') as f:
            json.dump(cleaned_news_list, f, ensure_ascii=False, indent=2)
        logger.info(f"정제 파일 저장 완료: {cleaned_file_path}, {len(cleaned_news_list)}개 뉴스")
        # 원본 파일 삭제
        try:
            os.remove(file_path)
            logger.info(f"원본 파일 삭제 완료: {file_path}")
        except Exception as e:
            logger.error(f"원본 파일 삭제 오류: {file_path}, {e}")
    except Exception as e:
        logger.error(f"파일 처리 오류: {file_path}, {e}")


def save_cleaned_news(news_list, output_file):
    """
    정제된 뉴스 저장
    
    Args:
        news_list (list): 정제된 뉴스 리스트
        output_file (str): 출력 파일 경로
    """
    if not news_list:
        logger.warning("저장할 뉴스가 없습니다.")
        return
    
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
            process_news_file(file_path)
    
    # 파일 시스템 감시
    event_handler = FileSystemEventHandler()
    event_handler.on_created = lambda event: process_file_event(event)
    
    observer = Observer()
    observer.schedule(event_handler, SHARED_DIR, recursive=False)
    observer.start()
    
    try:
        logger.info("파일 감시 시작...")
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        logger.info("파일 감시 종료")
    
    observer.join()


def process_file_event(event):
    """파일 생성 이벤트 처리"""
    if event.is_directory:
        return
    
    file_path = event.src_path
    if file_path.endswith('.json') and 'crawled_news_' in file_path:
        # 파일 생성 후 약간의 지연시간을 두고 처리 (파일 쓰기 완료 대기)
        time.sleep(1)
        process_news_file(file_path)


if __name__ == "__main__":
    main() 