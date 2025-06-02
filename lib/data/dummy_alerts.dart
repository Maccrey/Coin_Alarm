import '../model/price_alert_model.dart';

// 더미 알림 데이터
class DummyAlerts {
  // 사용자 알림 리스트
  static List<PriceAlert> userAlerts = [
    PriceAlert(
      id: '1',
      userId: 'user1',
      coinId: 'bitcoin',
      coinSymbol: 'BTC',
      priceTarget: 70000.0,
      isAbove: true,
      isTriggered: false,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      notes: '70,000 달러 도달 시 일부 매도 고려',
    ),
    PriceAlert(
      id: '2',
      userId: 'user1',
      coinId: 'ethereum',
      coinSymbol: 'ETH',
      priceTarget: 3500.0,
      isAbove: false,
      isTriggered: true,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      triggeredAt: DateTime.now().subtract(const Duration(hours: 5)),
      notes: '지지선 하락 시 추가 매수 검토',
    ),
    PriceAlert(
      id: '3',
      userId: 'user1',
      coinId: 'binancecoin',
      coinSymbol: 'BNB',
      priceTarget: 650.0,
      isAbove: true,
      isTriggered: false,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      notes: null,
    ),
    PriceAlert(
      id: '4',
      userId: 'user1',
      coinId: 'ripple',
      coinSymbol: 'XRP',
      priceTarget: 0.6,
      isAbove: true,
      isTriggered: false,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      notes: '0.6 달러 돌파 시 추세 전환 예상',
    ),
    PriceAlert(
      id: '5',
      userId: 'user1',
      coinId: 'cardano',
      coinSymbol: 'ADA',
      priceTarget: 0.4,
      isAbove: false,
      isTriggered: true,
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      triggeredAt: DateTime.now().subtract(const Duration(hours: 12)),
      notes: '지지선 하락 시 장기 보유 전략 검토',
    ),
    PriceAlert(
      id: '6',
      userId: 'user1',
      coinId: 'solana',
      coinSymbol: 'SOL',
      priceTarget: 150.0,
      isAbove: true,
      isTriggered: false,
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
      notes: '강한 상승세, 매도 시점 고려',
    ),
    PriceAlert(
      id: '7',
      userId: 'user1',
      coinId: 'dogecoin',
      coinSymbol: 'DOGE',
      priceTarget: 0.10,
      isAbove: false,
      isTriggered: true,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      triggeredAt: DateTime.now().subtract(const Duration(days: 1)),
      notes: '펀드에서 보유한 물량 추가 매수 고려',
    ),
  ];

  // 대기중 알림 목록 가져오기
  static List<PriceAlert> getPendingAlerts() {
    return userAlerts.where((alert) => !alert.isTriggered).toList();
  }

  // 발생된 알림 목록 가져오기
  static List<PriceAlert> getTriggeredAlerts() {
    return userAlerts.where((alert) => alert.isTriggered).toList();
  }

  // ID로 알림 찾기
  static PriceAlert? getAlertById(String id) {
    try {
      return userAlerts.firstWhere((alert) => alert.id == id);
    } catch (e) {
      return null;
    }
  }

  // 특정 코인에 대한 알림 가져오기
  static List<PriceAlert> getAlertsByCoin(String coinId) {
    return userAlerts.where((alert) => alert.coinId == coinId).toList();
  }
}
