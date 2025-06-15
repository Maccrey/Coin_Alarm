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
from datetime import datetime, timedelta
import pytz
import requests
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from dotenv import load_dotenv
import uuid
import hashlib
import glob
import sqlite3

# 환경 변수 로드
load_dotenv()

# 공유 디렉토리 (항상 절대경로로 고정)
SHARED_DIR = os.path.abspath(os.environ.get('SHARED_DIR', './shared'))
os.makedirs(SHARED_DIR, exist_ok=True)

# 로깅 설정 (SHARED_DIR 기반)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.join(SHARED_DIR, 'writer.log'))
    ]
)
logger = logging.getLogger('writer')

# 로컬 DB 파일 (처리된 파일 추적용)
DB_FILE = os.path.join(SHARED_DIR, 'processed_files.db')

# Supabase 설정
SUPABASE_URL = os.environ.get("SUPABASE_URL", "").strip()
SUPABASE_KEY = os.environ.get("SUPABASE_API_KEY", "").strip()  # 환경 변수 이름 변경
SUPABASE_NEWS_TABLE = 'news'

# 헤더 설정
headers = {
    'apikey': SUPABASE_KEY,
    'Content-Type': 'application/json',
    'Prefer': 'resolution=merge-duplicates,return=minimal'
}

def init_db():
    """로컬 SQLite DB 초기화"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS processed_files (
        filename TEXT PRIMARY KEY,
        processed_at TIMESTAMP
    )
    ''')
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS processed_news (
        news_id TEXT PRIMARY KEY,
        title TEXT,
        processed_at TIMESTAMP
    )
    ''')
    conn.commit()
    conn.close()
    logger.info("로컬 DB 초기화 완료")

def is_file_processed(filename):
    """파일이 이미 처리되었는지 확인"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute('SELECT filename FROM processed_files WHERE filename = ?', (filename,))
    result = cursor.fetchone()
    conn.close()
    return result is not None

def mark_file_as_processed(filename):
    """파일을 처리됨으로 표시"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute('INSERT OR REPLACE INTO processed_files VALUES (?, ?)', 
                 (filename, datetime.now(pytz.timezone('Asia/Seoul')).isoformat()))
    conn.commit()
    conn.close()

def is_news_processed(news_id, title):
    """뉴스가 이미 처리되었는지 확인"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute('SELECT news_id FROM processed_news WHERE news_id = ?', (news_id,))
    result = cursor.fetchone()
    conn.close()
    return result is not None

