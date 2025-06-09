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
        logging.FileHandler("/app/shared/cleaner.log")
    ]
)
logger = logging.getLogger(__name__)

# 공유 디렉토리
SHARED_DIR = "/app/shared"

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
    text = re.sub(r"<[^>]*>", "", text)
    
    # 연속된 공백 제거
    text = re.sub(r"\s+", " ", text)
    
    # 양쪽 공백 제거
    text = text.strip()
    
    return text


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
    key = f"{title}|{url}".encode("utf-8")
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
                "image_url": news.get("image_url", ""),
                "published_at": news.get("published_at", ""),
                "source": news.get("source", ""),
                "hash": news_hash,
                "cleaned_at": datetime.now(pytz.timezone("Asia/Seoul")).strftime("%Y-%m-%d %H:%M:%S")
            }
            
            cleaned_list.append(cleaned_news)
            
        except Exception as e:
            logger.error(f"뉴스 정제 오류: {str(e)}")
            continue
    
    logger.info(f"정제 완료: {len(cleaned_list)}개 정제됨, {len(news_list) - len(cleaned_list)}개 필터링됨")
    return cleaned_list


def process_file(file_path):
    """
    파일 처리
    
    Args:
        file_path (str): 처리할 파일 경로
    """
    try:
        logger.info(f"파일 처리: {file_path}")
        
        # 파일 읽기
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            
        # 데이터 형식 확인
        if not isinstance(data, list):
            logger.error(f"잘못된 데이터 형식: {file_path}")
            return
            
        logger.info(f"읽기 완료: {len(data)}개 뉴스")
        
        # 뉴스 정제
        cleaned_data = clean_news(data)
        
        # 정제된 데이터가 없으면 저장하지 않음
        if not cleaned_data:
            logger.info(f"정제된 데이터 없음: {file_path}")
            return
            
        # 정제된 파일 저장
        timestamp = datetime.now(pytz.timezone("Asia/Seoul")).strftime("%Y%m%d%H%M%S")
        output_path = os.path.join(SHARED_DIR, f"cleaned_news_{timestamp}.json")
        
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(cleaned_data, f, ensure_ascii=False, indent=2)
            
        logger.info(f"저장 완료: {output_path}, {len(cleaned_data)}개 뉴스")
        
    except Exception as e:
        logger.error(f"파일 처리 오류: {file_path}, {str(e)}")


class NewsHandler(FileSystemEventHandler):
    """
    뉴스 파일 감시 핸들러
    """
    def on_created(self, event):
        if event.is_directory:
            return
            
        file_path = event.src_path
        if file_path.endswith(".json") and "crawled_news_" in file_path:
            # 파일 생성 후 약간의 지연시간을 두고 처리 (파일 쓰기 완료 대기)
            time.sleep(1)
            process_file(file_path)


def main():
    """
    메인 함수
    """
    logger.info("뉴스 정제 서비스 시작")
    
    # 기존 파일 처리
    for filename in os.listdir(SHARED_DIR):
        if filename.endswith(".json") and filename.startswith("crawled_news_"):
            file_path = os.path.join(SHARED_DIR, filename)
            process_file(file_path)
    
    # 파일 감시 설정
    event_handler = NewsHandler()
    observer = Observer()
    observer.schedule(event_handler, path=SHARED_DIR, recursive=False)
    observer.start()
    
    try:
        while True:
            time.sleep(5)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
    
    logger.info("뉴스 정제 서비스 종료")


if __name__ == "__main__":
    main() 