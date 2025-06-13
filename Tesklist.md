- [x] Supabase 저장 신뢰성 강화 (저장 후 DB 반영 여부 즉시 검증, 실패 시 재시도, 필수 필드 체크, 상세 로그 및 예외 처리)

# 암호화폐 뉴스 파이프라인 MSA 재구현 테스크 (2025.06)

- [ ] 1. 크롤러: 주요 사이트(예: blockmedia, coinreaders, digitaltoday)에서 Playwright로 뉴스 수집, crawled*news*\*.json 파일로 저장 (한글 주석, 명확한 변수명, 예외 처리, 중복/빈 데이터 방지)
- [ ] 2. 클리너: crawled*news*_.json을 읽어 정제(필터링, 중복/광고/짧은 기사 제거), cleaned*news*_.json 파일로 저장
- [ ] 3. writer: cleaned*news*\*.json을 읽어 Supabase에 저장, 성공 시 파일 삭제, 실패 시 로그 남기고 파일 유지
- [ ] 4. 각 단계별 robust한 예외/에러/빈 데이터/중복/포맷 문제 처리, 한글 상세 로그 남기기
- [ ] 5. logger: 각 단계별 로그/상태를 실시간 대시보드로 시각화 (최신 30건, KPI, 에러 강조, 다크테마 등)
- [ ] 6. 불필요 파일/임시/중복/테스트 파일(.DS_Store, temp_cleaner.py 등) 정리 및 삭제