def mark_news_as_processed(news_id, title):
    """뉴스를 처리됨으로 표시"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute('INSERT OR REPLACE INTO processed_news VALUES (?, ?, ?)', 
                 (news_id, title, datetime.now(pytz.timezone('Asia/Seoul')).isoformat()))
    conn.commit()
    conn.close()

def get_existing_news(news_id):
    """Supabase에서 기존 뉴스 정보 가져오기"""
    if not SUPABASE_URL or not SUPABASE_KEY:
        logger.error("Supabase URL 또는 Key가 설정되지 않았습니다.")
        return None
    
    url = f"{SUPABASE_URL}/rest/v1/{SUPABASE_NEWS_TABLE}?id=eq.{news_id}"
    get_headers = headers.copy()
    get_headers['Prefer'] = 'return=representation'
    
    try:
        response = requests.get(url, headers=get_headers)
        if response.status_code == 200 and response.json():
            return response.json()[0]
        return None
    except Exception as e:
        logger.error(f"기존 뉴스 조회 중 오류: {str(e)}")
        return None

def create_news_hash(title):
    """뉴스 해시 생성"""
    return hashlib.md5(title.encode('utf-8')).hexdigest()

def save_to_supabase(news_data):
    """뉴스 데이터 Supabase에 저장 (신뢰성 강화)"""
    if not SUPABASE_URL or not SUPABASE_KEY:
        logger.error("Supabase URL 또는 Key가 설정되지 않았습니다.")
        return 0

    now = datetime.now(pytz.timezone('Asia/Seoul')).isoformat()
    success_count = 0
    
    # 1. ID 없는 데이터에 ID 생성 (cleaner의 'hash' 필드 사용)
    for news in news_data:
        if 'id' not in news or not news['id']:
            if 'hash' in news and news['hash']:
                news['id'] = news['hash']
                logger.info(f"ID 필드를 hash 값으로 설정: {news['title']}")
            else:
                news_hash = create_news_hash(news['title'])
                logger.warning(f"ID(hash) 없음, 자동 생성: {news['title']}")
                news['id'] = news_hash

    # 2. Supabase에 이미 존재하는지 ID로 일괄 확인
    news_ids = [news['id'] for news in news_data if 'id' in news]
    existing_ids = set()
    if news_ids:
        try:
            url = f"{SUPABASE_URL}/rest/v1/{SUPABASE_NEWS_TABLE}?select=id&id=in.({','.join(news_ids)})"
            response = requests.get(url, headers={'apikey': SUPABASE_KEY, 'Content-Type': 'application/json'})
            if response.status_code == 200:
                existing_ids = {item['id'] for item in response.json()}
                logger.info(f"Supabase에서 {len(existing_ids)}개의 기존 뉴스 ID 확인")
            else:
                logger.error(f"Supabase 기존 뉴스 ID 확인 실패: {response.text}")
        except Exception as e:
            logger.error(f"Supabase 기존 뉴스 ID 확인 중 예외: {e}")

    # 3. 신규 뉴스만 저장 시도
    news_to_save = []
    for news in news_data:
        if news.get('id') not in existing_ids:
            # 필수 필드 체크
            if not news.get('title') or not news.get('url') or not news.get('published_at'):
                logger.error(f"필수 필드 누락, 건너뛰기: {news.get('title')}")
                continue
            
            # 필드 정리 및 추가
            news['image_url'] = news.get('imageUrl', news.get('image_url', ''))
            
            if 'related_coins' in news and isinstance(news['related_coins'], list):
                news['related_coins'] = "{" + ",".join([f'\\"{c}\\"' for c in news['related_coins']]) + "}"
            else:
                news['related_coins'] = "{}"

            news['created_at'] = news.get('created_at', now)
            
            # 불필요한 필드 제거
            for field in ['crawled_at', 'imageUrl', 'cleaned_at', 'hash']:
                if field in news:
                    del news[field]

            news_to_save.append(news)
        else:
            logger.info(f"이미 저장된 뉴스 건너뛰기: {news.get('title')}")
    
    if not news_to_save:
        logger.info("새로 저장할 뉴스가 없습니다.")
        return 0

    # 4. 일괄 저장 (bulk insert)
    try:
        url = f"{SUPABASE_URL}/rest/v1/{SUPABASE_NEWS_TABLE}"
        response = requests.post(url, json=news_to_save, headers=headers, timeout=30)

        if response.status_code in (200, 201):
            success_count = len(news_to_save)
            logger.info(f"Supabase에 뉴스 {success_count}개 저장 성공!")
            for news in news_to_save:
                 logger.info(f"  - 저장 성공: {news['title']}")
        else:
            logger.error(f"Supabase 뉴스 일괄 저장 실패: {response.status_code} | {response.text}")
            # 개별 저장으로 재시도
            logger.info("개별 저장으로 재시도합니다.")
            individual_success = 0
            for news in news_to_save:
                try:
                    res_ind = requests.post(url, json=news, headers=headers, timeout=10)
                    if res_ind.status_code in (200, 201):
                        individual_success += 1
                        logger.info(f"  - 개별 저장 성공: {news['title']}")
                    else:
                        logger.error(f"  - 개별 저장 실패: {news['title']} | {res_ind.text}")
                except Exception as e_ind:
                    logger.error(f"  - 개별 저장 예외: {news['title']} | {e_ind}")
            success_count = individual_success

    except Exception as e:
        logger.error(f"Supabase 저장 중 예외 발생: {str(e)}")

    logger.info(f"Supabase 저장 완료: {success_count}개 성공")
    return success_count

class NewsHandler(FileSystemEventHandler):
    """뉴스 파일 변경 감지 및 처리"""
    
    def on_created(self, event):
        """파일 생성 이벤트 처리"""
        if not event.is_directory and event.src_path.endswith('.json'):
            file_path = event.src_path
            filename = os.path.basename(file_path)
            
            # 파일 유형 확인 및 처리
            if 'cleaned_news_' in filename or 'crawled_news_' in filename:
                # 이미 처리된 파일인지 확인
                if is_file_processed(filename):
                    logger.info(f"이미 처리된 파일 건너뛰기: {filename}")
                    return
                
                logger.info(f"새 파일 처리: {file_path}")
                try:
                    self.process_file(file_path)
                except Exception as e:
                    logger.error(f"파일 처리 중 오류 발생: {str(e)}")
    
    def process_file(self, file_path):
        """뉴스 파일 처리"""
        filename = os.path.basename(file_path)
        
        # 이미 처리된 파일인지 확인
        if is_file_processed(filename):
            logger.info(f"이미 처리된 파일 건너뛰기: {filename}")
            return
        
        # 파일 읽기
        with open(file_path, 'r', encoding='utf-8') as f:
            news_data = json.load(f)
        
        logger.info(f"읽기 완료: {len(news_data)}개 뉴스")
        
        # Supabase에 저장
        logger.info(f"Supabase에 {len(news_data)}개 뉴스 저장 시작")
        success_count = save_to_supabase(news_data)
        logger.info(f"Supabase 저장 완료: {success_count}개 성공")
        
        if success_count == len(news_data):
            # 전체 성공 시에만 파일 삭제
            processed_file = file_path.replace('cleaned_news_', 'processed_news_').replace('crawled_news_', 'processed_news_')
            os.rename(file_path, processed_file)
            logger.info(f"파일 처리 완료: {processed_file}")
            os.remove(processed_file)
            logger.info(f"파일 삭제 완료: {processed_file}")
            mark_file_as_processed(filename)
        else:
            logger.error(f"일부 뉴스 저장 실패! 파일을 삭제하지 않고 남깁니다: {file_path}")

def process_existing_files():
    """기존 파일 처리"""
    # 정제된 뉴스 파일 처리
    cleaned_files = glob.glob(os.path.join(SHARED_DIR, 'cleaned_news_*.json'))
    for file_path in cleaned_files:
        filename = os.path.basename(file_path)
        
        # 이미 처리된 파일인지 확인
        if is_file_processed(filename):
            logger.info(f"이미 처리된 파일 건너뛰기: {filename}")
            continue
            
        logger.info(f"기존 정제 파일 처리: {file_path}")
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                news_data = json.load(f)
            
            logger.info(f"읽기 완료: {len(news_data)}개 뉴스")
            success_count = save_to_supabase(news_data)
            logger.info(f"Supabase 저장 완료: {success_count}개 성공")
            
            if success_count == len(news_data):
                # 전체 성공 시에만 파일 삭제
                processed_file = file_path.replace('cleaned_news_', 'processed_news_')
                os.rename(file_path, processed_file)
                logger.info(f"파일 처리 완료: {processed_file}")
                os.remove(processed_file)
                logger.info(f"파일 삭제 완료: {processed_file}")
                mark_file_as_processed(filename)
            else:
                logger.error(f"일부 뉴스 저장 실패! 파일을 삭제하지 않고 남깁니다: {file_path}")
        except Exception as e:
            logger.error(f"기존 파일 처리 중 오류 발생: {str(e)}")
    
    # 크롤링된 뉴스 파일 처리
    crawled_files = glob.glob(os.path.join(SHARED_DIR, 'crawled_news_*.json'))
    for file_path in crawled_files:
        filename = os.path.basename(file_path)
        
        # 이미 처리된 파일인지 확인
        if is_file_processed(filename):
            logger.info(f"이미 처리된 파일 건너뛰기: {filename}")
            continue
            
        logger.info(f"기존 크롤링 파일 처리: {file_path}")
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                news_data = json.load(f)
            
            logger.info(f"읽기 완료: {len(news_data)}개 뉴스")
            success_count = save_to_supabase(news_data)
            logger.info(f"Supabase 저장 완료: {success_count}개 성공")
            
            if success_count == len(news_data):
                # 전체 성공 시에만 파일 삭제
                processed_file = file_path.replace('crawled_news_', 'processed_news_')
                os.rename(file_path, processed_file)
                logger.info(f"파일 처리 완료: {processed_file}")
                os.remove(processed_file)
                logger.info(f"파일 삭제 완료: {processed_file}")
                mark_file_as_processed(filename)
            else:
                logger.error(f"일부 뉴스 저장 실패! 파일을 삭제하지 않고 남깁니다: {file_path}")
        except Exception as e:
            logger.error(f"기존 파일 처리 중 오류 발생: {str(e)}")

def cleanup_old_files():
    """오래된 파일 정리"""
    # 현재 시간으로부터 하루 이상 지난 파일 삭제
    cutoff_time = datetime.now(pytz.timezone('Asia/Seoul')) - timedelta(days=1)
    
    # 모든 JSON 파일 확인
    all_files = glob.glob(os.path.join(SHARED_DIR, '*.json'))
    for file_path in all_files:
        try:
            file_stats = os.stat(file_path)
            file_time = datetime.fromtimestamp(file_stats.st_mtime, pytz.timezone('Asia/Seoul'))
            
            if file_time < cutoff_time:
                logger.info(f"오래된 파일 삭제: {file_path}")
                os.remove(file_path)
                
                # 파일 처리 기록
                filename = os.path.basename(file_path)
                mark_file_as_processed(filename)
        except Exception as e:
            logger.error(f"파일 정리 중 오류 발생: {str(e)}")
    
    # 오래된 DB 기록 정리 (30일 이상)
    try:
        cutoff_time = datetime.now(pytz.timezone('Asia/Seoul')) - timedelta(days=30)
        cutoff_str = cutoff_time.isoformat()
        
        conn = sqlite3.connect(DB_FILE)
        cursor = conn.cursor()
        cursor.execute('DELETE FROM processed_files WHERE processed_at < ?', (cutoff_str,))
        cursor.execute('DELETE FROM processed_news WHERE processed_at < ?', (cutoff_str,))
        conn.commit()
        conn.close()
        logger.info("오래된 DB 기록 정리 완료")
    except Exception as e:
        logger.error(f"DB 정리 중 오류 발생: {str(e)}")

def main():
    """메인 함수"""
    logger.info("뉴스 저장 서비스 시작 (1회 실행)")
    init_db()  # DB 초기화
    
    # 처리되지 않은 기존 파일 처리
    process_existing_files()
    
    # 오래된 파일 정리
    cleanup_old_files()
    
    logger.info("뉴스 저장 서비스 종료")

if __name__ == "__main__":
    main() 