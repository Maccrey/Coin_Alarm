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
    전문 데이터 분석가용 실시간 대시보드 (HTML+JS)
    - 상단 KPI 카드, 트렌드 차트, 상세 테이블, 전문가용 레이아웃
    """
    html = """
    <!DOCTYPE html>
    <html lang='ko'>
    <head>
        <title>암호화폐 뉴스 데이터 분석 대시보드</title>
        <meta charset='UTF-8'>
        <meta name='viewport' content='width=device-width, initial-scale=1.0'>
        <script src='https://cdn.jsdelivr.net/npm/chart.js'></script>
        <style>
            body { font-family: 'Pretendard', 'Noto Sans KR', Arial, sans-serif; margin: 0; padding: 0; background: #181c23; color: #e6eaf3; }
            h1 { color: #fff; margin: 0 0 16px 0; font-size: 2.2rem; }
            h2 { color: #7ecfff; margin: 32px 0 12px 0; font-size: 1.3rem; }
            .dashboard { max-width: 1200px; margin: 0 auto; padding: 32px 16px; }
            .kpi-row { display: flex; gap: 24px; margin-bottom: 32px; }
            .kpi-card { flex: 1; background: #232936; border-radius: 12px; box-shadow: 0 2px 8px #0003; padding: 24px 18px; display: flex; flex-direction: column; align-items: flex-start; }
            .kpi-label { color: #b0b8c9; font-size: 1rem; margin-bottom: 6px; }
            .kpi-value { font-size: 2.1rem; font-weight: bold; color: #7ecfff; }
            .kpi-sub { color: #b0b8c9; font-size: 0.95rem; margin-top: 4px; }
            .chart-section { background: #232936; border-radius: 12px; box-shadow: 0 2px 8px #0003; padding: 24px; margin-bottom: 32px; height: 320px; }
            .flex-row { display: flex; gap: 24px; }
            .flex-col { flex: 1; }
            .table-section { background: #232936; border-radius: 12px; box-shadow: 0 2px 8px #0003; padding: 24px; margin-bottom: 32px; }
            table { width: 100%; border-collapse: collapse; margin-top: 8px; margin-bottom: 16px; background: #232936; color: #e6eaf3; }
            th, td { padding: 8px 10px; border-bottom: 1px solid #2c3240; text-align: left; font-size: 15px; }
            th { background: #232936; color: #7ecfff; font-weight: 600; position: sticky; top: 0; z-index: 2; }
            tr:last-child td { border-bottom: none; }
            .mono { font-family: 'Fira Mono', 'Menlo', 'Consolas', monospace; font-size: 13px; }
            .center { text-align: center; }
            .search-box { background: #232936; border: 1px solid #2c3240; color: #e6eaf3; border-radius: 6px; padding: 6px 12px; margin-bottom: 8px; width: 220px; }
            .table-scroll { max-height: 340px; overflow-y: auto; }
            .status { padding: 4px 10px; border-radius: 4px; font-size: 13px; display: inline-block; }
            .status.ok { background: #1e3a2e; color: #7ecfff; }
            .status.error { background: #3a1e1e; color: #ff7e7e; }
            .status.warning { background: #3a2e1e; color: #ffe07e; }
            @media (max-width: 900px) { .kpi-row, .flex-row { flex-direction: column; } }
        </style>
    </head>
    <body>
    <div class='dashboard'>
        <h1>암호화폐 뉴스 데이터 분석 대시보드</h1>
        <!-- KPI 카드 -->
        <div class='kpi-row' id='kpi-row'>
            <div class='kpi-card'><div class='kpi-label'>전체 크롤링</div><div class='kpi-value' id='kpi-crawl'>-</div><div class='kpi-sub'>건</div></div>
            <div class='kpi-card'><div class='kpi-label'>Supabase 저장</div><div class='kpi-value' id='kpi-save'>-</div><div class='kpi-sub'>건</div></div>
            <div class='kpi-card'><div class='kpi-label'>에러/경고</div><div class='kpi-value' id='kpi-err'>-</div><div class='kpi-sub'>건</div></div>
            <div class='kpi-card'><div class='kpi-label'>성공률</div><div class='kpi-value' id='kpi-success'>-</div><div class='kpi-sub'>%</div></div>
            <div class='kpi-card'><div class='kpi-label'>마지막 크롤링</div><div class='kpi-value' id='kpi-last-crawl'>-</div><div class='kpi-sub' id='kpi-next-crawl'></div></div>
        </div>
        <!-- 트렌드 차트 -->
        <div class='chart-section'>
            <h2>최근 24시간 크롤링/저장 트렌드</h2>
            <canvas id='trendChart'></canvas>
        </div>
        <!-- 상세 테이블 -->
        <div class='flex-row'>
            <div class='flex-col table-section'>
                <h2>최근 크롤링 뉴스</h2>
                <input class='search-box' id='search-crawl' placeholder='제목 검색...'>
                <div class='table-scroll'>
                <table id='news-table'>
                    <thead>
                        <tr><th style='min-width:120px;'>시간</th><th>출처</th><th>제목</th></tr>
                    </thead>
                    <tbody><tr><td colspan='3'>로딩 중...</td></tr></tbody>
                </table>
                </div>
            </div>
            <div class='flex-col table-section'>
                <h2>Supabase 저장 뉴스</h2>
                <input class='search-box' id='search-save' placeholder='제목 검색...'>
                <div class='table-scroll'>
                <table id='save-table'>
                    <thead>
                        <tr><th style='min-width:120px;'>시간</th><th>제목</th></tr>
                    </thead>
                    <tbody><tr><td colspan='2'>로딩 중...</td></tr></tbody>
                </table>
                </div>
            </div>
        </div>
        <div class='table-section'>
            <h2>에러/경고 내역</h2>
            <div class='table-scroll'>
            <table id='err-table'>
                <thead>
                    <tr><th style='min-width:120px;'>시간</th><th>서비스</th><th>레벨</th><th>메시지</th></tr>
                </thead>
                <tbody><tr><td colspan='4'>로딩 중...</td></tr></tbody>
            </table>
            </div>
        </div>
    </div>
    <script>
    // KPI, 차트, 테이블용 데이터 변수
    let crawlRows = [], saveRows = [], errRows = [];
    // 1. 크롤링/저장/에러 KPI 및 차트 데이터 집계
    function updateKPI() {
        document.getElementById('kpi-crawl').textContent = crawlRows.length;
        document.getElementById('kpi-save').textContent = saveRows.length;
        document.getElementById('kpi-err').textContent = errRows.length;
        let success = crawlRows.length ? Math.round(saveRows.length / crawlRows.length * 100) : '-';
        document.getElementById('kpi-success').textContent = success;
        // 마지막/다음 크롤링
        let last = crawlRows.length ? crawlRows[0].time : '-';
        document.getElementById('kpi-last-crawl').textContent = last;
        if (last !== '-') {
            let dt = new Date(last.replace(/-/g,'/'));
            dt.setHours(dt.getHours() + 2);
            document.getElementById('kpi-next-crawl').textContent = '다음: ' + dt.toLocaleString('ko-KR');
        } else {
            document.getElementById('kpi-next-crawl').textContent = '';
        }
    }
    // 2. 트렌드 차트(최근 24시간)
    function updateChart() {
        let now = new Date();
        let hours = [];
        let crawlCnt = [], saveCnt = [];
        for (let i = 23; i >= 0; i--) {
            let h = new Date(now.getTime() - i*3600*1000);
            let label = h.getHours() + '시';
            hours.push(label);
            let hStr = h.getFullYear()+'-'+String(h.getMonth()+1).padStart(2,'0')+'-'+String(h.getDate()).padStart(2,'0')+' '+String(h.getHours()).padStart(2,'0');
            crawlCnt.push(crawlRows.filter(r => r.time.startsWith(hStr)).length);
            saveCnt.push(saveRows.filter(r => r.time.startsWith(hStr)).length);
        }
        let ctx = document.getElementById('trendChart').getContext('2d');
        if (window.trendChartObj) window.trendChartObj.destroy();
        window.trendChartObj = new Chart(ctx, {
            type: 'line',
            data: {
                labels: hours,
                datasets: [
                    { label: '크롤링', data: crawlCnt, borderColor: '#7ecfff', backgroundColor: 'rgba(126,207,255,0.1)', tension:0.2, fill:true },
                    { label: '저장', data: saveCnt, borderColor: '#ffe07e', backgroundColor: 'rgba(255,224,126,0.1)', tension:0.2, fill:true }
                ]
            },
            options: {
                plugins: { legend: { labels: { color: '#e6eaf3' } } },
                scales: { x: { ticks: { color: '#b0b8c9', padding: 10 } }, y: { ticks: { color: '#b0b8c9' } } },
                responsive: true, maintainAspectRatio: false,
                layout: { padding: { bottom: 32 } }
            }
        });
    }
    // 3. 테이블 렌더링(검색/정렬)
    function renderTable(id, rows, cols, searchId) {
        let q = document.getElementById(searchId).value.trim();
        let filtered = q ? rows.filter(r => r.title.includes(q)) : rows;
        let html = filtered.length ? filtered.map(r => `<tr>${cols.map(c => `<td class='mono'>${r[c]}</td>`).join('')}</tr>`).join('') : `<tr><td colspan='${cols.length}'>아직 데이터가 없습니다.</td></tr>`;
        document.querySelector(`#${id} tbody`).innerHTML = html;
    }
    // 시간 문자열을 Date 객체로 변환(,밀리초 없는 경우도 지원)
    function parseKST(t) {
        if (!t) return '-';
        let t2 = t.includes(',') ? t.replace(/-/g,'/') : t.replace(/-/g,'/').replace(' ', 'T');
        let d = new Date(t2);
        if (d.toString() === 'Invalid Date') return t;
        return d.toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' });
    }
    function parseCrawl(logs) {
        // 'YYYY-MM-DD HH:MM:SS - ...' 형식도 지원
        return logs.filter(line => line.includes('수집 완료')).slice(-100).reverse().map(line => {
            const m = line.match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})(?:,\d+)? - [^ ]+ - [^ ]+ - [^\[]*\[Playwright\] ([^ ]+) 수집 완료: (.+)$/);
            if (!m) return null;
            let t_kr = parseKST(m[1]);
            let source = m[2];
            let title = m[3];
            return { time: t_kr, source, title };
        }).filter(Boolean);
    }
    function parseSave(logs) {
        // 'YYYY-MM-DD HH:MM:SS - ...' 형식도 지원
        return logs.filter(line => line.includes('저장 성공')).slice(-100).reverse().map(line => {
            // 새 형식: "  - 저장 성공: TITLE" 또는 "뉴스 저장 및 DB 반영 확인 성공: TITLE"
            const m = line.match(/(?:저장 성공|반영 확인 성공): (.+)$/);
            if (!m || !m[1]) return null;

            // 시간은 같은 줄의 타임스탬프에서 가져오기
            const tsMatch = line.match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/);
            let t_kr = tsMatch ? parseKST(tsMatch[1]) : '-';
            let title = m[1] || '-';

            return { time: t_kr, title };
        }).filter(Boolean);
    }
    function parseErr(cLogs, wLogs) {
        // 멀티라인 로그 병합: 타임스탬프로 시작하지 않는 줄은 직전 메시지에 이어붙임
        const lines = cLogs.concat(wLogs).filter(line => line.includes('ERROR') || line.includes('WARNING'));
        let merged = [];
        let last = null;
        const tsPattern = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:,\d+)? - /;
        for (let i = 0; i < lines.length; i++) {
            if (tsPattern.test(lines[i])) {
                if (last) merged.push(last);
                last = lines[i];
            } else if (last) {
                last += '\n' + lines[i];
            }
        }
        if (last) merged.push(last);
        return merged.slice(-100).reverse().map(line => {
            // 표준 로그 패턴: 2025-06-14 01:50:48 - __main__ - WARNING - 메시지
            const m = line.match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})(?:,\d+)? - ([^ ]+) - (ERROR|WARNING) - ([\s\S]+)$/);
            if (m) {
                let t_kr = parseKST(m[1]);
                return { time: t_kr, svc: m[2], level: m[3], msg: m[4].replace(/\n/g, '<br>') };
            } else {
                // 패턴이 맞지 않는 경우에도 최대한 정보 추출
                const m2 = line.match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})(?:,\d+)? - ([^ ]+) - ([^ ]+) - ([\s\S]+)$/);
                if (m2) {
                    let t_kr = parseKST(m2[1]);
                    return { time: t_kr, svc: m2[2], level: m2[3], msg: m2[4].replace(/\n/g, '<br>') };
                }
                return { time: '-', svc: '-', level: '-', msg: line.replace(/\n/g, '<br>') };
            }
        });
    }
    // 5. 데이터 로드 및 UI 갱신
    function loadAll() {
        Promise.all([
            fetch('/api/logs/crawler?lines=500').then(r=>r.json()),
            fetch('/api/logs/writer?lines=500').then(r=>r.json())
        ]).then(([c, w]) => {
            crawlRows = parseCrawl(c.logs);
            saveRows = parseSave(w.logs);
            errRows = parseErr(c.logs, w.logs);
            updateKPI();
            updateChart();
            renderTable('news-table', crawlRows, ['time','source','title'], 'search-crawl');
            renderTable('save-table', saveRows, ['time','title'], 'search-save');
            let errHtml = errRows.length ? errRows.map(r => `<tr><td class='mono'>${r.time}</td><td>${r.svc}</td><td>${r.level}</td><td class='mono'>${r.msg}</td></tr>`).join('') : `<tr><td colspan='4'>아직 데이터가 없습니다.</td></tr>`;
            document.querySelector('#err-table tbody').innerHTML = errHtml;
        });
    }
    document.getElementById('search-crawl').oninput = () => renderTable('news-table', crawlRows, ['time','source','title'], 'search-crawl');
    document.getElementById('search-save').oninput = () => renderTable('save-table', saveRows, ['time','title'], 'search-save');
    loadAll();
    setInterval(loadAll, 5000); // 5초마다 실시간 갱신
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
                    const m = line.match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})(?:,\d+)? - [^ ]+ - [^ ]+ - [^\[]*\[Playwright\] ([^ ]+) 수집 완료: (.+)$/);
                    if (!m) return null;
                    let title = m[3];
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
                        const m = data.logs[i].match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})(?:,\d+)? - [^ ]+ - [^ ]+ - 뉴스 저장 성공: (.+)$/);
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
                const html = result.length ? result.map(r => `<tr><td>${r.time}</td><td>${r.title}</td><td>${r.rel}</td><td>${r.img}</td></tr>`).join('') : `<tr><td colspan='4'>데이터 없음</td></tr>`;
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
                const m = line.match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})(?:,\d+)? - ([^ ]+) - (ERROR|WARNING) - (.+)$/);
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