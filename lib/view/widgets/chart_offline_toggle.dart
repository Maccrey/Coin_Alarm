import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodel/chart_viewmodel.dart';

/// 차트 오프라인 모드 전환 버튼 위젯
class ChartOfflineToggle extends StatelessWidget {
  const ChartOfflineToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final chartViewModel = Provider.of<ChartViewModel>(context);
    final isOfflineMode = chartViewModel.isOfflineMode;

    return IconButton(
      onPressed: () => chartViewModel.setOfflineMode(!isOfflineMode),
      icon: Icon(
        isOfflineMode ? Icons.offline_bolt : Icons.offline_bolt_outlined,
        color: isOfflineMode ? Colors.blue : Theme.of(context).iconTheme.color,
      ),
      tooltip: isOfflineMode ? '오프라인 모드 해제' : '오프라인 모드 활성화',
    );
  }
}
