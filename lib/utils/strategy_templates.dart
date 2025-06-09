/// 단타매매 전략 템플릿 유틸리티 클래스
/// 각 전략별 기본 설정과 조건을 템플릿으로 제공합니다.
class StrategyTemplates {
  /// 지원하는 모든 전략 목록 반환
  /// 반환: 전략 정보 리스트 (name, displayName, description, riskLevel)
  static List<Map<String, dynamic>> getAllStrategies() {
    return [
      {
        'name': 'breakout',
        'displayName': '돌파매매',
        'description': '저항선/지지선 돌파 시점 포착',
        'riskLevel': 'high',
        'category': 'momentum',
      },
      {
        'name': 'pullback',
        'displayName': '눌림목 매매',
        'description': '상승 추세 중 일시적 하락 후 재상승',
        'riskLevel': 'medium',
        'category': 'trend',
      },
      {
        'name': 'rsi_reversal',
        'displayName': 'RSI 반등',
        'description': 'RSI 과매도/과매수 구간 반전 신호',
        'riskLevel': 'low',
        'category': 'oscillator',
      },
      {
        'name': 'golden_cross',
        'displayName': '골든크로스',
        'description': '단기 이동평균이 장기 이동평균 상향 돌파',
        'riskLevel': 'medium',
        'category': 'moving_average',
      },
      {
        'name': 'dead_cross',
        'displayName': '데드크로스',
        'description': '단기 이동평균이 장기 이동평균 하향 돌파',
        'riskLevel': 'medium',
        'category': 'moving_average',
      },
      {
        'name': 'candle_pattern',
        'displayName': '캔들 패턴',
        'description': '특정 캔들 패턴 (해머, 도지, 엔걸핑 등)',
        'riskLevel': 'medium',
        'category': 'pattern',
      },
    ];
  }

  /// 특정 전략의 기본 템플릿 반환
  /// [strategyName] 전략명
  /// 반환: 기본 트리거 조건 Map
  static Map<String, dynamic> getDefaultTemplate(String strategyName) {
    switch (strategyName) {
      case 'breakout':
        return _getBreakoutTemplate();
      case 'pullback':
        return _getPullbackTemplate();
      case 'rsi_reversal':
        return _getRsiReversalTemplate();
      case 'golden_cross':
        return _getGoldenCrossTemplate();
      case 'dead_cross':
        return _getDeadCrossTemplate();
      case 'candle_pattern':
        return _getCandlePatternTemplate();
      default:
        return {};
    }
  }

  /// 돌파매매 기본 템플릿
  static Map<String, dynamic> _getBreakoutTemplate() {
    return {
      'type': 'breakout',
      'period': 24, // 분석 기간 (시간)
      'breakoutType': 'upward', // 'upward' or 'downward'
      'threshold': 3.0, // 돌파 임계값 (%)
      'minVolumeRatio': 2.0, // 최소 거래량 비율
      'confirmationPeriod': 1, // 확인 기간 (시간)
      'volume_multiplier': 1.5, // 평균 거래량의 배수
      'price_threshold': 0.02, // 돌파 임계값 (2%)
      'description': '24시간 고점/저점 돌파 감지 (거래량 1.5배 이상)',
    };
  }

  /// 눌림목 매매 기본 템플릿
  static Map<String, dynamic> _getPullbackTemplate() {
    return {
      'type': 'pullback',
      'pullbackPercent': 4.0, // 풀백 비율 (%)
      'supportLevel': 0.0, // 지지선 가격 (0이면 자동 계산)
      'trendDirection': 'upward', // 'upward' or 'downward'
      'minVolume': 0.0, // 최소 거래량
      'maxPullback': 8.0, // 최대 풀백 비율 (%)
      'recovery_percent': 0.03, // 반등 확인 비율 (3%)
      'trend_strength': 0.15, // 추세 강도 (15% 이상 상승)
      'rsi_condition': true, // RSI 조건 추가 (과매도 확인)
      'rsi_threshold': 40, // RSI 임계값
      'description': '7일간 15% 이상 상승 후 5-10% 하락에서 3% 반등',
    };
  }

