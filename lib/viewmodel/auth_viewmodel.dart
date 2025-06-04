import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';
import '../model/user_model.dart';

// 인증 관련 ViewModel 클래스
class AuthViewModel extends ChangeNotifier {
  final SupabaseService _supabaseService;

  // 상태 관리
  bool _isLoading = false;
  User? _currentUser;
  String? _errorMessage;

  // 생성자
  AuthViewModel(this._supabaseService) {
    // 현재 로그인된 사용자 확인
    _loadCurrentUser();
  }

  // Getters
  bool get isLoading => _isLoading;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;

  // 초기 사용자 로드
  Future<void> _loadCurrentUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _supabaseService.getCurrentUser();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = '사용자 정보 로드 실패: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 이메일/비밀번호로 로그인
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _supabaseService.login(email, password);
      return true;
    } catch (e) {
      _errorMessage = '로그인 실패: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 회원가입
  Future<bool> signUp(String email, String password, {String? name}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _supabaseService.register(
        email,
        password,
        name ?? '사용자',
      );
      return true;
    } catch (e) {
      _errorMessage = '회원가입 실패: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 로그아웃
  Future<bool> signOut() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabaseService.logout();
      _currentUser = null;
      return true;
    } catch (e) {
      _errorMessage = '로그아웃 실패: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 비밀번호 재설정
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 현재 SupabaseService에 비밀번호 재설정 기능이 없으므로 임시로 성공 반환
      debugPrint('비밀번호 재설정 기능은 아직 구현되지 않았습니다.');
      return true;
    } catch (e) {
      _errorMessage = '비밀번호 재설정 요청 실패: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 사용자 정보 업데이트
  Future<bool> updateUserInfo(Map<String, dynamic> data) async {
    if (_currentUser == null) {
      _errorMessage = '로그인이 필요합니다.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // 현재 SupabaseService에 사용자 정보 업데이트 기능이 없으므로 임시로 성공 반환
      debugPrint('사용자 정보 업데이트 기능은 아직 구현되지 않았습니다.');
      // 로컬 사용자 정보 업데이트
      final updatedUser = _currentUser!.copyWith(
        name: data['name'] ?? _currentUser!.name,
        profileImageUrl:
            data['profile_image_url'] ?? _currentUser!.profileImageUrl,
      );
      _currentUser = updatedUser;
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = '사용자 정보 업데이트 실패: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
