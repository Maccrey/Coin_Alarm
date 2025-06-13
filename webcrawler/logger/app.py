#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
로깅 서비스
- 로그 수집 및 조회 API
- 간단한 대시보드 제공
"""

import os
import json
import logging
from datetime import datetime, timedelta
import pytz
from flask import Flask, request, jsonify, render_template, send_from_directory
from flask_cors import CORS
import requests

app = Flask(__name__)
CORS(app)

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/app/logs/logger.log')
    ]
)
logger = logging.getLogger(__name__)

# 공유 디렉토리
SHARED_DIR = '/app/shared'
LOGS_DIR = '/app/logs'

# 로그 파일 목록
LOG_FILES = {
    'crawler': '/app/shared/crawler.log',
    'cleaner': '/app/shared/cleaner.log',
    'writer': '/app/shared/writer.log',
    'scheduler': '/app/shared/scheduler.log',
    'logger': '/app/logs/logger.log'
}

# 서비스 목록
SERVICES = [
    {"name": "news-crawler", "url": "http://news-crawler:5000/health"},
    {"name": "news-cleaner", "url": "http://news-cleaner:5000/health"},
    {"name": "news-writer", "url": "http://news-writer:5000/health"},
    {"name": "scheduler", "url": "http://scheduler:5000/health"}
]


# 헬스 체크 엔드포인트
@app.route('/health', methods=['GET'])
def health_check():
    """서비스 헬스 체크"""
    return jsonify({"status": "ok", "service": "logger"})


# 로그 파일 목록 조회
@app.route('/api/logs', methods=['GET'])
def get_log_files():
    """로그 파일 목록 조회"""
    return jsonify({
        "status": "ok",
        "log_files": list(LOG_FILES.keys())
    })


# 로그 조회
@app.route('/api/logs/<service>', methods=['GET'])
def get_logs(service):
    """
    특정 서비스의 로그 조회
    
    Args:
        service (str): 서비스 이름
        
    Returns:
        JSON: 로그 데이터
    """
    if service not in LOG_FILES:
        return jsonify({"status": "error", "message": "서비스를 찾을 수 없습니다."}), 404
    
    log_file = LOG_FILES[service]
    
    # 최대 라인 수 (기본값: 100)
    lines = request.args.get('lines', default=100, type=int)
    
    try:
        if os.path.exists(log_file):
            with open(log_file, 'r', encoding='utf-8') as f:
                all_lines = f.readlines()
                log_data = all_lines[-lines:] if lines < len(all_lines) else all_lines
            
            return jsonify({
                "status": "ok",
                "service": service,
                "logs": log_data,
                "total_lines": len(all_lines),
                "showing_lines": len(log_data)
            })
        else:
            return jsonify({"status": "error", "message": "로그 파일이 존재하지 않습니다."}), 404
    
    except Exception as e:
        logger.error(f"로그 조회 오류: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500


# 서비스 상태 조회
@app.route('/api/status', methods=['GET'])
def get_services_status():
    """
    모든 서비스의 상태 조회
    
    Returns:
        JSON: 서비스 상태 데이터
    """
    status_data = []
    
    for service in SERVICES:
        try:
            response = requests.get(service["url"], timeout=3)
            status = "ok" if response.status_code == 200 else "error"
        except Exception:
            status = "error"
        
        status_data.append({
            "name": service["name"],
            "status": status,
            "checked_at": datetime.now(pytz.timezone('Asia/Seoul')).isoformat()
        })
    
    return jsonify({
        "status": "ok",
        "services": status_data
    })


# 로그 메시지 추가
@app.route('/api/log', methods=['POST'])
def add_log():
    """
    로그 메시지 추가
    
    Request Body:
        {
            "service": "서비스 이름",
            "level": "로그 레벨 (info, warning, error)",
            "message": "로그 메시지"
        }
        
    Returns:
        JSON: 성공 여부
    """
    data = request.json
    
    service = data.get('service')
    level = data.get('level', 'info')
    message = data.get('message')
    
    if not service or not message:
        return jsonify({"status": "error", "message": "필수 필드 누락"}), 400
    
    try:
        # 로그 메시지 형식 생성
        timestamp = datetime.now(pytz.timezone('Asia/Seoul')).strftime('%Y-%m-%d %H:%M:%S')
        log_message = f"{timestamp} - {service} - {level.upper()} - {message}\n"
        
        # 서비스별 로그 파일에 기록
        if service in LOG_FILES:
            log_file = LOG_FILES[service]
        else:
            log_file = '/app/logs/other.log'
        
        with open(log_file, 'a', encoding='utf-8') as f:
            f.write(log_message)
        
        return jsonify({"status": "ok"})
    
    except Exception as e:
        logger.error(f"로그 추가 오류: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500


# 대시보드 메인 페이지
@app.route('/')
def index():
    """
    전문가용 실시간 대시보드 (HTML+JS)
    - 크롤링 마지막 시간, 다음 크롤링 예정 시간
    - 최근 크롤링 뉴스, Supabase 저장 뉴스, 서비스 상태, 에러/경고 등 시각화
    - 한글 UI, 전문가용 스타일
    """
    html = """
    <!DOCTYPE html>
    <html lang='ko'>
    <head>
        <title>암호화폐 뉴스 실시간 대시보드</title>
        <meta charset='UTF-8'>
        <meta name='viewport' content='width=device-width, initial-scale=1.0'>
        <style>
            body { font-family: 'Pretendard', 'Noto Sans KR', Arial, sans-serif; margin: 0; padding: 24px; background: #f7f9fa; }
            h1 { color: #222; margin-bottom: 8px; }
            h2 { color: #2a5d9f; margin-top: 32px; margin-bottom: 8px; }
            .section { background: #fff; border-radius: 10px; box-shadow: 0 2px 8px #0001; margin-bottom: 32px; padding: 24px; }
            table { width: 100%; border-collapse: collapse; margin-top: 8px; margin-bottom: 16px; }
            th, td { padding: 8px 10px; border-bottom: 1px solid #e3e6ea; text-align: left; font-size: 15px; }
            th { background: #f0f4fa; color: #1a3a5e; font-weight: 600; }
            tr:last-child td { border-bottom: none; }
            .error { color: #c0392b; font-weight: bold; background: #fff0f0; }
            .warn { color: #b9770e; font-weight: bold; background: #fffbe6; }
            .ok { color: #27ae60; font-weight: bold; }
            .status { padding: 4px 10px; border-radius: 4px; font-size: 13px; display: inline-block; }
            .status.ok { background: #eafaf1; color: #27ae60; }
            .status.error { background: #fff0f0; color: #c0392b; }
            .status.warning { background: #fffbe6; color: #b9770e; }
            .mono { font-family: 'Fira Mono', 'Menlo', 'Consolas', monospace; font-size: 13px; }
            .highlight { background: #eaf6ff; }
            .flex-row { display: flex; gap: 24px; }
            .flex-col { flex: 1; }
            .img-thumb { width: 48px; height: 48px; object-fit: cover; border-radius: 6px; border: 1px solid #e3e6ea; }
            .center { text-align: center; }
            @media (max-width: 900px) { .flex-row { flex-direction: column; } }
        </style>
    </head>
    <body>
        <h1>암호화폐 뉴스 실시간 대시보드</h1>
        <div class='section' id='summary'>
            <h2>크롤링 현황 요약</h2>
            <div id='crawl-summary'>로딩 중...</div>
        </div>
        <div class='section' id='service-status'>
            <h2>서비스 상태</h2>
            <div id='services'>로딩 중...</div>
        </div>
        <div class='section'>
            <div class='flex-row'>
                <div class='flex-col'>
                    <h2>최근 크롤링 뉴스 (최신 20건)</h2>
                    <table id='news-table'>
                        <thead>
                            <tr><th>시간</th><th>출처</th><th>제목</th><th>대표 이미지</th></tr>
                        </thead>
                        <tbody><tr><td colspan='4'>로딩 중...</td></tr></tbody>
                    </table>
                </div>
                <div class='flex-col'>
                    <h2>Supabase 저장 뉴스 (최신 20건)</h2>
                    <table id='save-table'>
                        <thead>
                            <tr><th>시간</th><th>제목</th><th>관련 코인</th><th>대표 이미지</th></tr>
                        </thead>
                        <tbody><tr><td colspan='4'>로딩 중...</td></tr></tbody>
                    </table>
                </div>
            </div>
        </div>
        <div class='section'>
            <h2>에러/경고 내역 (최신 20건)</h2>
            <table id='err-table'>
                <thead>
                    <tr><th>시간</th><th>서비스</th><th>레벨</th><th>메시지</th></tr>
                </thead>
                <tbody><tr><td colspan='4'>로딩 중...</td></tr></tbody>
            </table>
        </div>
        <script>
        // 크롤링 현황 요약(마지막/다음 시간) 계산 및 표시
        fetch('/api/logs/crawler?lines=200')
            .then(r => r.json())
            .then(data => {
                // 마지막 "수집 완료" 라인 추출
                const last = data.logs.filter(line => line.includes('수집 완료')).pop();
                let lastTime = '-', nextTime = '-';
                if (last) {
                    const m = last.match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),\d+ -/);
                    if (m) {
                        lastTime = m[1];
                        // 2시간 주기라 가정
                        const dt = new Date(lastTime.replace(/-/g,'/'));
                        dt.setHours(dt.getHours() + 2);
                        nextTime = dt.toLocaleString('ko-KR');
                    }
                }
                document.getElementById('crawl-summary').innerHTML = `<b>마지막 크롤링 시간:</b> <span class='highlight'>${lastTime}</span> &nbsp; <b>다음 예정 시간:</b> <span class='highlight'>${nextTime}</span>`;
            })
            .catch(() => { document.getElementById('crawl-summary').innerHTML = '오류: 정보를 불러올 수 없습니다.'; });

        // 서비스 상태 로드
        fetch('/api/status')
            .then(r => r.json())
            .then(data => {
                const s = data.services.map(svc => `<span class='status ${svc.status}'>${svc.name}: ${svc.status.toUpperCase()}<br><span style='font-size:12px;color:#888'>${new Date(svc.checked_at).toLocaleString('ko-KR')}</span></span>`).join(' ');
                document.getElementById('services').innerHTML = s;
            })
            .catch(() => { document.getElementById('services').innerHTML = '오류: 상태 정보를 불러올 수 없습니다.'; });

        // 최근 크롤링 뉴스(crawler.log) 파싱 및 표 렌더링
        fetch('/api/logs/crawler?lines=200')
            .then(r => r.json())
            .then(data => {
                // "수집 완료: ..." 라인만 추출
                const rows = data.logs.filter(line => line.includes('수집 완료')).slice(-20).reverse();
                const parsed = rows.map(line => {
                    // 예시: 2025-06-11 04:17:57,647 - __main__ - INFO - 수집 완료: 고물가에 무너지는 XRP 꿈...99%는 버티지 못하는 현실
                    const m = line.match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),\d+ - [^ ]+ - [^ ]+ - 수집 완료: (.+)$/);
                    if (!m) return null;
                    let title = m[2];
                    let source = '-';
                    if (title.includes('디지털투데이')) source = 'digitaltoday';
                    else if (title.includes('코인리더스') || title.includes('XRP') || title.includes('비트코인') || title.includes('이더리움') || title.includes('솔라나')) source = 'coinreaders';
                    else if (title.includes('블록미디어') || title.includes('blockmedia')) source = 'blockmedia';
                    // 대표이미지 추정 불가시 '-'
                    return { time: m[1], source, title, img: '-' };
                }).filter(Boolean);
                const html = parsed.length ? parsed.map(r => `<tr><td>${r.time}</td><td>${r.source}</td><td class='mono'>${r.title}</td><td class='center'>${r.img==='-'?'-':`<img src='${r.img}' class='img-thumb'>`}</td></tr>`).join('') : `<tr><td colspan='4'>데이터 없음</td></tr>`;
                document.querySelector('#news-table tbody').innerHTML = html;
            })
            .catch(() => { document.querySelector('#news-table tbody').innerHTML = `<tr><td colspan='4'>오류</td></tr>`; });

        // Supabase 저장 뉴스(writer.log) 파싱 및 표 렌더링
        fetch('/api/logs/writer?lines=200')
            .then(r => r.json())
            .then(data => {
                // "뉴스 저장 성공: ..." 라인만 추출
                const rows = data.logs.filter(line => line.includes('뉴스 저장 성공')).slice(-20).reverse();
                let result = [];
                for (let i = 0; i < data.logs.length; i++) {
                    if (data.logs[i].includes('뉴스 저장 성공')) {
                        const m = data.logs[i].match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),\d+ - [^ ]+ - [^ ]+ - 뉴스 저장 성공: (.+)$/);
                        let time = m ? m[1] : '-';
                        let title = m ? m[2] : data.logs[i];
                        let rel = '-', img = '-';
                        for (let j = i-1; j>=0 && j>=i-5; j--) {
                            if (data.logs[j].includes('뉴스 저장 요청 데이터')) {
                                try {
                                    const obj = JSON.parse(data.logs[j].split('뉴스 저장 요청 데이터:')[1].replace(/'/g,'"'));
                                    rel = obj.related_coins || '-';
                                    img = obj.image_url || '-';
                                } catch(e) {}
                                break;
                            }
                        }
                        result.push({time, title, rel, img});
                    }
                }
                result = result.slice(-20).reverse();
                const html = result.length ? result.map(r => `<tr><td>${r.time}</td><td class='mono'>${r.title}</td><td class='mono'>${r.rel}</td><td class='center'>${r.img==='-'?'-':`<img src='${r.img}' class='img-thumb'>`}</td></tr>`).join('') : `<tr><td colspan='4'>데이터 없음</td></tr>`;
                document.querySelector('#save-table tbody').innerHTML = html;
            })
            .catch(() => { document.querySelector('#save-table tbody').innerHTML = `<tr><td colspan='4'>오류</td></tr>`; });

        // 에러/경고 내역(crawler+writer) 파싱 및 표 렌더링
        Promise.all([
            fetch('/api/logs/crawler?lines=200').then(r=>r.json()),
            fetch('/api/logs/writer?lines=200').then(r=>r.json())
        ]).then(([c, w]) => {
            const errLines = c.logs.concat(w.logs).filter(line => line.includes('ERROR') || line.includes('WARNING')).slice(-20).reverse();
            const html = errLines.length ? errLines.map(line => {
                const m = line.match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),\d+ - ([^ ]+) - (ERROR|WARNING) - (.+)$/);
                if (!m) return `<tr><td colspan='4' class='warn'>${line}</td></tr>`;
                const level = m[3] === 'ERROR' ? 'error' : 'warn';
                return `<tr><td>${m[1]}</td><td>${m[2]}</td><td class='${level}'>${m[3]}</td><td class='${level}'>${m[4]}</td></tr>`;
            }).join('') : `<tr><td colspan='4'>데이터 없음</td></tr>`;
            document.querySelector('#err-table tbody').innerHTML = html;
        }).catch(() => { document.querySelector('#err-table tbody').innerHTML = `<tr><td colspan='4'>오류</td></tr>`; });
        </script>
    </body>
    </html>
    """
    return html


# 정적 파일 서빙
@app.route('/static/<path:path>')
def serve_static(path):
    """정적 파일 서빙"""
    return send_from_directory('static', path)


# 템플릿이 없을 경우를 대비한 간단한 HTML 생성
@app.route('/fallback')
def fallback_dashboard():
    """
    템플릿이 없을 경우 대체 대시보드 (전문가용)
    - 크롤링 내역, Supabase 저장 내역, 에러/경고를 표로 시각화
    - crawler.log, writer.log에서 최신 30건씩 파싱
    - 한글 UI, 컬럼명, 색상 강조, 전문가용 정보 대시보드 스타일
    """
    html = """
    <!DOCTYPE html>
    <html lang='ko'>
    <head>
        <title>암호화폐 뉴스 크롤러 모니터링 대시보드</title>
        <meta charset='UTF-8'>
        <meta name='viewport' content='width=device-width, initial-scale=1.0'>
        <style>
            body { font-family: 'Pretendard', 'Noto Sans KR', Arial, sans-serif; margin: 0; padding: 24px; background: #f7f9fa; }
            h1 { color: #222; margin-bottom: 8px; }
            h2 { color: #2a5d9f; margin-top: 32px; margin-bottom: 8px; }
            .section { background: #fff; border-radius: 10px; box-shadow: 0 2px 8px #0001; margin-bottom: 32px; padding: 24px; }
            table { width: 100%; border-collapse: collapse; margin-top: 8px; margin-bottom: 16px; }
            th, td { padding: 8px 10px; border-bottom: 1px solid #e3e6ea; text-align: left; font-size: 15px; }
            th { background: #f0f4fa; color: #1a3a5e; font-weight: 600; }
            tr:last-child td { border-bottom: none; }
            .error { color: #c0392b; font-weight: bold; background: #fff0f0; }
            .warn { color: #b9770e; font-weight: bold; background: #fffbe6; }
            .ok { color: #27ae60; font-weight: bold; }
            .status { padding: 4px 10px; border-radius: 4px; font-size: 13px; display: inline-block; }
            .status.ok { background: #eafaf1; color: #27ae60; }
            .status.error { background: #fff0f0; color: #c0392b; }
            .status.warning { background: #fffbe6; color: #b9770e; }
            .mono { font-family: 'Fira Mono', 'Menlo', 'Consolas', monospace; font-size: 13px; }
            .highlight { background: #eaf6ff; }
            .flex-row { display: flex; gap: 24px; }
            .flex-col { flex: 1; }
            @media (max-width: 900px) { .flex-row { flex-direction: column; } }
        </style>
    </head>
    <body>
        <h1>암호화폐 뉴스 크롤러 모니터링 대시보드</h1>
        <div class='section' id='service-status'>
            <h2>서비스 상태</h2>
            <div id='services'>로딩 중...</div>
        </div>
        <div class='section'>
            <div class='flex-row'>
                <div class='flex-col'>
                    <h2>최근 크롤링 내역 (최신 30건)</h2>
                    <table id='crawl-table'>
                        <thead>
                            <tr><th>시간</th><th>뉴스 출처</th><th>제목</th></tr>
                        </thead>
                        <tbody><tr><td colspan='3'>로딩 중...</td></tr></tbody>
                    </table>
                </div>
                <div class='flex-col'>
                    <h2>Supabase 저장 내역 (최신 30건)</h2>
                    <table id='save-table'>
                        <thead>
                            <tr><th>시간</th><th>제목</th><th>관련 코인</th><th>대표 이미지</th></tr>
                        </thead>
                        <tbody><tr><td colspan='4'>로딩 중...</td></tr></tbody>
                    </table>
                </div>
            </div>
        </div>
        <div class='section'>
            <h2>에러/경고 내역 (최신 30건)</h2>
            <table id='err-table'>
                <thead>
                    <tr><th>시간</th><th>서비스</th><th>레벨</th><th>메시지</th></tr>
                </thead>
                <tbody><tr><td colspan='4'>로딩 중...</td></tr></tbody>
            </table>
        </div>
        <script>
        // 서비스 상태 로드
        fetch('/api/status')
            .then(r => r.json())
            .then(data => {
                const s = data.services.map(svc => `<span class='status ${svc.status}'>${svc.name}: ${svc.status.toUpperCase()}<br><span style='font-size:12px;color:#888'>${new Date(svc.checked_at).toLocaleString('ko-KR')}</span></span>`).join(' ');
                document.getElementById('services').innerHTML = s;
            })
            .catch(() => { document.getElementById('services').innerHTML = '오류: 상태 정보를 불러올 수 없습니다.'; });

        // 크롤링 내역(crawler.log) 파싱 및 표 렌더링
        fetch('/api/logs/crawler?lines=200')
            .then(r => r.json())
            .then(data => {
                // "수집 완료: ..." 라인만 추출
                const rows = data.logs.filter(line => line.includes('수집 완료')).slice(-30).reverse();
                const parsed = rows.map(line => {
                    // 예시: 2025-06-11 04:17:57,647 - __main__ - INFO - 수집 완료: 고물가에 무너지는 XRP 꿈...99%는 버티지 못하는 현실
                    const m = line.match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),\d+ - [^ ]+ - [^ ]+ - 수집 완료: (.+)$/);
                    if (!m) return null;
                    // 출처 추출(제목에서 추정, 또는 뉴스별로 구분 불가시 "-" 처리)
                    let title = m[2];
                    let source = '-';
                    if (title.includes('디지털투데이')) source = 'digitaltoday';
                    else if (title.includes('코인리더스') || title.includes('XRP') || title.includes('비트코인') || title.includes('이더리움') || title.includes('솔라나')) source = 'coinreaders';
                    else if (title.includes('블록미디어') || title.includes('blockmedia')) source = 'blockmedia';
                    return { time: m[1], source, title };
                }).filter(Boolean);
                const html = parsed.length ? parsed.map(r => `<tr><td>${r.time}</td><td>${r.source}</td><td class='mono'>${r.title}</td></tr>`).join('') : `<tr><td colspan='3'>데이터 없음</td></tr>`;
                document.querySelector('#crawl-table tbody').innerHTML = html;
            })
            .catch(() => { document.querySelector('#crawl-table tbody').innerHTML = `<tr><td colspan='3'>오류</td></tr>`; });

        // Supabase 저장 내역(writer.log) 파싱 및 표 렌더링
        fetch('/api/logs/writer?lines=200')
            .then(r => r.json())
            .then(data => {
                // "뉴스 저장 성공: ..." 라인만 추출
                const rows = data.logs.filter(line => line.includes('뉴스 저장 성공')).slice(-30).reverse();
                // 관련 코인, 이미지 등은 직전 "뉴스 저장 요청 데이터" 라인에서 추출
                let result = [];
                for (let i = 0; i < data.logs.length; i++) {
                    if (data.logs[i].includes('뉴스 저장 성공')) {
                        // 시간, 제목
                        const m = data.logs[i].match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),\d+ - [^ ]+ - [^ ]+ - 뉴스 저장 성공: (.+)$/);
                        let time = m ? m[1] : '-';
                        let title = m ? m[2] : data.logs[i];
                        // 직전 5줄 내에서 "뉴스 저장 요청 데이터" 라인 찾기
                        let rel = '-', img = '-';
                        for (let j = i-1; j>=0 && j>=i-5; j--) {
                            if (data.logs[j].includes('뉴스 저장 요청 데이터')) {
                                try {
                                    const obj = JSON.parse(data.logs[j].split('뉴스 저장 요청 데이터:')[1].replace(/'/g,'"'));
                                    rel = obj.related_coins || '-';
                                    img = obj.image_url || '-';
                                } catch(e) {}
                                break;
                            }
                        }
                        result.push({time, title, rel, img});
                    }
                }
                result = result.slice(-30).reverse();
                const html = result.length ? result.map(r => `<tr><td>${r.time}</td><td class='mono'>${r.title}</td><td class='mono'>${r.rel}</td><td class='mono'>${r.img}</td></tr>`).join('') : `<tr><td colspan='4'>데이터 없음</td></tr>`;
                document.querySelector('#save-table tbody').innerHTML = html;
            })
            .catch(() => { document.querySelector('#save-table tbody').innerHTML = `<tr><td colspan='4'>오류</td></tr>`; });

        // 에러/경고 내역(crawler+writer) 파싱 및 표 렌더링
        Promise.all([
            fetch('/api/logs/crawler?lines=200').then(r=>r.json()),
            fetch('/api/logs/writer?lines=200').then(r=>r.json())
        ]).then(([c, w]) => {
            // 에러/경고 라인만 추출
            const errLines = c.logs.concat(w.logs).filter(line => line.includes('ERROR') || line.includes('WARNING')).slice(-30).reverse();
            const html = errLines.length ? errLines.map(line => {
                // 예시: 2025-06-11 03:05:18,144 - __main__ - ERROR - blockmedia 크롤링 오류: ...
                const m = line.match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),\d+ - ([^ ]+) - (ERROR|WARNING) - (.+)$/);
                if (!m) return `<tr><td colspan='4' class='warn'>${line}</td></tr>`;
                const level = m[3] === 'ERROR' ? 'error' : 'warn';
                return `<tr><td>${m[1]}</td><td>${m[2]}</td><td class='${level}'>${m[3]}</td><td class='${level}'>${m[4]}</td></tr>`;
            }).join('') : `<tr><td colspan='4'>데이터 없음</td></tr>`;
            document.querySelector('#err-table tbody').innerHTML = html;
        }).catch(() => { document.querySelector('#err-table tbody').innerHTML = `<tr><td colspan='4'>오류</td></tr>`; });
        </script>
    </body>
    </html>
    """
    return html


if __name__ == '__main__':
    # 필요한 디렉토리 생성
    os.makedirs(LOGS_DIR, exist_ok=True)
    
    # 로그 파일이 없으면 생성
    for log_file in LOG_FILES.values():
        if not os.path.exists(log_file):
            with open(log_file, 'w', encoding='utf-8') as f:
                f.write(f"Log file created at {datetime.now(pytz.timezone('Asia/Seoul')).isoformat()}\n")
    
    logger.info("로깅 서비스 시작")
    app.run(host='0.0.0.0', port=5000) 