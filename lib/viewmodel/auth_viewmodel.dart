import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import '../model/user_model.dart';
import '../services/auth_service.dart';

/// 인증 관련 ViewModel
///
/// 사용자 인증 상태 및 기능을 관리합니다.
class AuthViewModel extends ChangeNotifier {
  final AuthService _authService;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  /// 현재 사용자
  UserModel? get currentUser => _currentUser;

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 오류 메시지
  String? get errorMessage => _errorMessage;

  /// 로그인 상태
  bool get isLoggedIn => _currentUser != null;

  /// 초기화 완료 여부
  bool get isInitialized => _isInitialized;

  /// ViewModel 초기화 및 현재 사용자 정보 로드
  AuthViewModel(this._authService) {
    debugPrint('AuthViewModel: 생성자 호출됨');
    _loadCurrentUser();

    // 인증 상태 변경 리스너 등록
    _authService.authStateChanges.listen((user) {
      debugPrint(
        'AuthViewModel: 인증 상태 변경 감지 - ${user != null ? "로그인됨" : "로그아웃됨"}',
      );
      _currentUser = user;
      notifyListeners();
    });
  }

  /// 현재 사용자 정보 로드
  Future<void> _loadCurrentUser() async {
    debugPrint('AuthViewModel: 현재 사용자 정보 로드 시작');
    _setLoading(true);
    try {
      // 서비스가 초기화되었는지 확인
      if (!_authService.isInitialized) {
        debugPrint('AuthViewModel: AuthService가 초기화되지 않음, 초기화 시도');
        await _authService.initialize();
        debugPrint('AuthViewModel: AuthService 초기화 완료');
      }

      _currentUser = _authService.currentUser;
      _setError(null);
      debugPrint(
        'AuthViewModel: 사용자 정보 로드 성공 - ${_currentUser != null ? '로그인됨 (${_currentUser?.email})' : '로그인되지 않음'}',
      );
    } catch (e) {
      _setError('사용자 정보를 불러오는데 실패했습니다.');
      debugPrint('AuthViewModel: 사용자 정보 로드 실패 - $e');
      debugPrint('AuthViewModel: 오류 스택 트레이스 - ${StackTrace.current}');

      // 오류 발생 시 모의 사용자로 설정 (앱 작동 유지를 위함)
      debugPrint('AuthViewModel: 모의 사용자로 설정');
      _currentUser = null;
    } finally {
      _isInitialized = true;
      debugPrint('AuthViewModel: 초기화 완료 설정');
      _setLoading(false);
    }
  }

  /// 초기화 완료까지 대기
  Future<void> waitForInitialization() async {
    debugPrint('AuthViewModel: 초기화 대기 시작');

    if (_isInitialized) {
      debugPrint('AuthViewModel: 이미 초기화됨');
      return;
    }

    // 최대 3초까지만 대기 (타임아웃 추가)
    int attempts = 0;
    const maxAttempts = 30; // 100ms 간격으로 30번 시도 (총 3초)

    // 초기화가 완료될 때까지 짧은 간격으로 확인
    while (!_isInitialized && attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;

      if (attempts % 10 == 0) {
        debugPrint('AuthViewModel: 초기화 대기 중... ($attempts/$maxAttempts)');
      }
    }

    if (!_isInitialized) {
      debugPrint('AuthViewModel: 초기화 타임아웃, 강제로 초기화 완료 처리');
      _isInitialized = true;
    } else {
      debugPrint('AuthViewModel: 초기화 완료 확인됨');
    }
  }

  /// 이메일/비밀번호로 로그인
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    _setLoading(true);
    try {
      debugPrint(
        'AuthViewModel: 로그인 시도 - 이메일: $email, 플랫폼: ${defaultTargetPlatform.toString()}',
      );
      _currentUser = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('AuthViewModel: 로그인 성공 - 사용자 ID: ${_currentUser?.id}');
      _setError(null);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AuthViewModel: 로그인 실패 - $e');
      debugPrint('AuthViewModel: 오류 스택 트레이스 - ${StackTrace.current}');
      _setError('로그인에 실패했습니다. 이메일과 비밀번호를 확인해주세요.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 회원가입
  Future<bool> signUp(String email, String password, {String? name}) async {
    _setLoading(true);
    try {
      _currentUser = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        displayName: name ?? email.split('@').first,
      );
      _setError(null);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('회원가입에 실패했습니다. 다시 시도해주세요.');
      debugPrint('AuthViewModel: 회원가입 실패 - $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 로그아웃
  Future<bool> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _currentUser = null;
      _setError(null);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('로그아웃에 실패했습니다.');
      debugPrint('AuthViewModel: 로그아웃 실패 - $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 비밀번호 재설정 이메일 전송
  Future<bool> sendPasswordResetEmail(String email) async {
    _setLoading(true);
    try {
      await _authService.sendPasswordResetEmail(email: email);
      _setError(null);
      return true;
    } catch (e) {
      _setError('비밀번호 재설정 이메일 전송에 실패했습니다.');
      debugPrint('AuthViewModel: 비밀번호 재설정 이메일 전송 실패 - $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 사용자 프로필 업데이트
  Future<bool> updateUserInfo({String? name, String? profileUrl}) async {
    _setLoading(true);
    try {
      _currentUser = await _authService.updateUserProfile(
        name: name,
        profileUrl: profileUrl,
      );
      _setError(null);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('프로필 업데이트에 실패했습니다.');
      debugPrint('AuthViewModel: 프로필 업데이트 실패 - $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 이메일 인증 상태 확인
  bool isEmailVerified() {
    return _currentUser?.isEmailVerified ?? false;
  }

  /// 이메일 인증 메일 전송
  Future<bool> sendEmailVerification() async {
    _setLoading(true);
    try {
      await _authService.sendEmailVerification();
      _setError(null);
      return true;
    } catch (e) {
      _setError('이메일 인증 메일 전송에 실패했습니다.');
      debugPrint('AuthViewModel: 이메일 인증 메일 전송 실패 - $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 로딩 상태 설정
  void _setLoading(bool isLoading) {
    _isLoading = isLoading;
    notifyListeners();
  }

  /// 오류 메시지 설정
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// 오류 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
