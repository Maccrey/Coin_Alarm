// 더 이상 사용하지 않음 - Supabase 연동으로 대체, 삭제 예정

import '../model/news_model.dart';

// 더미 뉴스 데이터
class DummyNews {
  // 뉴스 목록
  static List<News> newsList = [
    News(
      id: '1',
      title: '비트코인, 역대 최고가 경신 후 소폭 하락',
      content:
          '비트코인이 어제 역대 최고가인 73,800달러를 경신한 후 소폭 하락했습니다. 전문가들은 단기 조정 후 상승세가 계속될 것으로 전망하고 있습니다. "이번 상승은 기관 투자자들의 참여가 크게 증가한 것이 주요 원인"이라고 분석했습니다. 특히 미국 ETF 자금 유입이 지속되면서 추가 상승 여력이 있다는 의견이 지배적입니다.',
      source: 'CoinDesk Korea',
      url: 'https://example.com/news/1',
      publishedAt: DateTime.now().subtract(const Duration(hours: 3)),
      relatedCoins: ['bitcoin'],
      imageUrl: 'https://images.unsplash.com/photo-1518546305927-5a555bb7020d',
    ),
    News(
      id: '2',
      title: '이더리움 상하이 업그레이드, 거래 수수료 65% 감소 효과',
      content:
          '이더리움 재단이 발표한 자료에 따르면, 최근 진행된 상하이 업그레이드 이후 네트워크 거래 수수료가 평균 65% 감소한 것으로 나타났습니다. 이는 EIP-4844 프로토콜 업데이트로 인한 레이어2 솔루션의 데이터 처리 효율성 향상 때문입니다. 개발자들은 "이번 업그레이드는 이더리움 생태계의 확장성을 크게 개선하는 중요한 이정표"라고 평가했습니다.',
      source: 'Decrypt',
      url: 'https://example.com/news/2',
      publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
      relatedCoins: ['ethereum'],
      imageUrl: 'https://images.unsplash.com/photo-1639762681057-408e52192e55',
    ),
    News(
      id: '3',
      title: '바이낸스, 새로운 규제 준수 이니셔티브 발표',
      content:
          '세계 최대 암호화폐 거래소 바이낸스가 글로벌 규제 준수를 강화하기 위한 새로운 이니셔티브를 발표했습니다. 이 프로그램은 KYC 프로세스 강화, 실시간 거래 모니터링 시스템 개선, 규제 기관과의 협력 확대 등을 포함합니다. CEO 창펑 자오는 "암호화폐 산업이 주류 금융으로 진입하기 위해서는 규제 준수가 필수적"이라며 "이러한 노력이 업계 전반의 신뢰를 높이는 데 기여할 것"이라고 말했습니다.',
      source: 'Bloomberg Crypto',
      url: 'https://example.com/news/3',
      publishedAt: DateTime.now().subtract(const Duration(hours: 8)),
      relatedCoins: ['binancecoin'],
      imageUrl: 'https://images.unsplash.com/photo-1621761191319-c6fb62004040',
    ),
    News(
      id: '4',
      title: '리플, SEC와의 법적 분쟁에서 부분 승리',
      content:
          '리플 랩스가 미국 증권거래위원회(SEC)와의 오랜 법적 분쟁에서 중요한 부분 승리를 거뒀습니다. 연방 법원은 XRP 토큰 자체가 증권이 아니라는 판결을 내렸으며, 이는 암호화폐 산업 전체에 중요한 선례가 될 것으로 보입니다. 리플의 CEO 브래드 갈링하우스는 "이번 판결은 암호화폐에 대한 법적 명확성을 제공하는 중요한 진전"이라고 평가했습니다. 그러나 SEC는 이 판결에 항소할 가능성이 있어 법적 불확실성은 여전히 남아있습니다.',
      source: 'The Block',
      url: 'https://example.com/news/4',
      publishedAt: DateTime.now().subtract(const Duration(hours: 12)),
      relatedCoins: ['ripple'],
      imageUrl: 'https://images.unsplash.com/photo-1621504450181-5fdb1eaeb4c0',
    ),
    News(
      id: '5',
      title: '카르다노, 새로운 스마트 컨트랙트 기능 출시 예정',
      content:
          '카르다노 재단이 다음 달 플루투스 V3라는 이름의 새로운 스마트 컨트랙트 기능을 출시할 예정이라고 발표했습니다. 이 업데이트는 개발자들에게 더 강력한 도구와 언어 기능을 제공하여 복잡한 DeFi 애플리케이션 개발을 용이하게 할 것으로 기대됩니다. 카르다노 창립자 찰스 호스킨슨은 "이번 업데이트로 카르다노 생태계의 개발자 경험이 크게 향상될 것"이라고 밝혔습니다.',
      source: 'CoinTelegraph',
      url: 'https://example.com/news/5',
      publishedAt: DateTime.now().subtract(const Duration(hours: 24)),
      relatedCoins: ['cardano'],
      imageUrl: 'https://images.unsplash.com/photo-1622538387312-dfd0d828d258',
    ),
    News(
      id: '6',
      title: '솔라나, 새로운 온체인 게임 플랫폼 출시',
      content:
          '솔라나 재단이 블록체인 게임 개발을 위한 새로운 온체인 게임 플랫폼 솔라나 플레이를 출시했습니다. 이 플랫폼은 게임 개발자들에게 낮은 수수료와 빠른 트랜잭션 속도를 제공하며, 기존 게임 엔진과의 통합을 용이하게 합니다. 솔라나 공동 창립자 아나톨리 야코벤코는 "웹3 게임의 미래는 사용자 경험에 달려있으며, 솔라나의 기술력은 이를 가능하게 한다"고 말했습니다. 이미 20개 이상의 게임 스튜디오가 이 플랫폼을 활용한 게임 개발을 시작했다고 합니다.',
      source: 'GamesBeat',
      url: 'https://example.com/news/6',
      publishedAt: DateTime.now().subtract(const Duration(hours: 36)),
      relatedCoins: ['solana'],
      imageUrl: 'https://images.unsplash.com/photo-1616500888248-2914fb8ad4d6',
    ),
    News(
      id: '7',
      title: '도지코인, 트위터 결제 시스템 통합 소식에 급등',
      content:
          '일론 머스크가 트위터(현 X)에 암호화폐 결제 시스템을 통합할 계획이며 도지코인이 지원될 것이라는 소식에 도지코인 가격이 24시간 내 30% 이상 급등했습니다. 아직 공식 발표는 없지만, 내부 소식통에 따르면 트위터는 이미 여러 규제 기관으로부터 디지털 자산 결제 라이선스를 취득한 상태라고 합니다. 암호화폐 분석가들은 "이러한 통합이 실현된다면 도지코인의 유틸리티와 채택률이 크게 증가할 수 있다"고 전망했습니다.',
      source: 'Reuters Tech',
      url: 'https://example.com/news/7',
      publishedAt: DateTime.now().subtract(const Duration(days: 2)),
      relatedCoins: ['dogecoin'],
      imageUrl: 'https://images.unsplash.com/photo-1622637012691-6c2845efaaa0',
    ),
  ];

  // 최신 뉴스 가져오기
  static List<News> getLatestNews({int limit = 5}) {
    // 최신순으로 정렬 후 요청된 개수만큼 반환
    final sortedNews = List<News>.from(newsList)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return sortedNews.take(limit).toList();
  }

  // 특정 코인 관련 뉴스 가져오기
  static List<News> getNewsByCoin(String coinId, {int limit = 5}) {
    final filteredNews =
        newsList
            .where((news) => news.relatedCoins.contains(coinId.toLowerCase()))
            .toList()
          ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return filteredNews.take(limit).toList();
  }

  // 뉴스 ID로 찾기
  static News? getNewsById(String id) {
    try {
      return newsList.firstWhere((news) => news.id == id);
    } catch (e) {
      return null;
    }
  }

  // 인기 뉴스 가져오기 (임의 선택)
  static List<News> getPopularNews({int limit = 3}) {
    final list = [newsList[0], newsList[2], newsList[4], newsList[6]];
    return list.take(limit).toList();
  }
}
