import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../model/price_alert_model.dart';
import '../../model/coin_model.dart';
import '../../viewmodel/price_alert_viewmodel.dart';
import '../../viewmodel/coin_viewmodel.dart';

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
    _tabController = TabController(length: 2, vsync: this);
    // 실제 사용자 ID로 교체 필요
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final priceAlertVM = Provider.of<PriceAlertViewModel>(
        context,
        listen: false,
      );
      final coinVM = Provider.of<CoinViewModel>(context, listen: false);
      // TODO: 실제 로그인된 사용자 ID로 교체
      final userId = 'user-id';
      priceAlertVM.loadUserAlerts(userId);
      coinVM.refreshCoins();
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
    final coinVM = Provider.of<CoinViewModel>(context);
    final alerts = priceAlertVM.alerts;
    final pendingAlerts = alerts.where((a) => !a.isTriggered).toList();
    final triggeredAlerts = alerts.where((a) => a.isTriggered).toList();
    final coins = coinVM.coins;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Align(alignment: Alignment.centerLeft, child: Text('알림')),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '대기중'),
            Tab(text: '발생됨'),
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
          _buildAlertsList(pendingAlerts, coinVM, priceAlertVM),
          _buildAlertsList(triggeredAlerts, coinVM, priceAlertVM),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAlertDialog(coins, priceAlertVM),
        tooltip: '새 알림 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  // 알림 목록 위젯
  Widget _buildAlertsList(
    List<PriceAlert> alerts,
    CoinViewModel coinVM,
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
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('새 알림 추가'),
              onPressed: () => _showAddAlertDialog(coinVM.coins, priceAlertVM),
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
        return _buildAlertItem(alert, coinVM, priceAlertVM);
      },
    );
  }

  // 알림 아이템 위젯
  Widget _buildAlertItem(
    PriceAlert alert,
    CoinViewModel coinVM,
    PriceAlertViewModel priceAlertVM,
  ) {
    final coin = coinVM.getCoinById(alert.coinId);
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
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showAlertDetailDialog(alert, coin),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: coin?.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                coin!.imageUrl!,
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
                                    ? Colors.blue.shade700
                                    : Colors.red.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '₩${_formatPrice(alert.priceTarget)}',
                                style: TextStyle(
                                  color: alert.isAbove
                                      ? Colors.blue.shade700
                                      : Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: alert.isTriggered
                            ? Colors.orange.withOpacity(0.2)
                            : (alert.isAbove
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.blue.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        alert.status,
                        style: TextStyle(
                          fontSize: 12,
                          color: alert.isTriggered
                              ? Colors.orange
                              : (alert.isAbove ? Colors.red : Colors.blue),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (alert.notes != null && alert.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
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
  void _showAddAlertDialog(List<Coin> coins, PriceAlertViewModel priceAlertVM) {
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
                // 실제 로그인된 사용자 ID로 교체 필요
                final userId = 'user-id';
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
