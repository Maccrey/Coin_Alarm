-- Migration: 001_initial_schema.sql
-- 코인 알람 앱을 위한 초기 스키마 마이그레이션

-- 사용자 프로필 테이블 (Supabase Auth와 연동)
CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT,
  profile_image_url TEXT,
  favorite_coins TEXT[] DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 코인 정보 테이블
CREATE TABLE IF NOT EXISTS coins (
  id TEXT PRIMARY KEY,
  symbol TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  image_url TEXT,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 코인 가격 이력 테이블
CREATE TABLE IF NOT EXISTS price_history (
  id BIGSERIAL PRIMARY KEY,
  coin_id TEXT NOT NULL REFERENCES coins(id),
  price DECIMAL(24, 8) NOT NULL,
  market_cap DECIMAL(24, 2),
  volume_24h DECIMAL(24, 2),
  timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
  UNIQUE (coin_id, timestamp)
);

-- 가격 알림 설정 테이블
CREATE TABLE IF NOT EXISTS price_alerts (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  symbol TEXT NOT NULL,
  target_price DECIMAL(24, 8) NOT NULL,
  is_above BOOLEAN NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  is_triggered BOOLEAN NOT NULL DEFAULT FALSE,
  triggered_at TIMESTAMP WITH TIME ZONE,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 사용자 설정 테이블
CREATE TABLE IF NOT EXISTS user_settings (
  user_id UUID REFERENCES auth.users(id) PRIMARY KEY,
  settings JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 차트 데이터 캐시 테이블
CREATE TABLE IF NOT EXISTS chart_data (
  id BIGSERIAL PRIMARY KEY,
  symbol TEXT NOT NULL,
  exchange TEXT NOT NULL,
  timeframe TEXT NOT NULL,
  chart_type TEXT NOT NULL,
  data JSONB NOT NULL,
  timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
  UNIQUE (symbol, exchange, timeframe, chart_type)
);

-- 알림 이력 테이블
CREATE TABLE IF NOT EXISTS alert_history (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  alert_id BIGINT REFERENCES price_alerts(id),
  symbol TEXT NOT NULL,
  price DECIMAL(24, 8) NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS price_history_coin_timestamp_idx ON price_history (coin_id, timestamp);
CREATE INDEX IF NOT EXISTS price_alerts_user_symbol_idx ON price_alerts (user_id, symbol);
CREATE INDEX IF NOT EXISTS chart_data_symbol_timeframe_idx ON chart_data (symbol, timeframe);

-- RLS(Row Level Security) 정책 설정
-- 사용자 프로필 정책: 자신의 프로필만 읽고 수정 가능
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_profiles_select ON user_profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY user_profiles_insert ON user_profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY user_profiles_update ON user_profiles
  FOR UPDATE USING (auth.uid() = id);

-- 가격 알림 정책: 자신의 알림만 읽고 수정 가능
ALTER TABLE price_alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY price_alerts_select ON price_alerts
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY price_alerts_insert ON price_alerts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY price_alerts_update ON price_alerts
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY price_alerts_delete ON price_alerts
  FOR DELETE USING (auth.uid() = user_id);

-- 사용자 설정 정책: 자신의 설정만 읽고 수정 가능
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_settings_select ON user_settings
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY user_settings_insert ON user_settings
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_settings_update ON user_settings
  FOR UPDATE USING (auth.uid() = user_id);

-- 알림 이력 정책: 자신의 알림 이력만 읽기 가능
ALTER TABLE alert_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY alert_history_select ON alert_history
  FOR SELECT USING (auth.uid() = user_id);

-- 공개 테이블 정책: 코인, 가격 이력 테이블은 모든 사용자가 읽기 가능
ALTER TABLE coins ENABLE ROW LEVEL SECURITY;
CREATE POLICY coins_select ON coins FOR SELECT USING (true);

ALTER TABLE price_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY price_history_select ON price_history FOR SELECT USING (true);

ALTER TABLE chart_data ENABLE ROW LEVEL SECURITY;
CREATE POLICY chart_data_select ON chart_data FOR SELECT USING (true);

-- 트리거 함수: 업데이트 시간 자동 갱신
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 업데이트 트리거 적용
CREATE TRIGGER update_user_profiles_modtime
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_coins_modtime
  BEFORE UPDATE ON coins
  FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_price_alerts_modtime
  BEFORE UPDATE ON price_alerts
  FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_user_settings_modtime
  BEFORE UPDATE ON user_settings
  FOR EACH ROW EXECUTE PROCEDURE update_modified_column(); 