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
        'article_selector': '.sub_read_list_box',
        'title_selector': 'dl dt a',
        'link_selector': 'dl dt a',
        'date_selector': 'dd.etc',
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
        'article_selector': 'section#section-list ul.type2 > li',
        'title_selector': 'h4.titles a',
        'link_selector': 'h4.titles a',
        'date_selector': 'span.byline em',
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
        datetime: 파싱된 날짜 (KST 시간대 정보 포함)
    """
    try:
        now = datetime.now(pytz.timezone('Asia/Seoul'))
        
        if site == 'blockmedia':
            # "2023-06-25 08:30:45" 또는 "2023-06-25 08:30"
            try:
                dt = datetime.strptime(date_str.strip(), "%Y-%m-%d %H:%M:%S")
                return pytz.timezone('Asia/Seoul').localize(dt)
            except ValueError:
                dt = datetime.strptime(date_str.strip(), "%Y-%m-%d %H:%M")
                return pytz.timezone('Asia/Seoul').localize(dt)
        elif site == 'coinreaders':
            # 예: "홍길동 기자 | 2025.06.11 12:40"
            try:
                # 날짜 부분만 추출하기
                date_part = date_str.strip().split('|')[-1].strip()
                dt = datetime.strptime(date_part, "%Y.%m.%d %H:%M")
                return pytz.timezone('Asia/Seoul').localize(dt)
            except Exception as e:
                logger.warning(f"코인리더스 날짜 파싱 오류: {e}, 원본: {date_str}")
                return datetime.now(pytz.timezone('Asia/Seoul'))
        elif site == 'bloomingbit':
            # 예: "2023.06.25"
            dt = datetime.strptime(date_str.strip(), "%Y.%m.%d")
            return pytz.timezone('Asia/Seoul').localize(dt)
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
        options = Options()
        options.add_argument('--headless')
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        options.add_argument('--disable-gpu')
        service = Service('/usr/bin/chromedriver')
        driver = webdriver.Chrome(service=service, options=options)
        driver.get(url)
        time.sleep(3)
        html = driver.page_source
        # 디버깅용: HTML 저장
        try:
            with open(f'/app/shared/{site_name}_debug.html', 'w', encoding='utf-8') as f:
                f.write(html)
        except Exception as e:
            logger.warning(f"{site_name} HTML 저장 실패: {e}")
        driver.quit()
        soup = BeautifulSoup(html, 'lxml')
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
                    # 코인리더스의 경우 /숫자 형태로 링크가 제공됨 (예: /165823)
                    if site_name == 'coinreaders' and link.startswith('/'):
                        link = site_info['base_url'] + link
                    else:
                        link = site_info['base_url'] + link
                
                date_str = date_elem.get_text().strip() if date_elem else ""
                published_at = parse_date(date_str, site_name)
                
                # 뉴스 본문 가져오기
                content = ""
                image_url = ""
                if link:
                    try:
                        # 본문도 Selenium으로 접근
                        options = Options()
                        options.add_argument('--headless')
                        options.add_argument('--no-sandbox')
                        options.add_argument('--disable-dev-shm-usage')
                        options.add_argument('--disable-gpu')
                        service = Service('/usr/bin/chromedriver')
                        driver = webdriver.Chrome(service=service, options=options)
                        driver.get(link)
                        time.sleep(2)
                        article_html = driver.page_source
                        driver.quit()
                        article_soup = BeautifulSoup(article_html, 'lxml')
                        # 사이트별 본문 추출 로직
                        if site_name == 'coinreaders':
                            # 코인리더스는 특별한 처리가 필요함
                            content_elem = article_soup.select_one('#article-view-content-div')
                            if content_elem:
                                content = content_elem.get_text().strip()
                        else:
                            # 다른 사이트는 기존 방식 사용
                            for selector in site_info.get('content_selector', []):
                                content_elem = article_soup.select_one(selector)
                                if content_elem:
                                    content = content_elem.get_text().strip()
                                    break
                        # 이미지 URL 추출
                        if site_name == 'coinreaders':
                            # 코인리더스는 기사 내부 이미지 찾기
                            img_elem = article_soup.select_one('.article img')
                            if img_elem and img_elem.get('src'):
                                image_url = img_elem.get('src')
                                if not image_url.startswith(('http://', 'https://')):
                                    image_url = site_info['base_url'] + image_url
                            # 이미지를 못 찾으면 og:image 사용
                            if not image_url:
                                og_image = article_soup.find('meta', property='og:image')
                                if og_image and og_image.get('content'):
                                    image_url = og_image.get('content')
                        else:
                            # 다른 사이트는 기존 방식 사용
                            og_image = article_soup.find('meta', property='og:image')
                            if og_image and og_image.get('content'):
                                image_url = og_image.get('content')
                    except Exception as e:
                        logger.warning(f"본문/이미지 가져오기 실패: {link}, 오류: {e}")
                
                # 관련 코인 태깅
                related_coins = get_related_coins(title, content)
                
                news = {
                    'title': title,
                    'content': content[:500] + ('...' if len(content) > 500 else ''),
                    'url': link,
                    'source': site_name,
                    'published_at': published_at.isoformat(),
                    'related_coins': related_coins,
                    'crawled_at': datetime.now(pytz.timezone('Asia/Seoul')).isoformat(),
                    'imageUrl': image_url
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
    
    timestamp = datetime.now(pytz.timezone('Asia/Seoul')).strftime("%Y%m%d%H%M%S")
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