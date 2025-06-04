-- Migration: 002_sample_data.sql
-- 코인 알람 앱을 위한 샘플 데이터

-- 코인 샘플 데이터 삽입
INSERT INTO coins (id, symbol, name, image_url, description)
VALUES
  ('bitcoin', 'BTC', 'Bitcoin', 'https://cryptologos.cc/logos/bitcoin-btc-logo.png', '비트코인은 2009년 사토시 나카모토가 만든 최초의 암호화폐입니다.'),
  ('ethereum', 'ETH', 'Ethereum', 'https://cryptologos.cc/logos/ethereum-eth-logo.png', '이더리움은 스마트 계약 기능을 갖춘 분산형 플랫폼입니다.'),
  ('ripple', 'XRP', 'XRP', 'https://cryptologos.cc/logos/xrp-xrp-logo.png', 'XRP는 리플 네트워크의 기본 암호화폐로, 빠른 국제 송금을 목표로 합니다.'),
  ('solana', 'SOL', 'Solana', 'https://cryptologos.cc/logos/solana-sol-logo.png', '솔라나는 고성능 블록체인으로 초당 수천 건의 트랜잭션을 처리할 수 있습니다.'),
  ('dogecoin', 'DOGE', 'Dogecoin', 'https://cryptologos.cc/logos/dogecoin-doge-logo.png', '도지코인은 시바 이누 개를 마스코트로 한 밈 코인입니다.')
ON CONFLICT (id) DO UPDATE SET
  symbol = EXCLUDED.symbol,
  name = EXCLUDED.name,
  image_url = EXCLUDED.image_url,
  description = EXCLUDED.description,
  updated_at = NOW();

-- 가격 이력 샘플 데이터 삽입 (최근 7일간의 가격)
-- 비트코인 (BTC) 가격 이력
INSERT INTO price_history (coin_id, price, market_cap, volume_24h, timestamp)
VALUES
  ('bitcoin', 65000.00, 1200000000000, 30000000000, NOW() - INTERVAL '7 days'),
  ('bitcoin', 64500.00, 1190000000000, 29500000000, NOW() - INTERVAL '6 days'),
  ('bitcoin', 66000.00, 1210000000000, 31000000000, NOW() - INTERVAL '5 days'),
  ('bitcoin', 67200.00, 1230000000000, 32500000000, NOW() - INTERVAL '4 days'),
  ('bitcoin', 68500.00, 1250000000000, 33000000000, NOW() - INTERVAL '3 days'),
  ('bitcoin', 67800.00, 1240000000000, 31500000000, NOW() - INTERVAL '2 days'),
  ('bitcoin', 69000.00, 1260000000000, 34000000000, NOW() - INTERVAL '1 day')
ON CONFLICT (coin_id, timestamp) DO UPDATE SET
  price = EXCLUDED.price,
  market_cap = EXCLUDED.market_cap,
  volume_24h = EXCLUDED.volume_24h;

-- 이더리움 (ETH) 가격 이력
INSERT INTO price_history (coin_id, price, market_cap, volume_24h, timestamp)
VALUES
  ('ethereum', 3400.00, 410000000000, 15000000000, NOW() - INTERVAL '7 days'),
  ('ethereum', 3350.00, 405000000000, 14500000000, NOW() - INTERVAL '6 days'),
  ('ethereum', 3500.00, 420000000000, 16000000000, NOW() - INTERVAL '5 days'),
  ('ethereum', 3600.00, 430000000000, 17000000000, NOW() - INTERVAL '4 days'),
  ('ethereum', 3650.00, 435000000000, 17500000000, NOW() - INTERVAL '3 days'),
  ('ethereum', 3550.00, 425000000000, 16500000000, NOW() - INTERVAL '2 days'),
  ('ethereum', 3700.00, 440000000000, 18000000000, NOW() - INTERVAL '1 day')
ON CONFLICT (coin_id, timestamp) DO UPDATE SET
  price = EXCLUDED.price,
  market_cap = EXCLUDED.market_cap,
  volume_24h = EXCLUDED.volume_24h;

-- XRP 가격 이력
INSERT INTO price_history (coin_id, price, market_cap, volume_24h, timestamp)
VALUES
  ('ripple', 0.48, 24000000000, 1200000000, NOW() - INTERVAL '7 days'),
  ('ripple', 0.47, 23500000000, 1150000000, NOW() - INTERVAL '6 days'),
  ('ripple', 0.50, 25000000000, 1300000000, NOW() - INTERVAL '5 days'),
  ('ripple', 0.52, 26000000000, 1400000000, NOW() - INTERVAL '4 days'),
  ('ripple', 0.53, 26500000000, 1450000000, NOW() - INTERVAL '3 days'),
  ('ripple', 0.51, 25500000000, 1350000000, NOW() - INTERVAL '2 days'),
  ('ripple', 0.54, 27000000000, 1500000000, NOW() - INTERVAL '1 day')
