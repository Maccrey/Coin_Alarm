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

# 로컬 DB 파일 (처리된 파일 추적용)
DB_FILE = '/app/shared/processed_files.db'

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
    """뉴스 데이터 Supabase에 저장"""
    if not SUPABASE_URL or not SUPABASE_KEY:
        logger.error("Supabase URL 또는 Key가 설정되지 않았습니다.")
        return 0

    # 현재 시간
    now = datetime.now(pytz.timezone('Asia/Seoul')).isoformat()
    
    # 저장 성공 카운트
    success_count = 0

    # Supabase에 저장할 항목 추가
    for news in news_data:
        try:
            # news_hash가 없으면 타이틀 기반으로 생성
            if 'id' not in news or not news['id']:
                news_hash = create_news_hash(news['title'])
                logger.warning(f"news_hash 없음, 자동 생성: {news['title']}")
                news['id'] = news_hash
            
            # 이미 처리된 뉴스인지 확인
            if is_news_processed(news['id'], news['title']):
                logger.info(f"이미 처리된 뉴스 건너뛰기: {news['title']}")
                continue
            
            # 기존 뉴스 데이터 확인
            existing_news = get_existing_news(news['id'])
            
            # 기존 데이터가 있고 image_url과 related_coins 필드가 있으면 그대로 유지
            if existing_news:
                if (existing_news.get('image_url') and not news.get('image_url')) or \
                   (existing_news.get('image_url') and news.get('image_url') == ''):
                    logger.info(f"기존 이미지 URL 유지: {existing_news.get('image_url')}")
                    news['image_url'] = existing_news.get('image_url')
                
                if (existing_news.get('related_coins') and existing_news.get('related_coins') != '{}') and \
                   (not news.get('related_coins') or news.get('related_coins') == '{}'):
                    logger.info(f"기존 관련 코인 유지: {existing_news.get('related_coins')}")
                    news['related_coins'] = existing_news.get('related_coins')
            
            # 이미지 URL 처리 - JSON 파일에서는 'imageUrl'로 되어있음
            if 'imageUrl' in news and news['imageUrl']:
                news['image_url'] = news['imageUrl']
                logger.info(f"이미지 URL 매핑: {news['imageUrl']}")
            elif 'image_url' not in news or not news['image_url']:
                news['image_url'] = ''
                logger.warning(f"image_url 필드가 비어 있음: {news['title']}")

            # 관련 코인 처리 - PostgreSQL 배열 형식으로 변환
            if 'related_coins' in news:
                if isinstance(news['related_coins'], list):
                    if len(news['related_coins']) > 0:
                        # PostgreSQL 배열 형식으로 변환: '{item1,item2,item3}'
                        coins_str = "{" + ",".join([f'"{coin}"' for coin in news['related_coins']]) + "}"
                        news['related_coins'] = coins_str
                        logger.info(f"관련 코인 변환: {coins_str}")
                    else:
                        # 빈 배열
                        news['related_coins'] = "{}"
                elif news['related_coins'] == '[]':
                    news['related_coins'] = "{}"
            else:
                news['related_coins'] = "{}"

            # 생성 시간 추가
            if 'created_at' not in news:
                news['created_at'] = now

            # 필요없는 필드 제거
            if 'crawled_at' in news:
                del news['crawled_at']
            if 'imageUrl' in news:
                del news['imageUrl']
            # cleaned_at 필드 제거 (DB 스키마에 없음)
            if 'cleaned_at' in news:
                del news['cleaned_at']
            # hash 필드 제거 (DB 스키마에 없음)
            if 'hash' in news:
                del news['hash']

            # Supabase에 저장
            url = f"{SUPABASE_URL}/rest/v1/{SUPABASE_NEWS_TABLE}"
            
            logger.info(f"뉴스 저장 요청 데이터: {news}")
            logger.info(f"뉴스 저장 요청 URL: '{url}'")
            
            try:
                response = requests.post(url, json=news, headers=headers)
                logger.info(f"뉴스 저장 응답 코드: {response.status_code}")
                logger.info(f"뉴스 저장 응답 본문: {response.text}")
                
                if response.status_code == 201 or response.status_code == 200:
                    logger.info(f"뉴스 저장 성공: {news['title']}")
                    # 처리 성공한 뉴스 기록
                    mark_news_as_processed(news['id'], news['title'])
                    success_count += 1
                else:
                    logger.error(f"뉴스 저장 실패: {news['title']}, 코드: {response.status_code}, 응답: {response.text}")
            except Exception as e:
                logger.error(f"뉴스 저장 중 오류 발생: {str(e)}")
        except Exception as e:
            logger.error(f"뉴스 처리 중 예외 발생: {str(e)}")
    
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
        
        # 처리 완료된 파일 이름 변경
        processed_file = file_path.replace('cleaned_news_', 'processed_news_').replace('crawled_news_', 'processed_news_')
        os.rename(file_path, processed_file)
        logger.info(f"파일 처리 완료: {processed_file}")
        
        # 처리 완료된 파일 삭제
        os.remove(processed_file)
        logger.info(f"파일 삭제 완료: {processed_file}")
        
        # 파일 처리 기록
        mark_file_as_processed(filename)

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
            
            # 처리 완료된 파일 이름 변경 후 삭제
            processed_file = file_path.replace('cleaned_news_', 'processed_news_')
            os.rename(file_path, processed_file)
            logger.info(f"파일 처리 완료: {processed_file}")
            os.remove(processed_file)
            logger.info(f"파일 삭제 완료: {processed_file}")
            
            # 파일 처리 기록
            mark_file_as_processed(filename)
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
            
            # 처리 완료된 파일 이름 변경 후 삭제
            processed_file = file_path.replace('crawled_news_', 'processed_news_')
            os.rename(file_path, processed_file)
            logger.info(f"파일 처리 완료: {processed_file}")
            os.remove(processed_file)
            logger.info(f"파일 삭제 완료: {processed_file}")
            
            # 파일 처리 기록
            mark_file_as_processed(filename)
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
    logger.info("뉴스 저장 서비스 시작")
    
    # DB 초기화
    init_db()
    
    # 기존 파일 처리 및 정리
    process_existing_files()
    cleanup_old_files()
    
    # 감시자 설정
    event_handler = NewsHandler()
    observer = Observer()
    observer.schedule(event_handler, path=SHARED_DIR, recursive=False)
    observer.start()
    
    try:
        # 매 시간마다 파일 정리
        last_cleanup = datetime.now(pytz.timezone('Asia/Seoul'))
        while True:
            time.sleep(60)  # 1분마다 체크
            
            # 3시간마다 파일 정리 (서버 사용량 감소)
            now = datetime.now(pytz.timezone('Asia/Seoul'))
            if (now - last_cleanup).total_seconds() > 10800:  # 3시간(10800초)
                logger.info("정기 파일 정리 시작")
                cleanup_old_files()
                last_cleanup = now
            
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
    
    logger.info("뉴스 저장 서비스 종료")

if __name__ == "__main__":
    main() 