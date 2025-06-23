import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_database_service.dart';
import '../firebase_options.dart';

/// Firebase Realtime Database 사용 예제
class FirebaseDatabaseExample extends StatefulWidget {
  const FirebaseDatabaseExample({super.key});

  @override
  State<FirebaseDatabaseExample> createState() =>
      _FirebaseDatabaseExampleState();
}

class _FirebaseDatabaseExampleState extends State<FirebaseDatabaseExample> {
  final FirebaseDatabaseService _databaseService = FirebaseDatabaseService();
  String _result = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  /// Firebase 초기화
  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      setState(() {
        _result = 'Firebase 초기화 성공';
      });
    } catch (e) {
      setState(() {
        _result = '초기화 실패: $e';
      });
    }
  }

  /// 데이터 저장 예제
  Future<void> _saveData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = {
        'name': 'Bitcoin',
        'price': 50000,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final result = await _databaseService.saveData('coins/bitcoin', data);

      setState(() {
        _result = result ? '데이터 저장 성공' : '데이터 저장 실패';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = '데이터 저장 중 오류: $e';
        _isLoading = false;
      });
    }
  }

  /// 데이터 조회 예제
  Future<void> _getData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _databaseService.getData('coins/bitcoin');

      setState(() {
        _result = data != null ? '조회된 데이터: $data' : '데이터가 없습니다';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = '데이터 조회 중 오류: $e';
        _isLoading = false;
      });
    }
  }

  /// 데이터 업데이트 예제
  Future<void> _updateData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = {
        'price': 55000,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

      final result = await _databaseService.updateData('coins/bitcoin', data);

      setState(() {
        _result = result ? '데이터 업데이트 성공' : '데이터 업데이트 실패';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = '데이터 업데이트 중 오류: $e';
        _isLoading = false;
      });
    }
  }

  /// 데이터 삭제 예제
  Future<void> _deleteData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _databaseService.deleteData('coins/bitcoin');

      setState(() {
        _result = result ? '데이터 삭제 성공' : '데이터 삭제 실패';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = '데이터 삭제 중 오류: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Realtime Database 예제')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: _saveData,
                    child: const Text('데이터 저장'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _getData,
                    child: const Text('데이터 조회'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _updateData,
                    child: const Text('데이터 업데이트'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _deleteData,
                    child: const Text('데이터 삭제'),
                  ),
                  const SizedBox(height: 16),
                  const Text('결과:'),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(child: Text(_result)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