  /// RSI 반등 기본 템플릿
  static Map<String, dynamic> _getRsiReversalTemplate() {
    return {
      'type': 'rsi_reversal',
      'rsiPeriod': 14, // RSI 계산 기간
      'rsiLowerThreshold': 25.0, // 과매도 임계값 (더 엄격하게)
      'rsiUpperThreshold': 75.0, // 과매수 임계값 (더 엄격하게)
      'reversalType': 'oversold', // 'oversold' or 'overbought'
      'confirmationPeriod': 2, // 확인 기간
      'volumeIncrease': true, // 거래량 증가 확인
      'price_confirmation': true, // 가격 확인 여부
      'min_reversal_percent': 0.02, // 최소 반전 비율 (2%)
      'volume_factor': 1.2, // 거래량 조건 (평균의 1.2배)
      'description': 'RSI 30 이하에서 상승 반전 시그널 감지',
    };
  }

  /// 골든크로스 기본 템플릿
  static Map<String, dynamic> _getGoldenCrossTemplate() {
    return {
      'type': 'golden_cross',
      'shortPeriod': 5, // 단기 이동평균 기간 (일)
      'longPeriod': 20, // 장기 이동평균 기간 (일)
      'crossType': 'golden', // 'golden' or 'dead'
      'minAngle': 5.0, // 최소 기울기 각도
      'volumeConfirmation': true, // 거래량 확인
      'volume_multiplier': 1.3, // 거래량 배수
      'cross_angle': 5, // 교차 각도 (도)
      'price_above_ma': true, // 가격이 이동평균 위에 있어야 함
      'recent_trend': 'bullish', // 최근 추세 조건
      'description': '20일선이 50일선을 상향 돌파 (골든크로스)',
    };
  }

  /// 데드크로스 기본 템플릿
  static Map<String, dynamic> _getDeadCrossTemplate() {
    return {
      'type': 'dead_cross',
      'shortPeriod': 5, // 단기 이동평균 기간 (일)
      'longPeriod': 20, // 장기 이동평균 기간 (일)
      'crossType': 'dead', // 'golden' or 'dead'
      'minAngle': 5.0, // 최소 기울기 각도 (하락)
      'volumeConfirmation': true, // 거래량 확인
      'volume_multiplier': 1.3, // 거래량 배수
      'cross_angle': 5, // 교차 각도 (도)
      'price_below_ma': true, // 가격이 이동평균 아래에 있어야 함
      'recent_trend': 'bearish', // 최근 추세 조건
      'description': '20일선이 50일선을 하향 돌파 (데드크로스)',
    };
  }

  /// 캔들 패턴 기본 템플릿
  static Map<String, dynamic> _getCandlePatternTemplate() {
    return {
      'type': 'candle_pattern',
      'patternType': 'hammer', // 'hammer', 'doji', 'engulfing', 'shooting_star'
      'confirmationCandles': 2, // 확인용 캔들 수
      'minBodyRatio': 0.6, // 최소 몸통 비율
      'maxWickRatio': 0.3, // 최대 꼬리 비율
      'volumeWeight': 1.5, // 거래량 가중치
      'confirmation_required': true, // 다음 캔들 확인 필요
      'volume_condition': true, // 거래량 조건
      'shadow_ratio': 2.0, // 그림자 비율
      'trend_context': true, // 추세 맥락 고려
      'lookback_period': 20, // 패턴 확인 기간
      'description': '해머, 도지, 엔걸핑 등 주요 캔들 패턴 감지',
    };
  }

  /// 위험도별 기본 설정 반환
  /// [riskLevel] 위험도 (low, medium, high)
  /// 반환: 위험도별 설정 Map
  static Map<String, dynamic> getRiskLevelSettings(String riskLevel) {
    switch (riskLevel) {
      case 'low':
        return {
          'confirmation_period': 8, // 확인 기간 (시간) - 길게
          'min_volume_multiplier': 1.5, // 최소 거래량 배수 - 높게
          'profit_target': 0.05, // 수익 목표 (5%) - 낮게
          'stop_loss': 0.03, // 손절 비율 (3%) - 낮게
          'max_alerts_per_day': 3, // 일일 최대 알림 수 - 적게
          'cooldown_hours': 6, // 쿨다운 시간 - 길게
        };
      case 'medium':
        return {
          'confirmation_period': 4, // 확인 기간 (시간)
          'min_volume_multiplier': 1.3, // 최소 거래량 배수
          'profit_target': 0.08, // 수익 목표 (8%)
          'stop_loss': 0.05, // 손절 비율 (5%)
          'max_alerts_per_day': 5, // 일일 최대 알림 수
          'cooldown_hours': 4, // 쿨다운 시간
        };
      case 'high':
        return {
          'confirmation_period': 2, // 확인 기간 (시간) - 짧게
          'min_volume_multiplier': 1.1, // 최소 거래량 배수 - 낮게
          'profit_target': 0.12, // 수익 목표 (12%) - 높게
          'stop_loss': 0.08, // 손절 비율 (8%) - 높게
          'max_alerts_per_day': 10, // 일일 최대 알림 수 - 많게
          'cooldown_hours': 2, // 쿨다운 시간 - 짧게
        };
      default:
        return getRiskLevelSettings('medium');
    }
  }

