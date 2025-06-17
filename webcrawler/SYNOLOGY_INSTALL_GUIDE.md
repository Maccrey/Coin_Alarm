# 시놀로지 NAS에 뉴스 크롤링 시스템 설치 가이드

이 가이드는 시놀로지 NAS에 암호화폐 뉴스 크롤링 시스템을 Docker 컨테이너로 설치하는 방법을 설명합니다.

## 사전 요구 사항

1. Docker 패키지가 설치된 시놀로지 NAS
2. 시놀로지 NAS에 대한 SSH 접근 권한 (선택 사항)
3. Supabase 계정 및 API 키

## 설치 방법

### 1. 도커 이미지 준비

로컬 컴퓨터에서 다음 단계를 수행합니다:

1. 저장소를 클론합니다:

   ```bash
   git clone https://github.com/yourusername/coin_alarm.git
   cd coin_alarm/webcrawler
   ```

2. Docker Hub 계정이 있는지 확인하고, 로그인합니다:

   ```bash
   docker login
   ```

3. 이미지 빌드 및 푸시 스크립트를 실행합니다:
   ```bash
   ./build_push_images.sh yourdockerhubusername
   ```
   - 이 스크립트는 5개의 서비스 이미지를 빌드하고 Docker Hub에 푸시합니다.
   - 또한 시놀로지에서 사용할 `docker-compose.synology.yml` 파일을 생성합니다.

### 2. 시놀로지 NAS 준비

시놀로지 NAS에서 다음 단계를 수행합니다:

1. **Docker 패키지 설치**:

   - Synology Package Center에서 "Docker" 패키지를 검색하고 설치합니다.

2. **디렉토리 생성**:

   - File Station을 사용하여 다음 디렉토리를 생성합니다:
     ```
     /volume1/docker/coin-alarm-crawler
     /volume1/docker/coin-alarm-crawler/shared
     /volume1/docker/coin-alarm-crawler/logs
     ```

3. **환경 설정 파일 생성**:

   - `/volume1/docker/coin-alarm-crawler/.env` 파일을 생성하고 다음 내용을 추가합니다:
     ```
     SUPABASE_URL=your_supabase_url
     SUPABASE_API_KEY=your_supabase_anon_key
     ```
   - `your_supabase_url`과 `your_supabase_anon_key`를 실제 Supabase 정보로 바꿉니다.

4. **Docker Compose 파일 업로드**:
   - 로컬 컴퓨터에서 생성한 `docker-compose.synology.yml` 파일을 시놀로지의 `/volume1/docker/coin-alarm-crawler/` 경로에 업로드합니다.
   - 파일명을 `docker-compose.yml`로 변경합니다.

### 3. 컨테이너 실행

#### 방법 1: Synology Docker UI 사용

1. Synology Docker 앱을 엽니다.
2. "Registry"로 이동하여 각 이미지를 검색하고 다운로드합니다:

   - `yourdockerhubusername/coin-alarm-news-crawler:latest`
   - `yourdockerhubusername/coin-alarm-news-cleaner:latest`
   - `yourdockerhubusername/coin-alarm-news-writer:latest`
   - `yourdockerhubusername/coin-alarm-scheduler:latest`
   - `yourdockerhubusername/coin-alarm-logger:latest`

3. "Image"로 이동하여 다운로드한 이미지가 있는지 확인합니다.

4. "Container"로 이동하여 각 이미지를 기반으로 컨테이너를 생성합니다.
   - 볼륨 마운트와 환경 변수를 올바르게 설정해야 합니다.

#### 방법 2: SSH 및 Docker Compose 사용 (권장)

1. SSH를 통해 시놀로지 NAS에 접속합니다:

   ```bash
   ssh admin@your_synology_ip
   ```

2. 설치 디렉토리로 이동합니다:

   ```bash
   cd /volume1/docker/coin-alarm-crawler
   ```

3. Docker Compose를 사용하여 컨테이너를 시작합니다:

   ```bash
   docker-compose up -d
   ```

4. 컨테이너가 정상적으로 실행 중인지 확인합니다:
   ```bash
   docker-compose ps
   ```

### 4. 로그 및 모니터링

1. 컨테이너 로그 확인:

   ```bash
   docker-compose logs -f
   ```

2. 특정 서비스의 로그만 확인:

   ```bash
   docker-compose logs -f news-crawler
   docker-compose logs -f news-writer
   ```

3. 로깅 대시보드 접속:
   - 웹 브라우저에서 `http://your_synology_ip:5001`로 접속합니다.

### 5. 문제 해결

#### 컨테이너가 시작되지 않는 경우

1. 로그 확인:

   ```bash
   docker-compose logs service_name
   ```

2. 환경 변수 확인:

   - `.env` 파일이 올바른 경로에 있는지 확인합니다.
   - Supabase URL과 API 키가 올바른지 확인합니다.

3. 볼륨 권한 확인:
   ```bash
   ls -la /volume1/docker/coin-alarm-crawler/shared
   ```
   - `shared` 디렉토리에 대한 쓰기 권한이 있는지 확인합니다.

#### 데이터가 Supabase에 저장되지 않는 경우

1. `news-writer` 서비스 로그 확인:

   ```bash
   docker-compose logs -f news-writer
   ```

2. Supabase 연결 및 API 키 확인:
   - Supabase 프로젝트 설정에서 API URL과 키를 확인합니다.
   - `.env` 파일의 값이 올바른지 확인합니다.

## 유지 관리

### 컨테이너 재시작

```bash
docker-compose restart
```

### 이미지 업데이트

1. 최신 이미지 가져오기:

   ```bash
   docker-compose pull
   ```

2. 컨테이너 재시작:
   ```bash
   docker-compose up -d
   ```

### 데이터 백업

중요한 데이터는 `shared` 디렉토리에 저장됩니다. 주기적으로 이 디렉토리를 백업하세요:

```bash
cp -r /volume1/docker/coin-alarm-crawler/shared /volume1/backup/coin-alarm-crawler/shared_$(date +%Y%m%d)
```

## 보안 고려 사항

1. Supabase API 키는 안전하게 보관하고, `.env` 파일의 권한을 제한하세요:

   ```bash
   chmod 600 /volume1/docker/coin-alarm-crawler/.env
   ```

2. 로깅 서비스 포트(5001)는 내부 네트워크에서만 접근 가능하도록 설정하세요.

3. 정기적으로 Docker 이미지와 컨테이너를 업데이트하여 보안 취약점을 해결하세요.

## 추가 참고 사항

- 이 설치는 약 2시간마다 뉴스를 자동으로 크롤링합니다.
- 처리된 뉴스는 Supabase 데이터베이스에 저장됩니다.
- 이미지 URL과 관련 코인 정보도 함께 저장됩니다.
- SQLite 데이터베이스를 사용하여 이미 처리된 뉴스는 중복 저장되지 않습니다.
- 처리 완료된 파일은 자동으로 정리됩니다.
