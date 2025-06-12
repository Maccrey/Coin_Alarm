import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../model/price_alert_model.dart';
import '../../model/strategy_alert_model.dart';
import '../../model/coin_model.dart';
import '../../viewmodel/price_alert_viewmodel.dart';
import '../../viewmodel/strategy_alert_viewmodel.dart';
import '../../viewmodel/crypto_viewmodel.dart';
import '../../utils/strategy_templates.dart';

// 알림 화면
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedCoinId;
  bool _isAbove = true;
  String? _selectedFilter;
  String _selectedFilterName = '전체';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final priceAlertVM = Provider.of<PriceAlertViewModel>(
        context,
        listen: false,
      );
      final strategyAlertVM = Provider.of<StrategyAlertViewModel>(
        context,
        listen: false,
      );
      final cryptoVM = Provider.of<CryptoViewModel>(context, listen: false);

      // 임시 사용자 ID 사용 (실제로는 인증된 사용자 ID 사용)
      const userId = 'local-user';
      priceAlertVM.loadUserAlerts(userId);
      strategyAlertVM.setUserId(userId);
      cryptoVM.refreshCoins();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // 필터 적용
  void _applyFilter(String? coinId, String coinName) {
    setState(() {
      _selectedFilter = coinId;
      _selectedFilterName = coinName;
      final priceAlertVM = Provider.of<PriceAlertViewModel>(
        context,
        listen: false,
      );
      priceAlertVM.setFilter(coinId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceAlertVM = Provider.of<PriceAlertViewModel>(context);
    final cryptoVM = Provider.of<CryptoViewModel>(context);
    final alerts = priceAlertVM.alerts;
    final pendingAlerts = alerts.where((a) => !a.isTriggered).toList();
    final triggeredAlerts = alerts.where((a) => a.isTriggered).toList();
    final coins = cryptoVM.coins;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Align(alignment: Alignment.centerLeft, child: Text('알림')),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '대기중'),
            Tab(text: '발생됨'),
            Tab(text: '전략 기반'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: PopupMenuButton<Map<String, dynamic>>(
              tooltip: '코인별 필터링',
              offset: const Offset(0, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedFilterName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.filter_list,
                      size: 18,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ],
                ),
              ),
              onSelected: (option) {
                _applyFilter(option['id'] as String?, option['name'] as String);
              },
              itemBuilder: (context) {
                final allCoins = [
                  {'id': null, 'name': '전체', 'imageUrl': null},
                  ...coins
                      .map(
                        (coin) => {
                          'id': coin.id,
                          'name': coin.symbol,
                          'imageUrl': coin.imageUrl,
                        },
                      )
                      .toList(),
                ];
                return allCoins.map((coin) {
                  final bool isSelected =
                      (coin['id'] == _selectedFilter) ||
                      (coin['id'] == null && _selectedFilter == null);
                  return PopupMenuItem<Map<String, dynamic>>(
                    value: coin,
                    child: Row(
                      children: [
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                            size: 18,
                          )
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        if (coin['imageUrl'] != null) ...[
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                coin['imageUrl'] as String,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.currency_bitcoin,
                                      size: 16,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ] else if (coin['id'] != null) ...[
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.currency_bitcoin,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ] else ...[
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.filter_alt,
                              size: 16,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          coin['name'] as String,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAlertsList(pendingAlerts, cryptoVM, priceAlertVM),
          _buildAlertsList(triggeredAlerts, cryptoVM, priceAlertVM),
          _buildStrategyAlertsList(cryptoVM, priceAlertVM),
        ],
      ),
      floatingActionButton: (_tabController.index == 1)
          ? null
          : FloatingActionButton(
              onPressed: () {
                if (_tabController.index == 0) {
                  _showAddAlertDialog(coins, priceAlertVM);
                } else if (_tabController.index == 2) {
                  _showAddStrategyAlertDialog(cryptoVM);
                }
              },
              tooltip: _tabController.index == 2 ? '전략 알림 추가' : '새 알림 추가',
              child: const Icon(Icons.add),
            ),
    );
  }

  // 알림 목록 위젯
  Widget _buildAlertsList(
    List<PriceAlert> alerts,
    CryptoViewModel cryptoVM,
    PriceAlertViewModel priceAlertVM,
  ) {
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
              _selectedFilter == null
                  ? '알림이 없습니다'
                  : '$_selectedFilterName 코인에 대한 알림이 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).disabledColor,
              ),
            ),
            if (_tabController.index != 1) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('새 알림 추가'),
                onPressed: () =>
                    _showAddAlertDialog(cryptoVM.coins, priceAlertVM),
              ),
            ],
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        return _buildAlertItem(alert, cryptoVM, priceAlertVM);
      },
    );
  }

  // 알림 아이템 위젯
  Widget _buildAlertItem(
    PriceAlert alert,
    CryptoViewModel cryptoVM,
    PriceAlertViewModel priceAlertVM,
  ) {
    Coin? coin;
    try {
      coin = cryptoVM.coins.firstWhere((c) => c.id == alert.coinId);
    } catch (e) {
      coin = null;
    }

    // 현재 가격과 목표 가격 비교
    final currentPrice = coin?.currentPrice ?? 0.0;
    final targetPrice = alert.priceTarget;
    final conditionMet = alert.isAbove
        ? currentPrice >= targetPrice
        : currentPrice <= targetPrice;

    return Dismissible(
      key: Key(alert.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) async {
        await priceAlertVM.deleteAlert(alert.id);
        // 삭제 후 새로고침 필요시 추가
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () => _showAlertDetailDialog(alert, coin),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 코인 이미지
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: coin?.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.network(
                            coin!.imageUrl!,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.currency_bitcoin, size: 24),
                          ),
                        )
                      : Icon(
                          Icons.currency_bitcoin,
                          size: 24,
                          color: AppTheme.primaryColor,
                        ),
                ),
                const SizedBox(width: 16),
                // 알림 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            alert.coinSymbol,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 조건 달성 상태 표시
                          if (!alert.isTriggered)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: conditionMet
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: conditionMet
                                      ? Colors.green
                                      : Colors.grey,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                conditionMet ? '조건 달성' : '대기중',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: conditionMet
                                      ? Colors.green
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 목표 가격과 조건
                      Row(
                        children: [
                          Icon(
                            alert.isAbove
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 14,
                            color: alert.isAbove
                                ? Colors.blue.shade700
                                : Colors.red.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '목표: ₩${_formatPrice(alert.priceTarget)}',
                            style: TextStyle(
                              color: alert.isAbove
                                  ? Colors.blue.shade700
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),

                      // 현재 가격 표시
                      if (coin?.currentPrice != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.trending_flat,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '현재: ₩${_formatPrice(currentPrice)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 가격 차이 표시
                            if (currentPrice != 0.0) ...[
                              Icon(
                                conditionMet
                                    ? Icons.check_circle
                                    : Icons.schedule,
                                size: 12,
                                color: conditionMet
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                conditionMet
                                    ? '달성!'
                                    : '차이: ₩${_formatPrice((targetPrice - currentPrice).abs())}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: conditionMet
                                      ? Colors.green
                                      : Colors.orange[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // 알림 상태 및 시간 정보
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (alert.isTriggered) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '발생됨',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      if (alert.triggeredAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(alert.triggeredAt!, detailed: true),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ] else ...[
                      Text(
                        _formatDateTime(alert.createdAt),
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
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
  void _showAddAlertDialog(List<Coin> coins, PriceAlertViewModel priceAlertVM) {
    setState(() {
      _selectedCoinId = null;
      _priceController.text = '';
      _notesController.text = '';
    });
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, parentSetState) => AlertDialog(
          title: const Text('새 가격 알림 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('코인 선택'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      _showCoinSelectionDialog(coins, parentSetState),
                  child: _selectedCoinId == null
                      ? const Text('코인 선택')
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (coins.any((c) => c.id == _selectedCoinId) &&
                                coins
                                        .firstWhere(
                                          (c) => c.id == _selectedCoinId,
                                        )
                                        .imageUrl !=
                                    null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      coins
                                          .firstWhere(
                                            (c) => c.id == _selectedCoinId,
                                          )
                                          .imageUrl!,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.currency_bitcoin,
                                                size: 18,
                                              ),
                                    ),
                                  ),
                                ),
                              ),
                            Text(
                              coins
                                  .firstWhere((c) => c.id == _selectedCoinId)
                                  .symbol,
                            ),
                          ],
                        ),
                ),
                // 현재가 표시
                if (_selectedCoinId != null &&
                    coins.any((c) => c.id == _selectedCoinId)) ...[
                  const SizedBox(height: 12),
                  Text(
                    '현재가: ₩${_formatPrice(coins.firstWhere((c) => c.id == _selectedCoinId).currentPrice)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('알림 조건'),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('이상'),
                        value: true,
                        groupValue: _isAbove,
                        onChanged: (value) {
                          parentSetState(() {
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
                          parentSetState(() {
                            _isAbove = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
              onPressed: () async {
                if (_selectedCoinId == null || _priceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('코인과 가격을 모두 입력해주세요')),
                  );
                  return;
                }
                double? price = double.tryParse(_priceController.text.trim());
                if (price == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('올바른 가격을 입력해주세요')),
                  );
                  return;
                }
                final coin = coins.firstWhere((c) => c.id == _selectedCoinId);

                // 로컬 사용자 ID 사용
                const userId = 'local-user';
                await priceAlertVM.createAlert(
                  userId,
                  coin.id,
                  coin.symbol,
                  price,
                  _isAbove,
                  notes: _notesController.text.trim(),
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

  // 코인 선택 다이얼로그
  void _showCoinSelectionDialog(List<Coin> coins, StateSetter parentSetState) {
    String searchQuery = '';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('코인 선택'),
          content: Container(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: '코인 검색'),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: coins
                        .where(
                          (coin) =>
                              coin.symbol.toLowerCase().contains(
                                searchQuery.toLowerCase(),
                              ) ||
                              coin.name.toLowerCase().contains(
                                searchQuery.toLowerCase(),
                              ),
                        )
                        .length,
                    itemBuilder: (context, index) {
                      final filteredCoins = coins
                          .where(
                            (coin) =>
                                coin.symbol.toLowerCase().contains(
                                  searchQuery.toLowerCase(),
                                ) ||
                                coin.name.toLowerCase().contains(
                                  searchQuery.toLowerCase(),
                                ),
                          )
                          .toList();
                      final coin = filteredCoins[index];
                      return ListTile(
                        title: Text(coin.symbol),
                        leading: coin.imageUrl != null
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    coin.imageUrl!,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(Icons.currency_bitcoin),
                                  ),
                                ),
                              )
                            : const Icon(Icons.currency_bitcoin),
                        onTap: () {
                          parentSetState(() {
                            _selectedCoinId = coin.id;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }

  // 알림 상세 다이얼로그
  void _showAlertDetailDialog(PriceAlert alert, Coin? coin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: coin?.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        coin!.imageUrl!,
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
            Text(
              '가격 ${alert.isAbove ? '상승' : '하락'} 알림:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('₩${_formatPrice(alert.priceTarget)}'),
            const SizedBox(height: 16),
            if (coin != null) ...[
              const Text(
                '현재 가격:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('₩${_formatPrice(coin.currentPrice)}'),
              const SizedBox(height: 16),
            ],
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
            const Text('생성 시간:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_formatDateTime(alert.createdAt, detailed: true)),
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
          TextButton.icon(
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text('삭제', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              final priceAlertVM = Provider.of<PriceAlertViewModel>(
                context,
                listen: false,
              );
              await priceAlertVM.deleteAlert(alert.id);
              Navigator.pop(context);
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
      String formatted = price.toStringAsFixed(2);
      if (formatted.endsWith('.00')) {
        formatted = formatted.substring(0, formatted.length - 3);
      }
      return formatted.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    } else if (price >= 1) {
      String formatted = price.toStringAsFixed(2);
      if (formatted.endsWith('.00')) {
        formatted = formatted.substring(0, formatted.length - 3);
      }
      return formatted;
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

  // 전략 기반 알림 목록 위젯
  Widget _buildStrategyAlertsList(
    CryptoViewModel cryptoVM,
    PriceAlertViewModel priceAlertVM,
  ) {
    return Consumer<StrategyAlertViewModel>(
      builder: (context, strategyAlertVM, child) {
        final alerts = strategyAlertVM.alerts;
        final theme = Theme.of(context);

        if (strategyAlertVM.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (strategyAlertVM.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  '오류가 발생했습니다',
                  style: TextStyle(
                    fontSize: 18,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strategyAlertVM.errorMessage!,
                  style: TextStyle(color: theme.disabledColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => strategyAlertVM.refreshAlerts(),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          );
        }

        print('[AlertsScreen] 필터링 후 알림 수: ${alerts.length}');
        print(
          '[AlertsScreen] 현재 선택된 필터: ${strategyAlertVM.selectedStatusFilter}',
        );

        if (alerts.isEmpty) {
          // 선택된 필터에 따라 메시지 변경
          String mainMessage = '전략 기반 알림이 없습니다';
          String subMessage = '단타매매 전략을 설정하여\n스마트한 알림을 받아보세요';

          if (strategyAlertVM.selectedStatusFilter != null) {
            switch (strategyAlertVM.selectedStatusFilter) {
              case 'pending':
                mainMessage = '대기중인 전략 알림이 없습니다';
                subMessage = '새로운 전략 알림을 추가하거나\n다른 필터를 선택해보세요';
                break;
              case 'triggered':
                mainMessage = '발생된 전략 알림이 없습니다';
                subMessage = '아직 조건이 충족된 알림이 없습니다';
                break;
              case 'disabled':
                mainMessage = '비활성화된 전략 알림이 없습니다';
                subMessage = '알림 설정을 비활성화하면 이곳에 표시됩니다';
                break;
            }
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.smart_toy_outlined,
                  size: 64,
                  color: theme.disabledColor,
                ),
                const SizedBox(height: 16),
                Text(
                  mainMessage,
                  style: TextStyle(fontSize: 18, color: theme.disabledColor),
                ),
                const SizedBox(height: 8),
                Text(
                  subMessage,
                  style: TextStyle(color: theme.disabledColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (strategyAlertVM.selectedStatusFilter != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.filter_alt_off),
                    label: const Text('필터 초기화'),
                    onPressed: () => strategyAlertVM.setStatusFilter(null),
                  ),
                if (_tabController.index == 2 &&
                    (strategyAlertVM.selectedStatusFilter == null ||
                        strategyAlertVM.selectedStatusFilter == 'pending')) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('전략 알림 추가'),
                    onPressed: () => _showAddStrategyAlertDialog(cryptoVM),
                  ),
                ],
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => strategyAlertVM.refreshAlerts(),
          child: CustomScrollView(
            slivers: [
              // 필터 영역
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStrategyFilterChip('전체', null, strategyAlertVM),
                        const SizedBox(width: 8),
                        _buildStrategyFilterChip(
                          '대기중',
                          'pending',
                          strategyAlertVM,
                        ),
                        const SizedBox(width: 8),
                        _buildStrategyFilterChip(
                          '발생됨',
                          'triggered',
                          strategyAlertVM,
                        ),
                        const SizedBox(width: 8),
                        _buildStrategyFilterChip(
                          '비활성',
                          'disabled',
                          strategyAlertVM,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 알림 목록
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final alert = alerts[index];
                  return _buildStrategyAlertCard(
                    alert,
                    cryptoVM,
                    strategyAlertVM,
                  );
                }, childCount: alerts.length),
              ),
            ],
          ),
        );
      },
    );
  }

  // 전략 필터 칩
  Widget _buildStrategyFilterChip(
    String label,
    String? filterValue,
    StrategyAlertViewModel strategyAlertVM,
  ) {
    final theme = Theme.of(context);
    final isSelected = strategyAlertVM.selectedStatusFilter == filterValue;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        print('[FilterChip] 필터 선택: $filterValue, selected: $selected');
        if (selected) {
          strategyAlertVM.setStatusFilter(filterValue);
        } else {
          strategyAlertVM.setStatusFilter(null);
        }

        // 강제로 상태 업데이트
        setState(() {});
      },
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.primary,
    );
  }

  // 전략 알림 카드
  Widget _buildStrategyAlertCard(
    StrategyAlert alert,
    CryptoViewModel cryptoVM,
    StrategyAlertViewModel strategyAlertVM,
  ) {
    final theme = Theme.of(context);
    final triggerCondition = alert.triggerCondition;
    final strategyDisplayName = StrategyTemplates.getStrategyDisplayName(
      alert.strategyName,
    );
    final description =
        triggerCondition['description'] ??
        StrategyTemplates.getStrategyDescription(alert.strategyName);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStrategyColor(alert.strategyName),
          child: Text(
            alert.coinSymbol,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '$strategyDisplayName - ${alert.coinSymbol}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            _buildStrategyStatusBadge(alert, theme),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  _getRiskIcon(alert.riskLevel),
                  size: 14,
                  color: _getRiskColor(alert.riskLevel),
                ),
                const SizedBox(width: 4),
                Text(
                  _getRiskText(alert.riskLevel),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getRiskColor(alert.riskLevel),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDateTime(alert.createdAt),
                  style: TextStyle(fontSize: 11, color: theme.disabledColor),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) =>
              _handleStrategyAlertAction(value, alert, strategyAlertVM),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(alert.isEnabled ? Icons.pause : Icons.play_arrow),
                  const SizedBox(width: 8),
                  Text(alert.isEnabled ? '비활성화' : '활성화'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [Icon(Icons.edit), SizedBox(width: 8), Text('수정')],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('삭제', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showStrategyAlertDetails(alert),
      ),
    );
  }

  // 새 전략 기반 알림 추가 다이얼로그
  void _showAddStrategyAlertDialog(CryptoViewModel cryptoVM) {
    final coins = cryptoVM.coins;
    final strategies = StrategyTemplates.getAllStrategies();

    String? selectedCoinId;
    String? selectedStrategy;
    String selectedRiskLevel = 'medium';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('전략 기반 알림 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 코인 선택
                const Text(
                  '코인 선택',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCoinId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '코인을 선택하세요',
                  ),
                  items: coins
                      .map(
                        (coin) => DropdownMenuItem(
                          value: coin.id,
                          child: Row(
                            children: [
                              if (coin.imageUrl != null)
                                Image.network(
                                  coin.imageUrl!,
                                  width: 24,
                                  height: 24,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.currency_bitcoin,
                                        size: 24,
                                      ),
                                ),
                              const SizedBox(width: 8),
                              Text('${coin.name} (${coin.symbol})'),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => selectedCoinId = value),
                ),
                const SizedBox(height: 16),

                // 전략 선택
                const Text(
                  '전략 선택',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedStrategy,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '전략을 선택하세요',
                  ),
                  items: strategies
                      .map(
                        (strategy) => DropdownMenuItem(
                          value: strategy['name'] as String,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(strategy['displayName'] as String),
                              Text(
                                strategy['description'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => selectedStrategy = value),
                ),
                const SizedBox(height: 16),

                // 위험도 선택
                const Text(
                  '위험도',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'low', label: Text('낮음')),
                    ButtonSegment(value: 'medium', label: Text('중간')),
                    ButtonSegment(value: 'high', label: Text('높음')),
                  ],
                  selected: {selectedRiskLevel},
                  onSelectionChanged: (value) =>
                      setState(() => selectedRiskLevel = value.first),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: (selectedCoinId != null && selectedStrategy != null)
                  ? () => _createStrategyAlert(
                      selectedCoinId!,
                      selectedStrategy!,
                      selectedRiskLevel,
                      coins,
                    )
                  : null,
              child: const Text('생성'),
            ),
          ],
        ),
      ),
    );
  }

  // 전략 기반 알림 생성
  void _createStrategyAlert(
    String coinId,
    String strategyName,
    String riskLevel,
    List<Coin> coins,
  ) async {
    final strategyAlertVM = Provider.of<StrategyAlertViewModel>(
      context,
      listen: false,
    );
    // 사용자 ID를 반드시 먼저 설정
    await strategyAlertVM.setUserId('local-user');
    final coin = coins.firstWhere((c) => c.id == coinId);

    final success = await strategyAlertVM.createStrategyAlertFromTemplate(
      coinId: coinId,
      coinSymbol: coin.symbol,
      strategyName: strategyName,
      riskLevel: riskLevel,
    );

    if (mounted) {
      Navigator.of(context).pop();

      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('전략 기반 알림이 생성되었습니다')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strategyAlertVM.errorMessage ?? '알림 생성에 실패했습니다'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // 헬퍼 메서드들
  Color _getStrategyColor(String strategyName) {
    switch (strategyName) {
      case 'breakout':
        return Colors.orange;
      case 'pullback':
        return Colors.blue;
      case 'rsi_reversal':
        return Colors.green;
      case 'golden_cross':
        return Colors.amber;
      case 'dead_cross':
        return Colors.red;
      case 'candle_pattern':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStrategyStatusBadge(StrategyAlert alert, ThemeData theme) {
    String text;
    Color color;

    if (!alert.isEnabled) {
      text = '비활성';
      color = theme.disabledColor;
    } else if (alert.isTriggered) {
      text = '발생됨';
      color = theme.colorScheme.error;
    } else {
      text = '대기중';
      color = theme.colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  IconData _getRiskIcon(String riskLevel) {
    switch (riskLevel) {
      case 'low':
        return Icons.security;
      case 'high':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'low':
        return Colors.green;
      case 'high':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _getRiskText(String riskLevel) {
    switch (riskLevel) {
      case 'low':
        return '저위험';
      case 'high':
        return '고위험';
      default:
        return '중위험';
    }
  }

  void _handleStrategyAlertAction(
    String action,
    StrategyAlert alert,
    StrategyAlertViewModel strategyAlertVM,
  ) async {
    switch (action) {
      case 'toggle':
        await strategyAlertVM.toggleAlert(alert.id);
        break;
      case 'edit':
        // 편집 다이얼로그 표시
        break;
      case 'delete':
        await strategyAlertVM.deleteAlert(alert.id);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('알림이 삭제되었습니다')));
        }
        break;
    }
  }

  void _showStrategyAlertDetails(StrategyAlert alert) {
    // 상세 정보 다이얼로그 표시
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${alert.coinSymbol} - ${StrategyTemplates.getStrategyDisplayName(alert.strategyName)}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('위험도: ${_getRiskText(alert.riskLevel)}'),
            const SizedBox(height: 8),
            Text('상태: ${alert.statusText}'),
            const SizedBox(height: 8),
            Text('생성일: ${_formatDateTime(alert.createdAt, detailed: true)}'),
            if (alert.triggeredAt != null) ...[
              const SizedBox(height: 8),
              Text(
                '발생일: ${_formatDateTime(alert.triggeredAt!, detailed: true)}',
              ),
            ],
            if (alert.notes != null && alert.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('메모: ${alert.notes}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}
