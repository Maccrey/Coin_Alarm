-- Supabase RLS(Row Level Security) 정책 설정
-- 코인 알람 앱을 위한 보안 정책

-- ===== 사용자 프로필 테이블 정책 =====
-- 사용자는 자신의 프로필만 읽고 수정할 수 있습니다.
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- 기존 정책 삭제 (있는 경우)
DROP POLICY IF EXISTS user_profiles_select ON user_profiles;
DROP POLICY IF EXISTS user_profiles_insert ON user_profiles;
DROP POLICY IF EXISTS user_profiles_update ON user_profiles;
DROP POLICY IF EXISTS user_profiles_delete ON user_profiles;

-- 정책 생성
CREATE POLICY user_profiles_select ON user_profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY user_profiles_insert ON user_profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY user_profiles_update ON user_profiles
  FOR UPDATE USING (auth.uid() = id);

-- 삭제는 허용하지 않음 (사용자 프로필은 계정 삭제 시 트리거로 처리)

-- ===== 가격 알림 테이블 정책 =====
-- 사용자는 자신의 알림만 읽고 수정할 수 있습니다.
ALTER TABLE price_alerts ENABLE ROW LEVEL SECURITY;

-- 기존 정책 삭제 (있는 경우)
DROP POLICY IF EXISTS price_alerts_select ON price_alerts;
DROP POLICY IF EXISTS price_alerts_insert ON price_alerts;
DROP POLICY IF EXISTS price_alerts_update ON price_alerts;
DROP POLICY IF EXISTS price_alerts_delete ON price_alerts;

-- 정책 생성
CREATE POLICY price_alerts_select ON price_alerts
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY price_alerts_insert ON price_alerts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY price_alerts_update ON price_alerts
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY price_alerts_delete ON price_alerts
  FOR DELETE USING (auth.uid() = user_id);

-- ===== 사용자 설정 테이블 정책 =====
-- 사용자는 자신의 설정만 읽고 수정할 수 있습니다.
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

-- 기존 정책 삭제 (있는 경우)
DROP POLICY IF EXISTS user_settings_select ON user_settings;
DROP POLICY IF EXISTS user_settings_insert ON user_settings;
DROP POLICY IF EXISTS user_settings_update ON user_settings;
DROP POLICY IF EXISTS user_settings_delete ON user_settings;

-- 정책 생성
CREATE POLICY user_settings_select ON user_settings
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY user_settings_insert ON user_settings
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_settings_update ON user_settings
  FOR UPDATE USING (auth.uid() = user_id);

-- 삭제는 허용하지 않음 (사용자 설정은 계정 삭제 시 트리거로 처리)

-- ===== 알림 이력 테이블 정책 =====
-- 사용자는 자신의 알림 이력만 읽을 수 있습니다. (생성은 시스템에서 수행)
ALTER TABLE alert_history ENABLE ROW LEVEL SECURITY;

-- 기존 정책 삭제 (있는 경우)
DROP POLICY IF EXISTS alert_history_select ON alert_history;
DROP POLICY IF EXISTS alert_history_insert ON alert_history;

-- 정책 생성
CREATE POLICY alert_history_select ON alert_history
  FOR SELECT USING (auth.uid() = user_id);

-- 서비스 역할만 알림 이력을 생성할 수 있음
CREATE POLICY alert_history_insert ON alert_history
  FOR INSERT WITH CHECK (auth.uid() = user_id OR auth.role() = 'service_role');

-- ===== 코인 정보 테이블 정책 =====
-- 모든 사용자가 코인 정보를 읽을 수 있지만, 수정은 관리자만 가능합니다.
ALTER TABLE coins ENABLE ROW LEVEL SECURITY;

-- 기존 정책 삭제 (있는 경우)
DROP POLICY IF EXISTS coins_select ON coins;
DROP POLICY IF EXISTS coins_insert ON coins;
DROP POLICY IF EXISTS coins_update ON coins;

-- 정책 생성
CREATE POLICY coins_select ON coins
  FOR SELECT USING (true);

-- 관리자만 코인 정보 추가/수정 가능
CREATE POLICY coins_insert ON coins
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

CREATE POLICY coins_update ON coins
  FOR UPDATE USING (auth.role() = 'service_role');

-- ===== 가격 이력 테이블 정책 =====
-- 모든 사용자가 가격 이력을 읽을 수 있지만, 추가는 관리자만 가능합니다.
ALTER TABLE price_history ENABLE ROW LEVEL SECURITY;

-- 기존 정책 삭제 (있는 경우)
DROP POLICY IF EXISTS price_history_select ON price_history;
DROP POLICY IF EXISTS price_history_insert ON price_history;

-- 정책 생성
CREATE POLICY price_history_select ON price_history
  FOR SELECT USING (true);

-- 관리자만 가격 이력 추가 가능
CREATE POLICY price_history_insert ON price_history
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

-- ===== 차트 데이터 캐시 테이블 정책 =====
-- 모든 사용자가 차트 데이터를 읽을 수 있지만, 추가/수정은 관리자만 가능합니다.
ALTER TABLE chart_data ENABLE ROW LEVEL SECURITY;

-- 기존 정책 삭제 (있는 경우)
DROP POLICY IF EXISTS chart_data_select ON chart_data;
DROP POLICY IF EXISTS chart_data_insert ON chart_data;
DROP POLICY IF EXISTS chart_data_update ON chart_data;

-- 정책 생성
CREATE POLICY chart_data_select ON chart_data
  FOR SELECT USING (true);

-- 관리자만 차트 데이터 추가/수정 가능
CREATE POLICY chart_data_insert ON chart_data
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

CREATE POLICY chart_data_update ON chart_data
  FOR UPDATE USING (auth.role() = 'service_role');

-- ===== 뉴스 테이블 정책 =====
-- 모든 사용자가 뉴스를 읽을 수 있지만, 추가/수정은 관리자만 가능합니다.
ALTER TABLE news ENABLE ROW LEVEL SECURITY;

-- 기존 정책 삭제 (있는 경우)
DROP POLICY IF EXISTS news_select ON news;
DROP POLICY IF EXISTS news_insert ON news;
DROP POLICY IF EXISTS news_update ON news;

-- 정책 생성
CREATE POLICY news_select ON news
  FOR SELECT USING (true);

-- 관리자만 뉴스 추가/수정 가능
CREATE POLICY news_insert ON news
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

CREATE POLICY news_update ON news
  FOR UPDATE USING (auth.role() = 'service_role');

-- ===== 뉴스-코인 관계 테이블 정책 =====
-- 모든 사용자가 뉴스-코인 관계를 읽을 수 있지만, 추가/수정은 관리자만 가능합니다.
ALTER TABLE news_coins ENABLE ROW LEVEL SECURITY;

-- 기존 정책 삭제 (있는 경우)
DROP POLICY IF EXISTS news_coins_select ON news_coins;
DROP POLICY IF EXISTS news_coins_insert ON news_coins;

-- 정책 생성
CREATE POLICY news_coins_select ON news_coins
  FOR SELECT USING (true);

-- 관리자만 뉴스-코인 관계 추가 가능
CREATE POLICY news_coins_insert ON news_coins
  FOR INSERT WITH CHECK (auth.role() = 'service_role'); 