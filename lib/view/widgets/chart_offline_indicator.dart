import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/chart_viewmodel.dart';

/// 차트 오프라인 모드 표시 위젯
class ChartOfflineIndicator extends StatelessWidget {
  const ChartOfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final chartViewModel = Provider.of<ChartViewModel>(context);
    final isOfflineMode = chartViewModel.isOfflineMode;
    final isConnected = chartViewModel.isConnected;

    // 오프라인 모드가 아니고 네트워크도 연결된 경우 표시하지 않음
    if (!isOfflineMode && isConnected) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOfflineMode
            ? Colors.blue.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOfflineMode ? Colors.blue : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOfflineMode ? Icons.offline_bolt : Icons.signal_wifi_off,
            size: 16,
            color: isOfflineMode ? Colors.blue : Colors.red,
          ),
          const SizedBox(width: 6),
          Text(
            isOfflineMode ? '오프라인 모드' : '네트워크 연결 없음',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isOfflineMode ? Colors.blue : Colors.red,
            ),
          ),
          if (isOfflineMode) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => chartViewModel.setOfflineMode(false),
              child: const Icon(Icons.close, size: 14, color: Colors.blue),
            ),
          ],
        ],
      ),
    );
  }
}
