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
    return "Logger is running!"


# 정적 파일 서빙
@app.route('/static/<path:path>')
def serve_static(path):
    """정적 파일 서빙"""
    return send_from_directory('static', path)


# 템플릿이 없을 경우를 대비한 간단한 HTML 생성
@app.route('/fallback')
def fallback_dashboard():
    """
    템플릿이 없을 경우 대체 대시보드
    - 실제 구현 시 templates/index.html과 static/ 디렉토리 생성 필요
    """
    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>뉴스 크롤러 로그 대시보드</title>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }
            h1 { color: #333; }
            .service { margin-bottom: 20px; border: 1px solid #ddd; padding: 10px; border-radius: 5px; }
            .service h2 { margin-top: 0; }
            .status { padding: 5px 10px; border-radius: 3px; display: inline-block; }
            .status.ok { background-color: #dff0d8; color: #3c763d; }
            .status.error { background-color: #f2dede; color: #a94442; }
            pre { background-color: #f5f5f5; padding: 10px; border-radius: 5px; overflow: auto; }
        </style>
    </head>
    <body>
        <h1>뉴스 크롤러 로그 대시보드</h1>
        <div id="services">
            <h2>서비스 상태 로딩 중...</h2>
        </div>
        <div id="logs">
            <h2>로그 로딩 중...</h2>
        </div>
        
        <script>
            // 서비스 상태 로드
            fetch('/api/status')
                .then(response => response.json())
                .then(data => {
                    const servicesDiv = document.getElementById('services');
                    servicesDiv.innerHTML = '<h2>서비스 상태</h2>';
                    
                    data.services.forEach(service => {
                        const serviceDiv = document.createElement('div');
                        serviceDiv.className = 'service';
                        serviceDiv.innerHTML = `
                            <h3>${service.name}</h3>
                            <div class="status ${service.status}">${service.status.toUpperCase()}</div>
                            <p>마지막 체크: ${new Date(service.checked_at).toLocaleString()}</p>
                        `;
                        servicesDiv.appendChild(serviceDiv);
                    });
                })
                .catch(error => {
                    console.error('Error:', error);
                    document.getElementById('services').innerHTML = '<h2>서비스 상태</h2><p>오류: 데이터를 불러올 수 없습니다.</p>';
                });
            
            // 로그 로드
            fetch('/api/logs/crawler')
                .then(response => response.json())
                .then(data => {
                    const logsDiv = document.getElementById('logs');
                    logsDiv.innerHTML = `
                        <h2>${data.service} 로그</h2>
                        <pre>${data.logs.join('')}</pre>
                    `;
                })
                .catch(error => {
                    console.error('Error:', error);
                    document.getElementById('logs').innerHTML = '<h2>로그</h2><p>오류: 데이터를 불러올 수 없습니다.</p>';
                });
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