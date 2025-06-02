// 코인 모델 클래스

class Coin {
  final String id;
  final String name;
  final String symbol;
  final double currentPrice;
  final double priceChange24h;
  final double? priceChangePercentage24h;
  final double marketCap;
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
    required this.priceChange24h,
    this.priceChangePercentage24h,
    required this.marketCap,
    this.volume24h,
    this.high24h,
    this.low24h,
    required this.lastUpdated,
    this.imageUrl,
  });

  // JSON 데이터로부터 Coin 객체 생성
  factory Coin.fromJson(Map<String, dynamic> json) {
    return Coin(
      id: json['id'],
      name: json['name'],
      symbol: json['symbol'].toUpperCase(),
      currentPrice: json['current_price']?.toDouble() ?? 0.0,
      priceChange24h: json['price_change_24h']?.toDouble() ?? 0.0,
      priceChangePercentage24h: json['price_change_percentage_24h']?.toDouble(),
      marketCap: json['market_cap']?.toDouble() ?? 0.0,
      volume24h: json['volume_24h']?.toDouble(),
      high24h: json['high_24h']?.toDouble(),
      low24h: json['low_24h']?.toDouble(),
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'])
          : DateTime.now(),
      imageUrl: json['image_url'],
    );
  }

  // Coin 객체를 JSON 데이터로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'symbol': symbol,
      'current_price': currentPrice,
      'price_change_24h': priceChange24h,
      'price_change_percentage_24h': priceChangePercentage24h,
      'market_cap': marketCap,
      'volume_24h': volume24h,
      'high_24h': high24h,
      'low_24h': low24h,
      'last_updated': lastUpdated.toIso8601String(),
      'image_url': imageUrl,
    };
  }

  // 가격 변화의 상승/하락 여부 확인
  bool get isPriceUp => priceChange24h >= 0;

  // 가격 변화율 (% 형식, 소수점 2자리)
  String get priceChangePercent {
    if (priceChangePercentage24h != null) {
      return '${priceChangePercentage24h!.toStringAsFixed(2)}%';
    } else if (currentPrice > 0) {
      // 가격 변화율이 없는 경우 현재 가격 대비 계산
      final percent = (priceChange24h / currentPrice) * 100;
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
