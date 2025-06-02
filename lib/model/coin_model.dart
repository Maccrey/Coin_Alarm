// 코인 모델 클래스

class Coin {
  final String id;
  final String name;
  final String symbol;
  final double currentPrice;
  final double? priceChange24h;
  final double? priceChangePercentage24h;
  final double? marketCap;
  final double? volume24h;
  final double? high24h;
  final double? low24h;
  final DateTime lastUpdated;
  final String? imageUrl;

  Coin({
    required this.id,
    required this.name,
    required this.symbol,
    required this.currentPrice,
    this.priceChange24h,
    this.priceChangePercentage24h,
    this.marketCap,
    this.volume24h,
    this.high24h,
    this.low24h,
    required this.lastUpdated,
    this.imageUrl,
  });

  // 가격 상승 여부
  bool get isPriceUp => (priceChangePercentage24h ?? 0) >= 0;

  // JSON에서 변환
  factory Coin.fromJson(Map<String, dynamic> json) {
    return Coin(
      id: json['id'],
      name: json['name'],
      symbol: json['symbol'],
      currentPrice: json['current_price'].toDouble(),
      priceChange24h: json['price_change_24h']?.toDouble(),
      priceChangePercentage24h: json['price_change_percentage_24h']?.toDouble(),
      marketCap: json['market_cap']?.toDouble(),
      volume24h: json['total_volume']?.toDouble(),
      high24h: json['high_24h']?.toDouble(),
      low24h: json['low_24h']?.toDouble(),
      lastUpdated: DateTime.parse(json['last_updated']),
      imageUrl: json['image'],
    );
  }

  // JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'symbol': symbol,
      'current_price': currentPrice,
      'price_change_24h': priceChange24h,
      'price_change_percentage_24h': priceChangePercentage24h,
      'market_cap': marketCap,
      'total_volume': volume24h,
      'high_24h': high24h,
      'low_24h': low24h,
      'last_updated': lastUpdated.toIso8601String(),
      'image': imageUrl,
    };
  }

  // 가격 변화율 (% 형식, 소수점 2자리)
  String get priceChangePercent {
    if (priceChangePercentage24h != null) {
      return '${priceChangePercentage24h!.toStringAsFixed(2)}%';
    } else if (currentPrice > 0) {
      // 가격 변화율이 없는 경우 현재 가격 대비 계산
      final percent = (priceChange24h ?? 0 / currentPrice) * 100;
      return '${percent.toStringAsFixed(2)}%';
    }
    return '0.00%';
  }

  // Coin 객체 복사본 생성 (필드 업데이트 가능)
  Coin copyWith({
    String? id,
    String? name,
    String? symbol,
    double? currentPrice,
    double? priceChange24h,
    double? priceChangePercentage24h,
    double? marketCap,
    double? volume24h,
    double? high24h,
    double? low24h,
    DateTime? lastUpdated,
    String? imageUrl,
  }) {
    return Coin(
      id: id ?? this.id,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      currentPrice: currentPrice ?? this.currentPrice,
      priceChange24h: priceChange24h ?? this.priceChange24h,
      priceChangePercentage24h:
          priceChangePercentage24h ?? this.priceChangePercentage24h,
      marketCap: marketCap ?? this.marketCap,
      volume24h: volume24h ?? this.volume24h,
      high24h: high24h ?? this.high24h,
      low24h: low24h ?? this.low24h,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
