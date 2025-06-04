// Supabase Edge Function: 가격 알림 트리거
// 파일명: supabase/functions/price-alert-trigger/index.js

// 필요한 Supabase 클라이언트 및 기타 라이브러리 가져오기
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.21.0";

// 서버리스 함수 정의
serve(async (req) => {
  try {
    // 요청 본문 파싱
    const { coinPrices } = await req.json();

    // 환경 변수에서 Supabase URL과 서비스 롤 키 가져오기
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    // Supabase 클라이언트 초기화 (서비스 롤 키 사용)
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 활성화된 모든 가격 알림 가져오기
    const { data: alerts, error: alertsError } = await supabase
      .from("price_alerts")
      .select("*")
      .eq("is_active", true)
      .eq("is_triggered", false);

    if (alertsError) {
      throw new Error(`알림 조회 오류: ${alertsError.message}`);
    }

    // 트리거된 알림 추적
    const triggeredAlerts = [];

    // 각 알림을 현재 가격과 비교하여 트리거 여부 확인
    for (const alert of alerts) {
      const currentPrice = coinPrices[alert.symbol];

      // 현재 가격이 없으면 건너뛰기
      if (!currentPrice) continue;

      // 알림 조건 확인
      const isTriggered = alert.is_above
        ? currentPrice >= alert.target_price // 가격이 목표가 이상일 때 알림
        : currentPrice <= alert.target_price; // 가격이 목표가 이하일 때 알림

      // 알림이 트리거되면 업데이트 및 이력 저장
      if (isTriggered) {
        triggeredAlerts.push(alert);

        // 알림 상태 업데이트
        const { error: updateError } = await supabase
          .from("price_alerts")
          .update({
            is_triggered: true,
            triggered_at: new Date().toISOString(),
          })
          .eq("id", alert.id);

        if (updateError) {
          console.error(
            `알림 업데이트 오류 (ID: ${alert.id}): ${updateError.message}`
          );
          continue;
        }

        // 알림 이력 저장
        const direction = alert.is_above ? "이상" : "이하";
        const message = `${alert.symbol} 가격이 ${alert.target_price}원 ${direction}이 되었습니다. (현재: ${currentPrice}원)`;

        const { error: historyError } = await supabase
          .from("alert_history")
          .insert({
            user_id: alert.user_id,
            alert_id: alert.id,
            symbol: alert.symbol,
            price: currentPrice,
            message: message,
          });

        if (historyError) {
          console.error(
            `알림 이력 저장 오류 (ID: ${alert.id}): ${historyError.message}`
          );
        }

        // 푸시 알림 전송 (실제 구현은 별도 서비스 필요)
        await sendPushNotification(alert.user_id, message);
      }
    }

    // 결과 반환
    return new Response(
      JSON.stringify({
        success: true,
        triggered_count: triggeredAlerts.length,
        triggered_alerts: triggeredAlerts,
      }),
      {
        headers: { "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    // 오류 처리
    console.error("Edge Function 오류:", error.message);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        headers: { "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});

// 푸시 알림 전송 함수 (예시)
async function sendPushNotification(userId, message) {
  try {
    // 여기에 실제 푸시 알림 서비스 연동 코드 구현
    // 예: Firebase Cloud Messaging, OneSignal 등
    console.log(`사용자 ${userId}에게 푸시 알림 전송: ${message}`);

    // 실제 구현 시 주석 해제
    /*
    const response = await fetch('https://your-push-notification-service.com/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${Deno.env.get('PUSH_SERVICE_API_KEY')}`
      },
      body: JSON.stringify({
        user_id: userId,
        message: message,
        title: '코인 알람',
        data: { type: 'price_alert' }
      })
    })
    
    if (!response.ok) {
      throw new Error(`푸시 알림 전송 실패: ${response.statusText}`)
    }
    
    return await response.json()
    */

    return true;
  } catch (error) {
    console.error(`푸시 알림 전송 오류: ${error.message}`);
    return false;
  }
}
