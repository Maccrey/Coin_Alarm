-- Supabase 데이터베이스 트리거 SQL 스크립트

-- 1. 사용자 생성 시 프로필 자동 생성 트리거
CREATE OR REPLACE FUNCTION public.create_profile_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', '사용자')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 사용자 생성 시 프로필 자동 생성 트리거 등록
DROP TRIGGER IF EXISTS create_profile_trigger ON auth.users;
CREATE TRIGGER create_profile_trigger
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE PROCEDURE public.create_profile_for_new_user();

-- 2. 알림 트리거 시 사용자에게 알림 보내기 (Supabase Realtime 활용)
CREATE OR REPLACE FUNCTION public.notify_on_price_alert_trigger()
RETURNS TRIGGER AS $$
BEGIN
  -- 알림이 트리거된 경우에만 실행
  IF NEW.is_triggered = TRUE AND OLD.is_triggered = FALSE THEN
    -- 알림 메시지 생성
    DECLARE
      direction TEXT := CASE WHEN NEW.is_above THEN '이상' ELSE '이하' END;
      message TEXT := NEW.symbol || ' 가격이 ' || NEW.target_price || '원 ' || direction || '이 되었습니다.';
    BEGIN
      -- Realtime 채널로 알림 전송 (클라이언트에서 구독 필요)
      PERFORM pg_notify(
        'price_alerts',
        json_build_object(
          'user_id', NEW.user_id,
          'alert_id', NEW.id,
          'symbol', NEW.symbol,
          'target_price', NEW.target_price,
          'message', message,
          'triggered_at', NEW.triggered_at
        )::text
      );
    END;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 알림 트리거 등록
DROP TRIGGER IF EXISTS price_alert_trigger ON public.price_alerts;
CREATE TRIGGER price_alert_trigger
AFTER UPDATE ON public.price_alerts
FOR EACH ROW EXECUTE PROCEDURE public.notify_on_price_alert_trigger();

-- 3. 뉴스 추가 시 관련 코인 자동 연결 트리거
CREATE OR REPLACE FUNCTION public.link_news_to_coins()
RETURNS TRIGGER AS $$
DECLARE
  coin_record RECORD;
  title_lower TEXT := LOWER(NEW.title);
  content_lower TEXT := LOWER(NEW.content);
BEGIN
  -- 모든 코인을 순회하며 뉴스 제목과 내용에 코인 이름이 포함되어 있는지 확인
  FOR coin_record IN SELECT id, name, symbol FROM public.coins LOOP
    IF 
      position(LOWER(coin_record.name) IN title_lower) > 0 OR
      position(LOWER(coin_record.name) IN content_lower) > 0 OR
      position(LOWER(coin_record.symbol) IN title_lower) > 0 OR
      position(LOWER(coin_record.symbol) IN content_lower) > 0
    THEN
      -- 뉴스와 코인 연결
      INSERT INTO public.news_coins (news_id, coin_id)
      VALUES (NEW.id, coin_record.id)
      ON CONFLICT (news_id, coin_id) DO NOTHING;
    END IF;
  END LOOP;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 뉴스 추가 트리거 등록
DROP TRIGGER IF EXISTS news_coins_link_trigger ON public.news;
CREATE TRIGGER news_coins_link_trigger
AFTER INSERT ON public.news
FOR EACH ROW EXECUTE PROCEDURE public.link_news_to_coins();

-- 4. 사용자 설정 변경 감지 트리거
CREATE OR REPLACE FUNCTION public.log_user_settings_changes()
RETURNS TRIGGER AS $$
BEGIN
  -- 변경 사항 로깅 (실제 프로덕션에서는 필요에 따라 수정)
  INSERT INTO public.user_activity_logs (
    user_id,
    activity_type,
    details
  ) VALUES (
    NEW.user_id,
    'settings_update',
    json_build_object(
      'previous_settings', OLD.settings,
      'new_settings', NEW.settings,
      'changed_at', now()
    )
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 사용자 설정 변경 트리거 등록 (사용자 활동 로그 테이블이 있을 경우 활성화)
/*
DROP TRIGGER IF EXISTS user_settings_change_trigger ON public.user_settings;
CREATE TRIGGER user_settings_change_trigger
AFTER UPDATE ON public.user_settings
FOR EACH ROW EXECUTE PROCEDURE public.log_user_settings_changes();
*/

-- 5. 가격 이력 중복 방지 트리거
CREATE OR REPLACE FUNCTION public.prevent_duplicate_price_history()
RETURNS TRIGGER AS $$
BEGIN
  -- 동일한 코인, 동일한 시간에 대한 가격 이력이 이미 존재하는지 확인
  IF EXISTS (
    SELECT 1 FROM public.price_history
    WHERE coin_id = NEW.coin_id
    AND timestamp = NEW.timestamp
    AND id <> NEW.id
  ) THEN
    -- 중복된 데이터가 있으면 해당 레코드 업데이트
    UPDATE public.price_history
    SET 
      price = NEW.price,
      market_cap = NEW.market_cap,
      volume_24h = NEW.volume_24h
    WHERE coin_id = NEW.coin_id
    AND timestamp = NEW.timestamp;
    
    -- 현재 삽입 작업 취소
    RETURN NULL;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 가격 이력 중복 방지 트리거 등록
DROP TRIGGER IF EXISTS price_history_duplicate_trigger ON public.price_history;
CREATE TRIGGER price_history_duplicate_trigger
BEFORE INSERT ON public.price_history
FOR EACH ROW EXECUTE PROCEDURE public.prevent_duplicate_price_history(); 