#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
암호화폐 뉴스 크롤러 서비스
- Blockmedia, CoinReaders, Bloomingbit 사이트의 뉴스를 수집
- 관련 코인 자동 태깅 (dummy_coins.dart 데이터 활용)
"""

import os
import json
import time
import logging
from datetime import datetime
import requests
from bs4 import BeautifulSoup
import pytz
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/app/shared/crawler.log')
    ]
)
logger = logging.getLogger(__name__)

# 공유 디렉토리
SHARED_DIR = '/app/shared'

# 크롤링 사이트 정보
SITES = {
    'blockmedia': {
        'url': 'https://www.blockmedia.co.kr/archives/category/market/digital-asset',
        'article_selector': 'article',
        'title_selector': 'h2, h3, .entry-title',
        'link_selector': 'a',
        'date_selector': 'time',
        'base_url': 'https://www.blockmedia.co.kr',
        'content_selector': ['.view-cont', '.entry-content', '.post-content']
    },
    'coinreaders': {
        'url': 'https://www.coinreaders.com/sub.html?section=sc21',
        'article_selector': '.media',
        'title_selector': '.media-body h4 a',
        'link_selector': '.media-body h4 a',
        'date_selector': '.media-body .write-time',
        'base_url': 'https://www.coinreaders.com',
        'content_selector': ['#article-view-content-div']
    },
    # 'bloomingbit': {
    #     'url': 'https://bloomingbit.io/news',
    #     'article_selector': '.news-list > li',
    #     'title_selector': '.news-title',
    #     'link_selector': '.news-title a',
    #     'date_selector': '.news-date',
    #     'base_url': 'https://bloomingbit.io',
    #     'content_selector': ['.news-content']
    # },
    'digitaltoday': {
        'url': 'https://www.digitaltoday.co.kr/news/articleList.html?sc_section_code=S1N9&view_type=sm',
        'article_selector': 'div.list-block',
        'title_selector': 'a.article-title',
        'link_selector': 'a.article-title',
        'date_selector': 'span.byline-date',
        'base_url': 'https://www.digitaltoday.co.kr',
        'content_selector': ['#article-view-content-div']
    },
}

# 코인 데이터 (dummy_coins.dart 참조)
COIN_DATA = [
    {"id": "bitcoin", "name": "비트코인", "symbol": "BTC"},
    {"id": "ethereum", "name": "이더리움", "symbol": "ETH"},
    {"id": "binancecoin", "name": "바이낸스 코인", "symbol": "BNB"},
    {"id": "ripple", "name": "리플", "symbol": "XRP"},
    {"id": "cardano", "name": "카르다노", "symbol": "ADA"},
    {"id": "solana", "name": "솔라나", "symbol": "SOL"},
    {"id": "dogecoin", "name": "도지코인", "symbol": "DOGE"},
    {"id": "polkadot", "name": "폴카닷", "symbol": "DOT"},
    {"id": "avalanche", "name": "아발란체", "symbol": "AVAX"},
    {"id": "uniswap", "name": "유니스왑", "symbol": "UNI"},
    {"id": "chainlink", "name": "체인링크", "symbol": "LINK"},
    {"id": "polygon", "name": "폴리곤", "symbol": "MATIC"},
    {"id": "cosmos", "name": "코스모스", "symbol": "ATOM"},
    {"id": "arbitrum", "name": "아비트럼", "symbol": "ARB"}
]

target_urls = [
    # 기존 크롤링 대상
    # ...
    "https://www.blockmedia.co.kr/archives/category/market/digital-asset"
]

def get_related_coins(title, content):
    """
    뉴스 제목과 내용에서 관련 코인을 추출
    
    Args:
        title (str): 뉴스 제목
        content (str): 뉴스 내용
        
    Returns:
        list: 관련 코인 심볼 리스트 (e.g. ['BTC', 'ETH'])
    """
    related_coins = []
    text = (title + " " + content).lower()
    
    for coin in COIN_DATA:
        # 한글 이름, 영문 이름, 심볼로 검색
        if (coin["name"] in text or 
            coin["id"].lower() in text or 
            coin["symbol"].lower() in text):
            related_coins.append(coin["symbol"])
    
    return list(set(related_coins))  # 중복 제거


def parse_date(date_str, site):
    """
    사이트별 날짜 형식 파싱
    
    Args:
        date_str (str): 날짜 문자열
        site (str): 사이트 이름
        
    Returns:
        datetime: 파싱된 날짜
    """
    try:
        now = datetime.now(pytz.timezone('Asia/Seoul'))
        
        if site == 'blockmedia':
            # "2023-06-25 08:30:45" 또는 "2023-06-25 08:30"
            try:
                return datetime.strptime(date_str.strip(), "%Y-%m-%d %H:%M:%S")
            except ValueError:
                return datetime.strptime(date_str.strip(), "%Y-%m-%d %H:%M")
        elif site == 'coinreaders':
            # 예: "2023-06-25"
            return datetime.strptime(date_str.strip(), "%Y-%m-%d")
        elif site == 'bloomingbit':
            # 예: "2023.06.25"
            return datetime.strptime(date_str.strip(), "%Y.%m.%d")
        else:
            return now
    except Exception as e:
        logger.error(f"날짜 파싱 오류: {e}")
        return datetime.now(pytz.timezone('Asia/Seoul'))


def crawl_site(site_name):
    """
    지정된 사이트에서 뉴스 크롤링
    
    Args:
        site_name (str): 사이트 이름
        
    Returns:
        list: 수집된 뉴스 리스트
    """
    site_info = SITES.get(site_name)
    if not site_info:
        logger.error(f"알 수 없는 사이트: {site_name}")
        return []
    
    logger.info(f"{site_name} 크롤링 시작...")
    
    try:
        url = site_info['url']
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        }
        # Selenium을 사용할 사이트 분기
        if site_name in ['coinreaders', 'bloomingbit']:
            options = Options()
            options.add_argument('--headless')
            options.add_argument('--no-sandbox')
            options.add_argument('--disable-dev-shm-usage')
            options.add_argument('--disable-gpu')
            # Chromium 사용
            service = Service('/usr/bin/chromedriver')
            driver = webdriver.Chrome(service=service, options=options)
            driver.get(url)
            time.sleep(3)  # JS 렌더링 대기
            html = driver.page_source
            driver.quit()
            soup = BeautifulSoup(html, 'lxml')
        else:
            response = requests.get(url, headers=headers)
            response.raise_for_status()
            soup = BeautifulSoup(response.text, 'lxml')
        articles = soup.select(site_info['article_selector'])
        
        news_list = []
        for article in articles[:10]:  # 최신 10개만 가져오기
            try:
                title_elem = article.select_one(site_info['title_selector'])
                link_elem = article.select_one(site_info['link_selector'])
                date_elem = article.select_one(site_info['date_selector'])
                
                if not title_elem or not link_elem:
                    continue
                
                title = title_elem.get_text().strip()
                link = link_elem.get('href', '')
                
                # 상대경로인 경우 base_url 추가
                if link and not link.startswith(('http://', 'https://')):
                    link = site_info['base_url'] + link
                
                date_str = date_elem.get_text().strip() if date_elem else ""
                published_at = parse_date(date_str, site_name)
                
                # 뉴스 본문 가져오기
                content = ""
                image_url = ""
                if link:
                    try:
                        # 본문도 Selenium으로 접근 필요 (coinreaders, bloomingbit)
                        if site_name in ['coinreaders', 'bloomingbit']:
                            options = Options()
                            options.add_argument('--headless')
                            options.add_argument('--no-sandbox')
                            options.add_argument('--disable-dev-shm-usage')
                            options.add_argument('--disable-gpu')
                            # Chromium 사용
                            service = Service('/usr/bin/chromedriver')
                            driver = webdriver.Chrome(service=service, options=options)
                            driver.get(link)
                            time.sleep(2)
                            article_html = driver.page_source
                            driver.quit()
                            article_soup = BeautifulSoup(article_html, 'lxml')
                        else:
                            article_response = requests.get(link, headers=headers)
                            article_response.raise_for_status()
                            article_soup = BeautifulSoup(article_response.text, 'lxml')
                        for selector in site_info.get('content_selector', []):
                            content_elem = article_soup.select_one(selector)
                            if content_elem:
                                content = content_elem.get_text().strip()
                                break
                        og_image = article_soup.find('meta', property='og:image')
                        if og_image and og_image.get('content'):
                            image_url = og_image.get('content')
                        else:
                            img_elem = (
                                article_soup.select_one('.view-cont img') or
                                article_soup.select_one('.entry-content img') or
                                article_soup.select_one('.post-content img')
                            )
                            if img_elem and img_elem.get('src'):
                                image_url = img_elem.get('src')
                    except Exception as e:
                        logger.warning(f"본문/이미지 가져오기 실패: {link}, 오류: {e}")
                
                # 관련 코인 태깅
                related_coins = get_related_coins(title, content)
                
                news = {
                    'title': title,
                    'content': content[:500] + ('...' if len(content) > 500 else ''),  # 미리보기 500자로 제한
                    'url': link,
                    'source': site_name,
                    'published_at': published_at.isoformat(),
                    'related_coins': related_coins,
                    'crawled_at': datetime.now().isoformat(),
                    'imageUrl': image_url  # 대표 이미지 필드 추가
                }
                
                news_list.append(news)
                logger.info(f"수집 완료: {title}")
                
            except Exception as e:
                logger.error(f"기사 파싱 오류: {e}")
                continue
        
        logger.info(f"{site_name} 크롤링 완료: {len(news_list)}개 수집")
        return news_list
        
    except Exception as e:
        logger.error(f"{site_name} 크롤링 오류: {e}")
        return []


def save_to_shared(news_list):
    """
    수집된 뉴스를 공유 디렉토리에 저장
    
    Args:
        news_list (list): 뉴스 리스트
    """
    if not news_list:
        logger.warning("저장할 뉴스가 없습니다.")
        return
    
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    output_file = os.path.join(SHARED_DIR, f'crawled_news_{timestamp}.json')
    
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(news_list, f, ensure_ascii=False, indent=2)
        logger.info(f"뉴스 저장 완료: {output_file}")
    except Exception as e:
        logger.error(f"파일 저장 오류: {e}")


def main():
    """메인 함수"""
    logger.info("뉴스 크롤러 시작 (6시간마다 1회 실행)")

    while True:
        # 각 사이트 크롤링
        all_news = []
        for site_name in SITES.keys():
            site_news = crawl_site(site_name)
            all_news.extend(site_news)
            time.sleep(2)  # 사이트 간 딜레이

        # 수집된 뉴스 저장
        save_to_shared(all_news)

        logger.info("크롤링 및 저장 완료. 6시간 대기 후 재실행")
        time.sleep(60 * 60 * 6)  # 6시간 대기


if __name__ == "__main__":
    main() 