  /// 전략과 위험도를 조합한 완전한 템플릿 반환
  /// [strategyName] 전략명
  /// [riskLevel] 위험도
  /// 반환: 조합된 템플릿
  static Map<String, dynamic> getCompleteTemplate(
    String strategyName,
    String riskLevel,
  ) {
    final strategyTemplate = getDefaultTemplate(strategyName);
    final riskSettings = getRiskLevelSettings(riskLevel);

    // 두 템플릿을 병합
    return {
      ...strategyTemplate,
      'risk_settings': riskSettings,
      'strategy_name': strategyName,
      'risk_level': riskLevel,
    };
  }

  /// 전략별 설명 텍스트 반환
  /// [strategyName] 전략명
  /// 반환: 상세 설명 텍스트
  static String getStrategyDescription(String strategyName) {
    final strategies = getAllStrategies();
    final strategy = strategies.firstWhere(
      (s) => s['name'] == strategyName,
      orElse: () => {'description': '알 수 없는 전략'},
    );
    return strategy['description'] ?? '설명이 없습니다.';
  }

  /// 전략별 표시명 반환
  /// [strategyName] 전략명
  /// 반환: 한국어 표시명
  static String getStrategyDisplayName(String strategyName) {
    final strategies = getAllStrategies();
    final strategy = strategies.firstWhere(
      (s) => s['name'] == strategyName,
      orElse: () => {'displayName': strategyName},
    );
    return strategy['displayName'] ?? strategyName;
  }

  /// 카테고리별 전략 목록 반환
  /// [category] 카테고리명
  /// 반환: 해당 카테고리의 전략 목록
  static List<Map<String, dynamic>> getStrategiesByCategory(String category) {
    return getAllStrategies()
        .where((strategy) => strategy['category'] == category)
        .toList();
  }

  /// 위험도별 전략 목록 반환
  /// [riskLevel] 위험도
  /// 반환: 해당 위험도의 전략 목록
  static List<Map<String, dynamic>> getStrategiesByRiskLevel(String riskLevel) {
    return getAllStrategies()
        .where((strategy) => strategy['riskLevel'] == riskLevel)
        .toList();
  }

  /// 전략 템플릿 유효성 검사
  /// [template] 검사할 템플릿
  /// 반환: 유효성 검사 결과 {isValid: bool, errors: List<String>}
  static Map<String, dynamic> validateTemplate(Map<String, dynamic> template) {
    List<String> errors = [];

    // 필수 필드 확인
    if (!template.containsKey('type')) {
      errors.add('전략 타입이 지정되지 않았습니다.');
    }

    // 전략별 필수 필드 확인
    final type = template['type'];
    switch (type) {
      case 'breakout':
        if (!template.containsKey('period')) {
          errors.add('돌파매매: 기준 기간이 지정되지 않았습니다.');
        }
        break;
      case 'rsi_reversal':
        if (!template.containsKey('rsiPeriod')) {
          errors.add('RSI 반등: RSI 기간이 지정되지 않았습니다.');
        }
        if (!template.containsKey('rsiLowerThreshold') &&
            !template.containsKey('rsiUpperThreshold')) {
          errors.add('RSI 반등: 과매도/과매수 임계값이 지정되지 않았습니다.');
        }
        break;
      // 다른 전략들도 필요에 따라 추가
    }

    return {'isValid': errors.isEmpty, 'errors': errors};
  }
}
