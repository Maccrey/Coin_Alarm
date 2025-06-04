# Supabase 데이터베이스 테이블 구조

이 문서는 코인 알람 앱에서 사용하는 Supabase 데이터베이스의 테이블 구조를 설명합니다.

## 테이블 목록

1. `user_profiles` - 사용자 프로필 정보
2. `coins` - 코인 기본 정보
3. `price_history` - 코인 가격 이력 데이터
4. `price_alerts` - 사용자 가격 알림 설정
5. `news` - 뉴스 정보
6. `news_coins` - 뉴스와 코인의 관계 정보
7. `user_settings` - 사용자별 앱 설정 정보
8. `chart_data` - 차트 데이터 캐시
9. `alert_history` - 알림 발생 이력

## 테이블 상세 정보

### 1. user_profiles

Supabase Auth와 연동된 사용자 프로필 정보를 저장합니다.

| 필드              | 타입      | 설명                               |
| ----------------- | --------- | ---------------------------------- |
| id                | UUID      | 사용자 ID (auth.users 테이블 참조) |
| email             | TEXT      | 이메일 주소                        |
| name              | TEXT      | 사용자 이름                        |
| profile_image_url | TEXT      | 프로필 이미지 URL                  |
| favorite_coins    | TEXT[]    | 즐겨찾기한 코인 심볼 배열          |
| created_at        | TIMESTAMP | 생성 시간                          |
| updated_at        | TIMESTAMP | 수정 시간                          |

### 2. coins

코인 기본 정보를 저장합니다.

| 필드        | 타입      | 설명                    |
| ----------- | --------- | ----------------------- |
| id          | TEXT      | 코인 ID (예: bitcoin)   |
| symbol      | TEXT      | 코인 심볼 (예: BTC)     |
| name        | TEXT      | 코인 이름 (예: Bitcoin) |
| image_url   | TEXT      | 코인 로고 이미지 URL    |
| description | TEXT      | 코인 설명               |
| created_at  | TIMESTAMP | 생성 시간               |
| updated_at  | TIMESTAMP | 수정 시간               |

### 3. price_history

코인의 가격 이력 데이터를 저장합니다.

| 필드       | 타입           | 설명                        |
| ---------- | -------------- | --------------------------- |
| id         | BIGSERIAL      | 고유 ID                     |
| coin_id    | TEXT           | 코인 ID (coins 테이블 참조) |
| price      | DECIMAL(24, 8) | 가격                        |
| market_cap | DECIMAL(24, 2) | 시가총액                    |
| volume_24h | DECIMAL(24, 2) | 24시간 거래량               |
| timestamp  | TIMESTAMP      | 데이터 시간                 |

### 4. price_alerts

사용자별 가격 알림 설정을 저장합니다.

| 필드         | 타입           | 설명                                                          |
| ------------ | -------------- | ------------------------------------------------------------- |
| id           | BIGSERIAL      | 고유 ID                                                       |
| user_id      | UUID           | 사용자 ID (auth.users 테이블 참조)                            |
| symbol       | TEXT           | 코인 심볼                                                     |
| target_price | DECIMAL(24, 8) | 목표 가격                                                     |
| is_above     | BOOLEAN        | 가격이 목표가 이상일 때 알림(true) 또는 이하일 때 알림(false) |
| is_active    | BOOLEAN        | 알림 활성화 여부                                              |
| is_triggered | BOOLEAN        | 알림 발생 여부                                                |
| triggered_at | TIMESTAMP      | 알림 발생 시간                                                |
| notes        | TEXT           | 사용자 메모                                                   |
| created_at   | TIMESTAMP      | 생성 시간                                                     |
| updated_at   | TIMESTAMP      | 수정 시간                                                     |

### 5. news

뉴스 정보를 저장합니다.

| 필드         | 타입      | 설명            |
| ------------ | --------- | --------------- |
| id           | BIGSERIAL | 고유 ID         |
| title        | TEXT      | 뉴스 제목       |
| content      | TEXT      | 뉴스 내용       |
| source       | TEXT      | 뉴스 출처       |
| url          | TEXT      | 뉴스 URL        |
| image_url    | TEXT      | 뉴스 이미지 URL |
| published_at | TIMESTAMP | 뉴스 발행 시간  |
| created_at   | TIMESTAMP | 생성 시간       |

### 6. news_coins

뉴스와 코인의 관계 정보를 저장합니다.

| 필드    | 타입      | 설명                        |
| ------- | --------- | --------------------------- |
| id      | BIGSERIAL | 고유 ID                     |
| news_id | BIGINT    | 뉴스 ID (news 테이블 참조)  |
| coin_id | TEXT      | 코인 ID (coins 테이블 참조) |

### 7. user_settings

사용자별 앱 설정 정보를 저장합니다.

| 필드       | 타입      | 설명                               |
| ---------- | --------- | ---------------------------------- |
| user_id    | UUID      | 사용자 ID (auth.users 테이블 참조) |
| settings   | JSONB     | 설정 정보 (JSON 형식)              |
| created_at | TIMESTAMP | 생성 시간                          |
| updated_at | TIMESTAMP | 수정 시간                          |

### 8. chart_data

차트 데이터 캐시를 저장합니다.

| 필드       | 타입      | 설명                         |
| ---------- | --------- | ---------------------------- |
| id         | BIGSERIAL | 고유 ID                      |
| symbol     | TEXT      | 코인 심볼                    |
| exchange   | TEXT      | 거래소                       |
| timeframe  | TEXT      | 시간 프레임 (예: 1m, 1h, 1d) |
| chart_type | TEXT      | 차트 타입 (예: candle, line) |
| data       | JSONB     | 차트 데이터 (JSON 형식)      |
| timestamp  | TIMESTAMP | 데이터 시간                  |

### 9. alert_history

알림 발생 이력을 저장합니다.

| 필드       | 타입           | 설명                               |
| ---------- | -------------- | ---------------------------------- |
| id         | BIGSERIAL      | 고유 ID                            |
| user_id    | UUID           | 사용자 ID (auth.users 테이블 참조) |
| alert_id   | BIGINT         | 알림 ID (price_alerts 테이블 참조) |
| symbol     | TEXT           | 코인 심볼                          |
| price      | DECIMAL(24, 8) | 발생 시 가격                       |
| message    | TEXT           | 알림 메시지                        |
| created_at | TIMESTAMP      | 생성 시간                          |

## RLS(Row Level Security) 정책

각 테이블에는 다음과 같은 RLS 정책이 적용되어 있습니다:

1. `user_profiles`, `price_alerts`, `user_settings`, `alert_history`: 사용자는 자신의 데이터만 읽고 수정할 수 있습니다.
2. `coins`, `price_history`, `news`, `news_coins`, `chart_data`: 모든 사용자가 읽기 가능합니다.

## 인덱스

성능 최적화를 위해 다음과 같은 인덱스가 생성되어 있습니다:

1. `price_history_coin_timestamp_idx`: 코인별 시간순 가격 조회 최적화
2. `price_alerts_user_symbol_idx`: 사용자별 코인 알림 조회 최적화
3. `news_published_at_idx`: 뉴스 발행 시간순 조회 최적화
4. `news_coins_coin_id_idx`: 코인별 뉴스 조회 최적화
5. `chart_data_symbol_timeframe_idx`: 코인별 시간프레임 차트 데이터 조회 최적화
