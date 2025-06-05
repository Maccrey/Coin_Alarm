// 더 이상 사용하지 않음 - Supabase 연동으로 대체, 삭제 예정

import '../model/coin_model.dart';

// 더미 코인 데이터
class DummyCoins {
  // 인기 코인 리스트
  static List<Coin> popularCoins = [
    Coin(
      id: 'bitcoin',
      name: '비트코인',
      symbol: 'BTC',
      currentPrice: 68421.56,
      priceChange24h: 1254.32,
      priceChangePercentage24h: 1.87,
      marketCap: 1345678901234,
      volume24h: 38762451298,
      high24h: 69123.45,
      low24h: 67890.12,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 2)),
      imageUrl: 'https://assets.coingecko.com/coins/images/1/large/bitcoin.png',
    ),
    Coin(
      id: 'ethereum',
      name: '이더리움',
      symbol: 'ETH',
      currentPrice: 3624.78,
      priceChange24h: -89.23,
      priceChangePercentage24h: -2.4,
      marketCap: 435612789012,
      volume24h: 15687423190,
      high24h: 3710.45,
      low24h: 3590.12,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 3)),
      imageUrl:
          'https://assets.coingecko.com/coins/images/279/large/ethereum.png',
    ),
    Coin(
      id: 'binancecoin',
      name: '바이낸스 코인',
      symbol: 'BNB',
      currentPrice: 608.12,
      priceChange24h: 12.34,
      priceChangePercentage24h: 2.07,
      marketCap: 95123456789,
      volume24h: 3245678901,
      high24h: 615.45,
      low24h: 598.76,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 4)),
      imageUrl:
          'https://assets.coingecko.com/coins/images/825/large/binance-coin-logo.png',
    ),
    Coin(
      id: 'ripple',
      name: '리플',
      symbol: 'XRP',
      currentPrice: 0.5321,
      priceChange24h: 0.0234,
      priceChangePercentage24h: 4.6,
      marketCap: 28345678901,
      volume24h: 1567890123,
      high24h: 0.5430,
      low24h: 0.5187,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 5)),
      imageUrl:
          'https://assets.coingecko.com/coins/images/44/large/xrp-symbol-white-128.png',
    ),
    Coin(
      id: 'cardano',
      name: '카르다노',
      symbol: 'ADA',
      currentPrice: 0.4523,
      priceChange24h: -0.0123,
      priceChangePercentage24h: -2.65,
      marketCap: 15789012345,
      volume24h: 987654321,
      high24h: 0.4678,
      low24h: 0.4498,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 6)),
      imageUrl:
          'https://assets.coingecko.com/coins/images/975/large/cardano.png',
    ),
    Coin(
      id: 'solana',
      name: '솔라나',
      symbol: 'SOL',
      currentPrice: 143.67,
      priceChange24h: 5.43,
      priceChangePercentage24h: 3.92,
      marketCap: 65432109876,
      volume24h: 3456789012,
      high24h: 145.89,
      low24h: 138.21,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 7)),
      imageUrl:
          'https://assets.coingecko.com/coins/images/4128/large/solana.png',
    ),
    Coin(
      id: 'dogecoin',
      name: '도지코인',
      symbol: 'DOGE',
      currentPrice: 0.1234,
      priceChange24h: 0.0056,
      priceChangePercentage24h: 4.76,
      marketCap: 16543210987,
      volume24h: 2345678901,
      high24h: 0.1245,
      low24h: 0.1189,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 8)),
      imageUrl:
          'https://assets.coingecko.com/coins/images/5/large/dogecoin.png',
    ),
  ];

  // 전체 코인 리스트 (더 많은 코인 포함)
  static List<Coin> allCoins = [
    ...popularCoins,
    Coin(
      id: 'polkadot',
      name: '폴카닷',
      symbol: 'DOT',
      currentPrice: 6.78,
      priceChange24h: -0.24,
      priceChangePercentage24h: -3.42,
      marketCap: 9876543210,
      volume24h: 876543210,
      high24h: 7.01,
      low24h: 6.74,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 8)),
      imageUrl:
          'https://assets.coingecko.com/coins/images/12171/large/polkadot.png',
    ),
    Coin(
      id: 'avalanche',
      name: '아발란체',
      symbol: 'AVAX',
      currentPrice: 35.67,
      priceChange24h: 1.23,
      priceChangePercentage24h: 3.57,
      marketCap: 12765432109,
      volume24h: 765432109,
      high24h: 36.12,
      low24h: 34.56,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 10)),
      imageUrl:
          'https://assets.coingecko.com/coins/images/12559/large/Avalanche_Circle_RedWhite_Trans.png',
    ),
    Coin(
      id: 'uniswap',
      name: '유니스왑',
      symbol: 'UNI',
      currentPrice: 8.91,
      priceChange24h: -0.32,
      priceChangePercentage24h: -3.47,
      marketCap: 4567890123,
      volume24h: 678901234,
      high24h: 9.23,
      low24h: 8.87,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 11)),
      imageUrl:
          'https://assets.coingecko.com/coins/images/12504/large/uniswap-uni.png',
    ),
    Coin(
      id: 'chainlink',
      name: '체인링크',
      symbol: 'LINK',
      currentPrice: 13.45,
      priceChange24h: 0.56,
      priceChangePercentage24h: 4.34,
      marketCap: 7654321098,
      volume24h: 543210987,
      high24h: 13.67,
      low24h: 12.98,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 12)),
      imageUrl:
          'https://assets.coingecko.com/coins/images/877/large/chainlink-new-logo.png',
    ),
    Coin(
      id: 'polygon',
      name: '폴리곤',
      symbol: 'MATIC',
      currentPrice: 0.67,
      priceChange24h: 0.04,
      priceChangePercentage24h: 6.35,
      marketCap: 6789012345,
      volume24h: 890123456,
      high24h: 0.68,
      low24h: 0.63,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 13)),
      imageUrl:
          'https://assets.coingecko.com/coins/images/4713/large/matic-token-icon.png',
    ),
    Coin(
      id: 'cosmos',
      name: '코스모스',
      symbol: 'ATOM',
      currentPrice: 8.76,
      priceChange24h: -0.45,
      priceChangePercentage24h: -4.89,
      marketCap: 3456789012,
      volume24h: 345678901,
      high24h: 9.12,
      low24h: 8.65,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 14)),
      imageUrl:
          'https://assets.coingecko.com/coins/images/1481/large/cosmos_hub.png',
    ),
    Coin(
      id: 'arbitrum',
      name: '아비트럼',
      symbol: 'ARB',
      currentPrice: 1.21,
      priceChange24h: 0.08,
      priceChangePercentage24h: 7.08,
      marketCap: 3123456789,
      volume24h: 432109876,
      high24h: 1.25,
      low24h: 1.13,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 15)),
      imageUrl:
          'https://assets.coingecko.com/coins/images/16547/large/photo_2023-03-29_21.47.00.jpeg',
    ),
  ];

  // 인기 순위별 코인 가져오기
  static List<Coin> getPopularCoins() {
    return popularCoins;
  }

  // 코인 심볼로 코인 찾기
  static Coin? getCoinBySymbol(String symbol) {
    try {
      return popularCoins.firstWhere(
        (coin) => coin.symbol.toLowerCase() == symbol.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  // 코인 ID로 코인 찾기
  static Coin? getCoinById(String id) {
    try {
      return popularCoins.firstWhere(
        (coin) => coin.id.toLowerCase() == id.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }
}