ON CONFLICT (coin_id, timestamp) DO UPDATE SET
  price = EXCLUDED.price,
  market_cap = EXCLUDED.market_cap,
  volume_24h = EXCLUDED.volume_24h;

-- 솔라나 (SOL) 가격 이력
INSERT INTO price_history (coin_id, price, market_cap, volume_24h, timestamp)
VALUES
  ('solana', 120.00, 48000000000, 2400000000, NOW() - INTERVAL '7 days'),
  ('solana', 118.00, 47200000000, 2350000000, NOW() - INTERVAL '6 days'),
  ('solana', 125.00, 50000000000, 2500000000, NOW() - INTERVAL '5 days'),
  ('solana', 130.00, 52000000000, 2600000000, NOW() - INTERVAL '4 days'),
  ('solana', 135.00, 54000000000, 2700000000, NOW() - INTERVAL '3 days'),
  ('solana', 132.00, 52800000000, 2640000000, NOW() - INTERVAL '2 days'),
  ('solana', 138.00, 55200000000, 2760000000, NOW() - INTERVAL '1 day')
ON CONFLICT (coin_id, timestamp) DO UPDATE SET
  price = EXCLUDED.price,
  market_cap = EXCLUDED.market_cap,
  volume_24h = EXCLUDED.volume_24h;

-- 도지코인 (DOGE) 가격 이력
INSERT INTO price_history (coin_id, price, market_cap, volume_24h, timestamp)
VALUES
  ('dogecoin', 0.12, 16800000000, 840000000, NOW() - INTERVAL '7 days'),
  ('dogecoin', 0.118, 16520000000, 826000000, NOW() - INTERVAL '6 days'),
  ('dogecoin', 0.125, 17500000000, 875000000, NOW() - INTERVAL '5 days'),
  ('dogecoin', 0.13, 18200000000, 910000000, NOW() - INTERVAL '4 days'),
  ('dogecoin', 0.135, 18900000000, 945000000, NOW() - INTERVAL '3 days'),
  ('dogecoin', 0.132, 18480000000, 924000000, NOW() - INTERVAL '2 days'),
  ('dogecoin', 0.138, 19320000000, 966000000, NOW() - INTERVAL '1 day')
ON CONFLICT (coin_id, timestamp) DO UPDATE SET
  price = EXCLUDED.price,
  market_cap = EXCLUDED.market_cap,
  volume_24h = EXCLUDED.volume_24h;

-- 차트 데이터 캐시 샘플
INSERT INTO chart_data (symbol, exchange, timeframe, chart_type, data, timestamp)
VALUES
  ('BTC', 'upbit', '1d', 'candlestick', 
   '[
      {"time": "2024-06-10", "open": 65000, "high": 65500, "low": 64000, "close": 64500, "volume": 10000},
      {"time": "2024-06-11", "open": 64500, "high": 66500, "low": 64000, "close": 66000, "volume": 12000},
      {"time": "2024-06-12", "open": 66000, "high": 67500, "low": 65800, "close": 67200, "volume": 15000},
      {"time": "2024-06-13", "open": 67200, "high": 69000, "low": 67000, "close": 68500, "volume": 14000},
      {"time": "2024-06-14", "open": 68500, "high": 68800, "low": 67000, "close": 67800, "volume": 13000},
      {"time": "2024-06-15", "open": 67800, "high": 69500, "low": 67500, "close": 69000, "volume": 16000},
      {"time": "2024-06-16", "open": 69000, "high": 70000, "low": 68500, "close": 69800, "volume": 18000}
    ]'::jsonb,
   NOW()),
  ('ETH', 'upbit', '1d', 'candlestick', 
   '[
      {"time": "2024-06-10", "open": 3400, "high": 3450, "low": 3300, "close": 3350, "volume": 5000},
      {"time": "2024-06-11", "open": 3350, "high": 3550, "low": 3300, "close": 3500, "volume": 6000},
      {"time": "2024-06-12", "open": 3500, "high": 3650, "low": 3480, "close": 3600, "volume": 7000},
      {"time": "2024-06-13", "open": 3600, "high": 3700, "low": 3550, "close": 3650, "volume": 6500},
      {"time": "2024-06-14", "open": 3650, "high": 3680, "low": 3500, "close": 3550, "volume": 6000},
      {"time": "2024-06-15", "open": 3550, "high": 3750, "low": 3520, "close": 3700, "volume": 7500},
      {"time": "2024-06-16", "open": 3700, "high": 3800, "low": 3650, "close": 3750, "volume": 8000}
    ]'::jsonb,
   NOW())
ON CONFLICT (symbol, exchange, timeframe, chart_type) DO UPDATE SET
  data = EXCLUDED.data,
  timestamp = EXCLUDED.timestamp; 