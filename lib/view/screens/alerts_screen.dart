import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../model/price_alert_model.dart';
import '../../data/dummy_alerts.dart';
import '../../data/dummy_coins.dart';

// 알림 화면
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  // 탭 컨트롤러
  late TabController _tabController;

  // 알림 추가 입력 컨트롤러
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedCoinId;
  bool _isAbove = true;

  // 더미 알림 데이터
  late List<PriceAlert> _pendingAlerts;
  late List<PriceAlert> _triggeredAlerts;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 더미 데이터 로드
    _loadDummyData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // 더미 데이터 로드
  void _loadDummyData() {
    setState(() {
      _pendingAlerts = DummyAlerts.getPendingAlerts();
      _triggeredAlerts = DummyAlerts.getTriggeredAlerts();
    });
  }

  // 필터 적용
  void _applyFilter(String? coinId) {
    setState(() {
      if (coinId == null) {
        _pendingAlerts = DummyAlerts.getPendingAlerts();
        _triggeredAlerts = DummyAlerts.getTriggeredAlerts();
      } else {
        _pendingAlerts = DummyAlerts.getPendingAlerts()
            .where((alert) => alert.coinId == coinId)
            .toList();
        _triggeredAlerts = DummyAlerts.getTriggeredAlerts()
            .where((alert) => alert.coinId == coinId)
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 테마 데이터
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        // title: const Text('알림'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '대기중'),
            Tab(text: '발생됨'),
          ],
        ),
        actions: [
          // 필터 버튼
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            tooltip: '코인별 필터링',
            onSelected: (value) {
              _applyFilter(value == '전체' ? null : value);
            },
            itemBuilder: (context) {
              // 코인 목록으로 필터 메뉴 아이템 생성
              final coinOptions = [
                {'id': null, 'name': '전체'},
                ...DummyCoins.popularCoins
                    .map((coin) => {'id': coin.id, 'name': coin.symbol})
                    .toList(),
              ];

              return coinOptions.map((option) {
                return PopupMenuItem<String?>(
                  value: option['id'],
                  child: Text(option['name'] as String),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 대기중 알림 탭
          _buildAlertsList(_pendingAlerts),

          // 발생된 알림 탭
          _buildAlertsList(_triggeredAlerts),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAlertDialog,
        tooltip: '새 알림 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  // 알림 목록 위젯
  Widget _buildAlertsList(List<PriceAlert> alerts) {
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              '알림이 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).disabledColor,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('새 알림 추가'),
              onPressed: _showAddAlertDialog,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        return _buildAlertItem(alert);
      },
    );
  }

  // 알림 아이템 위젯
  Widget _buildAlertItem(PriceAlert alert) {
    // 관련 코인 정보 가져오기
    final coin = DummyCoins.popularCoins.firstWhere(
      (coin) => coin.id == alert.coinId,
      orElse: () => DummyCoins.allCoins.firstWhere(
        (coin) => coin.id == alert.coinId,
        orElse: () => DummyCoins.popularCoins.first,
      ),
    );

    return Dismissible(
      key: Key(alert.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        // 알림 삭제 처리
        setState(() {
          if (alert.isTriggered) {
            _triggeredAlerts.removeWhere((a) => a.id == alert.id);
          } else {
            _pendingAlerts.removeWhere((a) => a.id == alert.id);
          }
          // 실제 DummyAlerts에서도 제거 (실제 앱에서는 필요 없음)
          DummyAlerts.userAlerts.removeWhere((a) => a.id == alert.id);
        });

        // 삭제 취소 스낵바
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('알림이 삭제되었습니다'),
            action: SnackBarAction(
              label: '실행 취소',
              onPressed: () {
                // 더미 데이터 다시 로드
                _loadDummyData();
              },
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showAlertDetailDialog(alert),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 코인 및 가격 목표
                Row(
                  children: [
                    // 코인 아이콘
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: coin.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                coin.imageUrl!,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.currency_bitcoin),
                              ),
                            )
                          : Icon(
                              Icons.currency_bitcoin,
                              color: AppTheme.primaryColor,
                            ),
                    ),
                    const SizedBox(width: 12),
                    // 알림 정보
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.coinSymbol,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                alert.isAbove
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                size: 14,
                                color: alert.isAbove
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '₩${_formatPrice(alert.priceTarget)}',
                                style: TextStyle(
                                  color: alert.isAbove
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 알림 상태
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: alert.isTriggered
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        alert.status,
                        style: TextStyle(
                          fontSize: 12,
                          color: alert.isTriggered
                              ? Colors.orange
                              : Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                if (alert.notes != null && alert.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // 메모
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.note, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            alert.notes!,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                // 생성 시간
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Theme.of(context).hintColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '생성: ${_formatDateTime(alert.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    if (alert.isTriggered && alert.triggeredAt != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.notifications_active,
                        size: 12,
                        color: Theme.of(context).hintColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '발생: ${_formatDateTime(alert.triggeredAt!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 새 알림 추가 다이얼로그
  void _showAddAlertDialog() {
    // 코인 목록
    final coins = DummyCoins.popularCoins;

    // 코인 선택 드롭다운 아이템
    final coinItems = coins
        .map<DropdownMenuItem<String>>(
          (coin) => DropdownMenuItem<String>(
            value: coin.id,
            child: Row(
              children: [
                if (coin.imageUrl != null) ...[
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Image.network(
                      coin.imageUrl!,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.currency_bitcoin, size: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else
                  const Icon(Icons.currency_bitcoin, size: 16),
                Text('${coin.symbol} (${coin.name})'),
              ],
            ),
          ),
        )
        .toList();

    // 필드 초기화
    _selectedCoinId = coins.isNotEmpty ? coins.first.id : null;
    _priceController.clear();
    _notesController.clear();
    _isAbove = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('새 가격 알림 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 코인 선택
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: '코인',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedCoinId,
                  items: coinItems,
                  onChanged: (value) {
                    setState(() {
                      _selectedCoinId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // 알림 방향 선택 (상승/하락)
                const Text('알림 조건'),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('이상'),
                        value: true,
                        groupValue: _isAbove,
                        onChanged: (value) {
                          setState(() {
                            _isAbove = value!;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('이하'),
                        value: false,
                        groupValue: _isAbove,
                        onChanged: (value) {
                          setState(() {
                            _isAbove = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 가격 입력
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: '가격 (KRW)',
                    border: OutlineInputBorder(),
                    hintText: '예: 50000000',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // 메모 입력 (선택사항)
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: '메모 (선택사항)',
                    border: OutlineInputBorder(),
                    hintText: '메모를 입력하세요',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_selectedCoinId == null || _priceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('코인과 가격을 모두 입력해주세요')),
                  );
                  return;
                }

                // 가격 변환
                double? price = double.tryParse(_priceController.text.trim());
                if (price == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('올바른 가격을 입력해주세요')),
                  );
                  return;
                }

                // 알림 생성
                _createAlert(
                  _selectedCoinId!,
                  price,
                  _isAbove,
                  _notesController.text.trim(),
                );

                Navigator.pop(context);
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  // 알림 생성 함수
  void _createAlert(String coinId, double price, bool isAbove, String notes) {
    // 관련 코인 찾기
    final coin = DummyCoins.popularCoins.firstWhere(
      (coin) => coin.id == coinId,
      orElse: () => DummyCoins.allCoins.firstWhere(
        (coin) => coin.id == coinId,
        orElse: () => DummyCoins.popularCoins.first,
      ),
    );

    // 새 알림 객체 생성
    final newAlert = PriceAlert(
      id: 'new-${DateTime.now().millisecondsSinceEpoch}',
      userId: 'user1',
      coinId: coinId,
      coinSymbol: coin.symbol,
      priceTarget: price,
      isAbove: isAbove,
      isTriggered: false,
      createdAt: DateTime.now(),
      notes: notes.isEmpty ? null : notes,
    );

    // 더미 데이터에 추가
    setState(() {
      DummyAlerts.userAlerts.add(newAlert);
      _pendingAlerts.add(newAlert);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('가격 알림이 생성되었습니다')));
  }

  // 알림 상세 다이얼로그
  void _showAlertDetailDialog(PriceAlert alert) {
    // 관련 코인 정보 가져오기
    final coin = DummyCoins.popularCoins.firstWhere(
      (coin) => coin.id == alert.coinId,
      orElse: () => DummyCoins.allCoins.firstWhere(
        (coin) => coin.id == alert.coinId,
        orElse: () => DummyCoins.popularCoins.first,
      ),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            // 코인 아이콘
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: coin.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        coin.imageUrl!,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.currency_bitcoin, size: 20),
                      ),
                    )
                  : Icon(
                      Icons.currency_bitcoin,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
            ),
            const SizedBox(width: 12),
            Text('${alert.coinSymbol} 알림'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 가격 목표
            Text(
              '가격 ${alert.isAbove ? '상승' : '하락'} 알림:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('₩${_formatPrice(alert.priceTarget)}'),
            const SizedBox(height: 16),

            // 현재 가격
            const Text('현재 가격:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('₩${_formatPrice(coin.currentPrice)}'),
            const SizedBox(height: 16),

            // 메모
            if (alert.notes != null && alert.notes!.isNotEmpty) ...[
              const Text('메모:', style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(alert.notes!),
              ),
              const SizedBox(height: 16),
            ],

            // 생성 시간
            const Text('생성 시간:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_formatDateTime(alert.createdAt, detailed: true)),

            // 발생 시간
            if (alert.isTriggered && alert.triggeredAt != null) ...[
              const SizedBox(height: 16),
              const Text(
                '알림 발생 시간:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(_formatDateTime(alert.triggeredAt!, detailed: true)),
            ],
          ],
        ),
        actions: [
          // 삭제 버튼
          TextButton.icon(
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text('삭제', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                if (alert.isTriggered) {
                  _triggeredAlerts.removeWhere((a) => a.id == alert.id);
                } else {
                  _pendingAlerts.removeWhere((a) => a.id == alert.id);
                }
                DummyAlerts.userAlerts.removeWhere((a) => a.id == alert.id);
              });
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('알림이 삭제되었습니다')));
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  // 가격 포맷팅 함수
  String _formatPrice(double price) {
    if (price >= 1000) {
      return '${price.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
    } else if (price >= 1) {
      return price.toStringAsFixed(2);
    } else {
      return price.toStringAsFixed(6);
    }
  }

  // 날짜/시간 포맷팅 함수
  String _formatDateTime(DateTime dateTime, {bool detailed = false}) {
    if (detailed) {
      return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.month}/${dateTime.day}';
    } else {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
