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

  /// 비밀번호 재설정 이메일 전송
  ///
  /// 사용자가 입력한 이메일로 비밀번호 재설정 링크를 전송합니다.
  /// Supabase 서비스를 통해 비밀번호 재설정 이메일을 발송하고 결과를 반환합니다.
  ///
  /// [email] 비밀번호를 재설정할 사용자의 이메일 주소
  /// [return] 이메일 전송 성공 여부 (true: 성공, false: 실패)
  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Supabase 서비스를 통해 비밀번호 재설정 이메일 전송
      await _supabaseService.resetPassword(email);
      return true;
    } catch (e) {
      _errorMessage = '비밀번호 재설정 이메일 전송 실패: $e';
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
