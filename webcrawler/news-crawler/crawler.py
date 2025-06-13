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
import asyncio
from playwright.async_api import async_playwright

# 공유 디렉토리
SHARED_DIR = os.environ.get('SHARED_DIR', 'webcrawler/shared')
# 로그 디렉토리 자동 생성
os.makedirs(SHARED_DIR, exist_ok=True)

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.join(SHARED_DIR, 'crawler.log'))
    ],
    datefmt='%Y-%m-%d %H:%M:%S'
)

# 로그 시간을 KST로 변환하는 필터 클래스
class KSTFormatter(logging.Formatter):
    def converter(self, timestamp):
        dt = datetime.fromtimestamp(timestamp)
        return dt.replace(tzinfo=pytz.UTC).astimezone(pytz.timezone('Asia/Seoul'))
        
    def formatTime(self, record, datefmt=None):
        dt = self.converter(record.created)
        if datefmt:
            return dt.strftime(datefmt)
        else:
            return dt.strftime('%Y-%m-%d %H:%M:%S')

# KST 포맷터 적용
for handler in logging.getLogger().handlers:
    handler.setFormatter(KSTFormatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s', datefmt='%Y-%m-%d %H:%M:%S'))

logger = logging.getLogger(__name__)

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


# (구) Selenium/동기 기반 크롤러 함수는 더 이상 사용하지 않으므로 완전히 주석 처리 또는 삭제
# def crawl_site(site_name):
#     ...
#     (기존 동기 크롤러 코드)
#     ...


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


async def main_async():
    """
    Playwright 기반 비동기 메인 함수 (모든 사이트 크롤링)
    """
    logger.info("[Playwright] 뉴스 크롤러 시작 (6시간마다 1회 실행)")
    while True:
        all_news = []
        # 각 사이트별 Playwright 크롤러 호출
        blockmedia_news = await crawl_blockmedia_playwright()
        all_news.extend(blockmedia_news)
        await asyncio.sleep(2)
        coinreaders_news = await crawl_coinreaders_playwright()
        all_news.extend(coinreaders_news)
        await asyncio.sleep(2)
        digitaltoday_news = await crawl_digitaltoday_playwright()
        all_news.extend(digitaltoday_news)
        # 수집된 뉴스 저장
        save_to_shared(all_news)
        logger.info("[Playwright] 크롤링 및 저장 완료. 2시간 대기 후 재실행")
        await asyncio.sleep(60 * 60 * 2)  # 2시간 대기


def get_playwright_browser():
    """
    Playwright 브라우저 객체 생성 (headless, user-agent 등 옵션 적용)
    """
    return async_playwright()

async def crawl_blockmedia_playwright():
    """
    Playwright 기반 blockmedia 뉴스 크롤러 (최신 10개)
    """
    site_info = SITES['blockmedia']
    url = site_info['url']
    news_list = []
    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            context = await browser.new_context(
                user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
            )
            page = await context.new_page()
            await page.goto(url, timeout=40000, wait_until="domcontentloaded")
            await page.wait_for_timeout(3000)  # 3초 대기
            html = await page.content()
            # 디버깅용: HTML 저장
            try:
                with open(os.path.join(SHARED_DIR, 'blockmedia_debug_playwright.html'), 'w', encoding='utf-8') as f:
                    f.write(html)
            except Exception as e:
                logger.warning(f"blockmedia HTML 저장 실패: {e}")
            soup = BeautifulSoup(html, 'lxml')
            articles = soup.select(site_info['article_selector'])
            for article in articles[:10]:
                try:
                    title_elem = article.select_one(site_info['title_selector'])
                    link_elem = article.select_one(site_info['link_selector'])
                    date_elem = article.select_one(site_info['date_selector'])
                    if not title_elem or not link_elem:
                        continue
                    title = title_elem.get_text().strip()
                    link = link_elem.get('href', '')
                    # 상대경로 처리
                    if link and not link.startswith(('http://', 'https://')):
                        link = site_info['base_url'] + link
                    date_str = date_elem.get_text().strip() if date_elem else ""
                    published_at = parse_date(date_str, 'blockmedia')
                    # 본문/이미지 추출
                    content = ""
                    image_url = ""
                    if link:
                        try:
                            detail_page = await context.new_page()
                            await detail_page.goto(link, timeout=40000, wait_until="domcontentloaded")
                            await detail_page.wait_for_timeout(2000)
                            detail_html = await detail_page.content()
                            detail_soup = BeautifulSoup(detail_html, 'lxml')
                            # 본문 추출
                            for selector in site_info.get('content_selector', []):
                                content_elem = detail_soup.select_one(selector)
                                if content_elem:
                                    content = content_elem.get_text().strip()
                                    break
                            # 이미지 추출 (og:image 우선)
                            og_image = detail_soup.find('meta', property='og:image')
                            if og_image and og_image.get('content'):
                                image_url = og_image.get('content')
                            await detail_page.close()
                        except Exception as e:
                            logger.warning(f"blockmedia 본문/이미지 추출 실패: {link}, 오류: {e}")
                    # 관련 코인 태깅
                    related_coins = get_related_coins(title, content)
                    news = {
                        'title': title,
                        'content': content[:500] + ('...' if len(content) > 500 else ''),
                        'url': link,
                        'source': 'blockmedia',
                        'published_at': published_at.isoformat(),
                        'related_coins': related_coins,
                        'crawled_at': datetime.now(pytz.timezone('Asia/Seoul')).isoformat(),
                        'imageUrl': image_url
                    }
                    news_list.append(news)
                    logger.info(f"[Playwright] blockmedia 수집 완료: {title}")
                except Exception as e:
                    logger.error(f"[Playwright] blockmedia 기사 파싱 오류: {e}")
                    continue
            await browser.close()
        logger.info(f"[Playwright] blockmedia 크롤링 완료: {len(news_list)}개 수집")
        return news_list
    except Exception as e:
        logger.error(f"[Playwright] blockmedia 크롤링 오류: {e}")
        return []

# (테스트용) 아래와 같이 실행 가능:
# asyncio.run(crawl_blockmedia_playwright())

async def crawl_coinreaders_playwright():
    """
    Playwright 기반 coinreaders 뉴스 크롤러 (최신 10개)
    """
    site_info = SITES['coinreaders']
    url = site_info['url']
    news_list = []
    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            context = await browser.new_context(
                user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
            )
            page = await context.new_page()
            await page.goto(url, timeout=30000)
            await page.wait_for_timeout(3000)
            html = await page.content()
            soup = BeautifulSoup(html, "lxml")
            articles = soup.select('ul.type2 > li')
            for article in articles[:10]:
                try:
                    title_elem = article.select_one('h4.titles > a')
                    title = title_elem.get_text().strip() if title_elem else ''
                    link = title_elem['href'] if title_elem else ''
                    if link and not link.startswith('http'):
                        link = site_info['base_url'] + link
                    date_elem = article.select_one('span.byline > em')
                    date_str = date_elem.get_text().strip() if date_elem else ""
                    published_at = parse_date(date_str, 'coinreaders')
                    # 상세 페이지 진입 및 본문/이미지/작성자/카테고리 추출
                    detail_page = await context.new_page()
                    await detail_page.goto(link, timeout=40000, wait_until="domcontentloaded")
                    detail_html = await detail_page.content()
                    detail_soup = BeautifulSoup(detail_html, "lxml")
                    # 제목
                    detail_title_elem = detail_soup.select_one('h1.read_title, h2.read_title')
                    detail_title = detail_title_elem.get_text(strip=True) if detail_title_elem else title
                    # 작성자
                    writer_elem = detail_soup.select_one('.writer_time .writer')
                    writer = writer_elem.get_text(strip=True) if writer_elem else ''
                    # 날짜 (입력: 또는 기사입력 모두 대응)
                    date_elem = detail_soup.select_one('.writer_time')
                    detail_date_str = ''
                    if date_elem:
                        import re
                        m = re.search(r'(입력|기사입력)\s*:?\s*([\d/]+\s*\[\d+:\d+\])', date_elem.get_text())
                        if m:
                            detail_date_str = m.group(2)
                    # 본문 (p 태그만)
                    content_elem = detail_soup.select_one('#textinput')
                    if content_elem:
                        paragraphs = [p.get_text(strip=True) for p in content_elem.find_all('p') if p.get_text(strip=True)]
                        content = '\n'.join(paragraphs)
                    else:
                        content = ''
                    # 대표 이미지 (절대경로 변환)
                    img_elem = content_elem.select_one('img') if content_elem else None
                    img_url = ''
                    if img_elem and img_elem.get('src'):
                        img_url = img_elem['src']
                        if img_url.startswith('//'):
                            img_url = 'https:' + img_url
                        elif img_url.startswith('/'):
                            img_url = 'https://www.coinreaders.com' + img_url
                    elif detail_soup.find('meta', property='og:image'):
                        img_url = detail_soup.find('meta', property='og:image')['content']
                        if img_url.startswith('//'):
                            img_url = 'https:' + img_url
                        elif img_url.startswith('/'):
                            img_url = 'https://www.coinreaders.com' + img_url
                    elif detail_soup.find('link', rel='image_src'):
                        img_url = detail_soup.find('link', rel='image_src')['href']
                        if img_url.startswith('//'):
                            img_url = 'https:' + img_url
                        elif img_url.startswith('/'):
                            img_url = 'https://www.coinreaders.com' + img_url
                    # 카테고리
                    category_elem = detail_soup.select_one('.section_arae a')
                    category = category_elem.get_text(strip=True) if category_elem else ''
                    # 크롤링 시각(한국시간) 추가
                    crawled_at = datetime.now(pytz.timezone('Asia/Seoul')).isoformat()
                    # 뉴스 dict 생성 (crawled_at 포함)
                    news_list.append({
                        'title': detail_title,
                        'url': link,
                        'published_at': detail_date_str or date_str,
                        'writer': writer,
                        'content': content,
                        'image_url': img_url,
                        'category': category,
                        'crawled_at': crawled_at  # 크롤링 시각(한국시간)
                    })
                    await detail_page.close()
                except Exception as e:
                    logger.error(f"[Playwright] coinreaders 기사 파싱 오류: {e}")
            await browser.close()
    except Exception as e:
        logger.error(f"[Playwright] coinreaders 크롤링 오류: {e}")
    return news_list

# (테스트용) 아래와 같이 실행 가능:
# asyncio.run(crawl_coinreaders_playwright())

async def crawl_digitaltoday_playwright():
    """
    Playwright 기반 digitaltoday 뉴스 크롤러 (최신 10개)
    """
    site_info = SITES['digitaltoday']
    url = site_info['url']
    news_list = []
    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            context = await browser.new_context(
                user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
            )
            page = await context.new_page()
            await page.goto(url, timeout=40000, wait_until="domcontentloaded")
            await page.wait_for_timeout(3000)  # 3초 대기
            html = await page.content()
            # 디버깅용: HTML 저장
            try:
                with open(os.path.join(SHARED_DIR, 'digitaltoday_debug_playwright.html'), 'w', encoding='utf-8') as f:
                    f.write(html)
            except Exception as e:
                logger.warning(f"digitaltoday HTML 저장 실패: {e}")
            soup = BeautifulSoup(html, 'lxml')
            articles = soup.select('ul.type2 > li')
            for article in articles[:10]:
                try:
                    title_elem = article.select_one('h4.titles > a')
                    title = title_elem.get_text().strip() if title_elem else ''
                    link = title_elem['href'] if title_elem else ''
                    if link and not link.startswith('http'):
                        link = site_info['base_url'] + link
                    date_elem = article.select_one('span.byline > em')
                    date_str = date_elem.get_text().strip() if date_elem else ""
                    published_at = parse_date(date_str, 'digitaltoday')
                    # 본문/이미지 추출
                    content = ""
                    image_url = ""
                    if link:
                        try:
                            detail_page = await context.new_page()
                            await detail_page.goto(link, timeout=40000, wait_until="domcontentloaded")
                            await detail_page.wait_for_timeout(2000)
                            detail_html = await detail_page.content()
                            detail_soup = BeautifulSoup(detail_html, 'lxml')
                            # 본문 추출
                            content_elem = detail_soup.select_one('#article-view-content-div, .article, .view-content')
                            content = content_elem.get_text().strip() if content_elem else ""
                            # 이미지 추출
                            img_elem = detail_soup.select_one('#article-view-content-div img, .article img')
                            if img_elem and img_elem.get('src'):
                                image_url = img_elem['src']
                            else:
                                og_image = detail_soup.find('meta', property='og:image')
                                if og_image and og_image.get('content'):
                                    image_url = og_image['content']
                            await detail_page.close()
                        except Exception as e:
                            logger.warning(f"digitaltoday 본문/이미지 추출 실패: {link}, 오류: {e}")
                    # 관련 코인 태깅
                    related_coins = get_related_coins(title, content)
                    news = {
                        'title': title,
                        'content': content[:500] + ('...' if len(content) > 500 else ''),
                        'url': link,
                        'source': 'digitaltoday',
                        'published_at': published_at.isoformat(),
                        'related_coins': related_coins,
                        'crawled_at': datetime.now(pytz.timezone('Asia/Seoul')).isoformat(),
                        'imageUrl': image_url
                    }
                    news_list.append(news)
                    logger.info(f"[Playwright] digitaltoday 수집 완료: {title}")
                except Exception as e:
                    logger.error(f"[Playwright] digitaltoday 기사 파싱 오류: {e}")
                    continue
            await browser.close()
        logger.info(f"[Playwright] digitaltoday 크롤링 완료: {len(news_list)}개 수집")
        return news_list
    except Exception as e:
        logger.error(f"[Playwright] digitaltoday 크롤링 오류: {e}")
        return []

# (테스트용) 아래와 같이 실행 가능:
# asyncio.run(crawl_digitaltoday_playwright())

if __name__ == "__main__":
    # Playwright 기반 비동기 크롤러만 실행
    asyncio.run(main_async()) 