import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:coin_alarm/firebase_options.dart';

import '../model/user_model.dart';

/// 인증 서비스
///
/// Firebase 인증을 사용하며, 로그인 정보는 Firebase Authentication에 저장됩니다.
class AuthService {
  // 싱글톤 패턴 구현
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Firebase 인증 인스턴스
  late firebase_auth.FirebaseAuth _auth;
  bool _isFirebaseAvailable = false;

  // 현재 로그인한 사용자
  UserModel? _currentUser;

  // 인증 상태 스트림 컨트롤러
  final _authStateController = StreamController<UserModel?>.broadcast();

  // 초기화 여부
  bool _isInitialized = false;

  /// 초기화 여부 확인용 getter
  bool get isInitialized => _isInitialized;

  /// 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('AuthService: 초기화 시작');
    debugPrint('AuthService: 플랫폼 - ${defaultTargetPlatform.toString()}');

    try {
      // 웹 플랫폼에서는 Firebase 사용을 건너뜁니다
      if (kIsWeb) {
        debugPrint(
          'AuthService: 웹 플랫폼에서는 Firebase 인증을 사용하지 않습니다. 모의 인증 서비스로 전환합니다.',
        );
        _isFirebaseAvailable = false;
        _setupMockAuth();
        _isInitialized = true;
        return;
      }

      try {
        debugPrint('AuthService: Firebase 인증 인스턴스 생성 시도');
        _auth = firebase_auth.FirebaseAuth.instance;
        _isFirebaseAvailable = true;
        debugPrint('AuthService: Firebase 인증 인스턴스 생성 성공');

        // Firebase 인증 상태 리스너 등록
        debugPrint('AuthService: Firebase 인증 상태 리스너 등록 시도');
        _auth.authStateChanges().listen((firebase_auth.User? firebaseUser) {
          _handleAuthStateChange(firebaseUser);
        });
        debugPrint('AuthService: Firebase 인증 상태 리스너 등록 성공');

        // 현재 로그인된 사용자 확인
        debugPrint('AuthService: 현재 로그인된 사용자 확인');
        final firebaseUser = _auth.currentUser;
        if (firebaseUser != null) {
          debugPrint('AuthService: 기존 로그인된 사용자 발견 - ${firebaseUser.email}');
          await _handleAuthStateChange(firebaseUser);
        } else {
          debugPrint('AuthService: 로그인된 사용자 없음');
          _currentUser = null;
          _authStateController.add(null);
        }
      } catch (e) {
        debugPrint('AuthService: Firebase 인증 초기화 실패 - $e');
        debugPrint('AuthService: 오류 스택 트레이스 - ${StackTrace.current}');
        _isFirebaseAvailable = false;
        // Firebase 초기화 실패 시 모의 인증 서비스로 폴백
        _setupMockAuth();
      }

      _isInitialized = true;
      debugPrint('AuthService: 초기화 완료 - Firebase 사용 가능: $_isFirebaseAvailable');
    } catch (e) {
      debugPrint('AuthService: 초기화 실패 - $e');
      debugPrint('AuthService: 오류 스택 트레이스 - ${StackTrace.current}');
      // 모든 예외 상황에서도 초기화 완료 처리
      _isInitialized = true;
      _isFirebaseAvailable = false;
      _setupMockAuth();
      debugPrint('AuthService: 오류 발생으로 모의 인증 서비스로 전환');
    }
  }

  /// 모의 인증 서비스 설정
  void _setupMockAuth() {
    debugPrint('AuthService: 모의 인증 서비스 설정 시작');
    try {
      // 모의 사용자 생성 (테스트용)
      _currentUser = UserModel(
        id: 'mock-test-user',
        email: 'test@example.com',
        displayName: '테스트 사용자',
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        favoriteCoins: [],
        settings: {'darkMode': false, 'notifications': true},
        profileUrl: '',
        isEmailVerified: true,
      );

      // 인증 상태 변경 이벤트 발생
      _authStateController.add(_currentUser);
      debugPrint('AuthService: 모의 사용자로 로그인 상태 설정 완료 - ${_currentUser?.email}');

      // 초기화 완료 표시
      _isInitialized = true;
      debugPrint('AuthService: 모의 인증 서비스 초기화 완료');
    } catch (e) {
      debugPrint('AuthService: 모의 인증 서비스 설정 실패 - $e');
      // 오류가 발생해도 초기화는 완료된 것으로 처리
      _isInitialized = true;
    }
  }

  /// Firebase 인증 상태 변경 처리
  Future<void> _handleAuthStateChange(firebase_auth.User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
      _authStateController.add(null);
      debugPrint('AuthService: 로그아웃 상태');
      return;
    }

    // Firebase 사용자 정보를 UserModel로 변환
    _currentUser = UserModel(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? '사용자',
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
      lastLoginAt: firebaseUser.metadata.lastSignInTime ?? DateTime.now(),
      favoriteCoins: [],
      settings: {'darkMode': false, 'notifications': true},
      profileUrl: firebaseUser.photoURL ?? '',
      isEmailVerified: firebaseUser.emailVerified,
    );

    _authStateController.add(_currentUser);
    debugPrint('AuthService: 로그인 상태 - ${_currentUser?.email}');
  }

  /// 현재 로그인한 사용자 가져오기
  UserModel? get currentUser => _currentUser;

  /// 인증 상태 스트림
  Stream<UserModel?> get authStateChanges => _authStateController.stream;

  /// 이메일/비밀번호로 회원가입
  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    // 웹 플랫폼에서는 모의 데이터 반환
    if (!_isFirebaseAvailable) {
      debugPrint('AuthService: 웹 플랫폼에서 모의 회원가입 처리');
      final user = UserModel(
        id: 'web-${Uuid().v4()}',
        email: email,
        displayName: displayName,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        favoriteCoins: [],
        settings: {'darkMode': false, 'notifications': true},
        profileUrl: '',
        isEmailVerified: false,
      );

      _currentUser = user;
      _authStateController.add(_currentUser);
      return user;
    }

    try {
      // Firebase 회원가입
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 사용자 프로필 업데이트
      await userCredential.user?.updateDisplayName(displayName);

      // 사용자 정보 반환
      if (userCredential.user != null) {
        final user = UserModel(
          id: userCredential.user!.uid,
          email: email,
          displayName: displayName,
          createdAt:
              userCredential.user!.metadata.creationTime ?? DateTime.now(),
          lastLoginAt:
              userCredential.user!.metadata.lastSignInTime ?? DateTime.now(),
          favoriteCoins: [],
          settings: {'darkMode': false, 'notifications': true},
          profileUrl: '',
          isEmailVerified: false,
        );

        return user;
      } else {
        throw Exception('회원가입 실패: 사용자 정보를 가져올 수 없습니다.');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint(
        'AuthService: Firebase 회원가입 오류 - 코드: ${e.code}, 메시지: ${e.message}',
      );
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('이미 사용 중인 이메일입니다.');
        case 'invalid-email':
          throw Exception('유효하지 않은 이메일 형식입니다.');
        case 'weak-password':
          throw Exception('비밀번호가 너무 약합니다.');
        default:
          throw Exception('회원가입 실패: ${e.message}');
      }
    } catch (e) {
      debugPrint('AuthService: 회원가입 일반 오류 - $e');
      throw Exception('회원가입 실패: $e');
    }
  }

  /// 이메일/비밀번호로 로그인
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    // 웹 플랫폼에서는 모의 데이터 반환
    if (!_isFirebaseAvailable) {
      debugPrint('AuthService: 웹 플랫폼에서 모의 로그인 처리');
      final user = UserModel(
        id: 'web-test-user',
        email: email,
        displayName: email.split('@').first,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        favoriteCoins: [],
        settings: {'darkMode': false, 'notifications': true},
        profileUrl: '',
        isEmailVerified: true,
      );

      _currentUser = user;
      _authStateController.add(_currentUser);
      return user;
    }

    try {
      debugPrint(
        'AuthService: Firebase 로그인 시도 - 이메일: $email, 플랫폼: ${defaultTargetPlatform.toString()}',
      );

      // iOS에서 추가 디버깅
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        debugPrint('AuthService: iOS 플랫폼에서 로그인 시도');
        debugPrint('AuthService: Firebase 인스턴스 상태 - $_auth');
        debugPrint('AuthService: Firebase 사용 가능 여부 - $_isFirebaseAvailable');

        // iOS에서는 로그인 전에 현재 사용자가 있는지 확인하고 로그아웃
        if (_auth.currentUser != null) {
          debugPrint('AuthService: iOS에서 기존 사용자 로그아웃 시도');
          try {
            await _auth.signOut();
            debugPrint('AuthService: iOS에서 기존 사용자 로그아웃 성공');
          } catch (e) {
            debugPrint('AuthService: iOS에서 기존 사용자 로그아웃 실패 - $e');
          }
        }

        // iOS에서 Firebase 인증 초기화 재확인
        try {
          debugPrint('AuthService: iOS에서 Firebase 인증 재초기화 시도');
          await firebase_auth.FirebaseAuth.instance.app.delete();
          await Firebase.initializeApp(
            name: 'CoinAlarmApp',
            options: DefaultFirebaseOptions.ios,
          );
          _auth = firebase_auth.FirebaseAuth.instance;
          debugPrint('AuthService: iOS에서 Firebase 인증 재초기화 성공');
        } catch (e) {
          debugPrint('AuthService: iOS에서 Firebase 인증 재초기화 실패 (무시 가능) - $e');
        }
      }

      // Firebase 로그인 - iOS에서는 재시도 로직 추가
      firebase_auth.UserCredential? userCredential;
      int maxRetries = 2;
      int retryCount = 0;

      while (retryCount <= maxRetries) {
        try {
          debugPrint('AuthService: Firebase 로그인 시도 #${retryCount + 1}');

          // iOS에서는 다른 방식으로 시도
          if (defaultTargetPlatform == TargetPlatform.iOS) {
            // iOS에서는 먼저 이메일 검증
            await _auth
                .fetchSignInMethodsForEmail(email)
                .then((methods) {
                  debugPrint(
                    'AuthService: 이메일($email)에 사용 가능한 로그인 방법: $methods',
                  );
                })
                .catchError((e) {
                  debugPrint('AuthService: 이메일 검증 실패 (무시 가능) - $e');
                });
          }

          userCredential = await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          debugPrint('AuthService: 로그인 성공');
          break; // 성공하면 반복문 종료
        } on firebase_auth.FirebaseAuthException catch (e) {
          if ((e.code == 'invalid-credential' ||
                  e.code == 'network-request-failed') &&
              retryCount < maxRetries &&
              defaultTargetPlatform == TargetPlatform.iOS) {
            retryCount++;
            debugPrint('AuthService: iOS에서 ${e.code} 오류, 재시도 #$retryCount');
            await Future.delayed(Duration(milliseconds: 1000 * retryCount));
            continue;
          }
          // 다른 오류이거나 최대 재시도 횟수를 초과한 경우 예외 다시 발생
          debugPrint('AuthService: 재시도 불가능한 오류 - ${e.code}');
          rethrow;
        }
      }

      if (userCredential == null) {
        throw Exception('로그인 실패: 사용자 인증에 실패했습니다.');
      }

      debugPrint(
        'AuthService: Firebase 로그인 성공 - UID: ${userCredential.user?.uid}',
      );

      // 사용자 정보 반환
      if (userCredential.user != null) {
        final user = UserModel(
          id: userCredential.user!.uid,
          email: userCredential.user!.email ?? '',
          displayName: userCredential.user!.displayName ?? '사용자',
          createdAt:
              userCredential.user!.metadata.creationTime ?? DateTime.now(),
          lastLoginAt:
              userCredential.user!.metadata.lastSignInTime ?? DateTime.now(),
          favoriteCoins: [],
          settings: {'darkMode': false, 'notifications': true},
          profileUrl: userCredential.user!.photoURL ?? '',
          isEmailVerified: userCredential.user!.emailVerified,
        );

        return user;
      } else {
        debugPrint('AuthService: 로그인 실패 - 사용자 정보 없음');
        throw Exception('로그인 실패: 사용자 정보를 가져올 수 없습니다.');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint(
        'AuthService: Firebase 로그인 오류 - 코드: ${e.code}, 메시지: ${e.message}',
      );

      // iOS에서 추가 디버깅
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        debugPrint('AuthService: iOS 플랫폼에서 Firebase 오류 발생');
        debugPrint('AuthService: 오류 세부 정보 - ${e.toString()}');

        // iOS에서는 특정 오류를 다르게 처리
        if (e.code == 'invalid-credential') {
          // 계정이 있는지 확인
          try {
            final methods = await _auth.fetchSignInMethodsForEmail(email);
            if (methods.isEmpty) {
              return Future.error(
                Exception('등록되지 않은 이메일입니다. 회원가입을 먼저 진행해주세요.'),
              );
            } else {
              return Future.error(Exception('비밀번호가 일치하지 않습니다. 다시 시도해주세요.'));
            }
          } catch (innerError) {
            debugPrint('AuthService: 이메일 검증 실패 - $innerError');
          }
        }
      }

      switch (e.code) {
        case 'user-not-found':
          throw Exception('등록되지 않은 이메일입니다. 회원가입을 먼저 진행해주세요.');
        case 'wrong-password':
          throw Exception('비밀번호가 일치하지 않습니다. 다시 시도해주세요.');
        case 'invalid-email':
          throw Exception('유효하지 않은 이메일 형식입니다.');
        case 'user-disabled':
          throw Exception('비활성화된 계정입니다.');
        case 'network-request-failed':
          throw Exception('네트워크 연결을 확인해주세요.');
        case 'too-many-requests':
          throw Exception('로그인 시도가 너무 많습니다. 잠시 후 다시 시도해주세요.');
        case 'invalid-credential':
          throw Exception('인증 정보가 유효하지 않습니다. 이메일과 비밀번호를 확인해주세요.');
        case 'operation-not-allowed':
          throw Exception('이 인증 방식은 현재 지원되지 않습니다.');
        default:
          throw Exception('로그인 실패: ${e.message}');
      }
    } catch (e) {
      debugPrint('AuthService: 로그인 일반 오류 - $e');
      debugPrint('AuthService: 오류 스택 트레이스 - ${StackTrace.current}');
      throw Exception('로그인 실패: $e');
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    if (_isFirebaseAvailable) {
      await _auth.signOut();
    }

    _currentUser = null;
    _authStateController.add(null);
  }

  /// 비밀번호 재설정 이메일 전송
  Future<void> sendPasswordResetEmail({required String email}) async {
    if (!_isFirebaseAvailable) {
      debugPrint('AuthService: 웹 플랫폼에서는 비밀번호 재설정을 지원하지 않습니다.');
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on firebase_auth.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          throw Exception('유효하지 않은 이메일 형식입니다.');
        case 'user-not-found':
          throw Exception('해당 이메일로 가입된 사용자가 없습니다.');
        default:
          throw Exception('비밀번호 재설정 이메일 전송 실패: ${e.message}');
      }
    } catch (e) {
      throw Exception('비밀번호 재설정 이메일 전송 실패: $e');
    }
  }

  /// 이메일 인증 전송
  Future<void> sendEmailVerification() async {
    if (!_isFirebaseAvailable) {
      debugPrint('AuthService: 웹 플랫폼에서는 이메일 인증을 지원하지 않습니다.');
      return;
    }

    try {
      await _auth.currentUser?.sendEmailVerification();
    } catch (e) {
      throw Exception('이메일 인증 전송 실패: $e');
    }
  }

  /// 이메일 인증 상태 새로고침
  Future<void> refreshEmailVerificationStatus() async {
    if (!_isFirebaseAvailable) {
      debugPrint('AuthService: 웹 플랫폼에서는 이메일 인증 상태 새로고침을 지원하지 않습니다.');
      return;
    }

    try {
      await _auth.currentUser?.reload();
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        await _handleAuthStateChange(firebaseUser);
      }
    } catch (e) {
      throw Exception('이메일 인증 상태 새로고침 실패: $e');
    }
  }

  /// 사용자 프로필 업데이트
  Future<UserModel> updateUserProfile({
    String? name,
    String? profileUrl,
  }) async {
    if (!_isFirebaseAvailable) {
      debugPrint('AuthService: 웹 플랫폼에서 모의 프로필 업데이트');
      if (_currentUser != null) {
        _currentUser = UserModel(
          id: _currentUser!.id,
          email: _currentUser!.email,
          displayName: name ?? _currentUser!.displayName,
          createdAt: _currentUser!.createdAt,
          lastLoginAt: DateTime.now(),
          favoriteCoins: _currentUser!.favoriteCoins,
          settings: _currentUser!.settings,
          profileUrl: profileUrl ?? _currentUser!.profileUrl,
          isEmailVerified: _currentUser!.isEmailVerified,
        );
        _authStateController.add(_currentUser);
        return _currentUser!;
      } else {
        throw Exception('로그인된 사용자가 없습니다.');
      }
    }

    try {
      if (_auth.currentUser == null) {
        throw Exception('로그인된 사용자가 없습니다.');
      }

      if (name != null) {
        await _auth.currentUser!.updateDisplayName(name);
      }

      if (profileUrl != null) {
        await _auth.currentUser!.updatePhotoURL(profileUrl);
      }

      await _auth.currentUser!.reload();
      final firebaseUser = _auth.currentUser;

      if (firebaseUser != null) {
        await _handleAuthStateChange(firebaseUser);
        return _currentUser!;
      } else {
        throw Exception('사용자 정보를 가져올 수 없습니다.');
      }
    } catch (e) {
      throw Exception('프로필 업데이트 실패: $e');
    }
  }

  /// 이메일 업데이트
  Future<void> updateEmail(String email) async {
    if (!_isFirebaseAvailable) {
      debugPrint('AuthService: 웹 플랫폼에서는 이메일 업데이트를 지원하지 않습니다.');
      return;
    }

    try {
      if (_auth.currentUser == null) {
        throw Exception('로그인된 사용자가 없습니다.');
      }

      await _auth.currentUser!.updateEmail(email);
      await _auth.currentUser!.reload();

      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        await _handleAuthStateChange(firebaseUser);
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          throw Exception('유효하지 않은 이메일 형식입니다.');
        case 'email-already-in-use':
          throw Exception('이미 사용 중인 이메일입니다.');
        case 'requires-recent-login':
          throw Exception('보안을 위해 재로그인이 필요합니다.');
        default:
          throw Exception('이메일 업데이트 실패: ${e.message}');
      }
    } catch (e) {
      throw Exception('이메일 업데이트 실패: $e');
    }
  }

  /// 비밀번호 업데이트
  Future<void> updatePassword(String password) async {
    if (!_isFirebaseAvailable) {
      debugPrint('AuthService: 웹 플랫폼에서는 비밀번호 업데이트를 지원하지 않습니다.');
      return;
    }

    try {
      if (_auth.currentUser == null) {
        throw Exception('로그인된 사용자가 없습니다.');
      }

      await _auth.currentUser!.updatePassword(password);
    } on firebase_auth.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          throw Exception('비밀번호가 너무 약합니다.');
        case 'requires-recent-login':
          throw Exception('보안을 위해 재로그인이 필요합니다.');
        default:
          throw Exception('비밀번호 업데이트 실패: ${e.message}');
      }
    } catch (e) {
      throw Exception('비밀번호 업데이트 실패: $e');
    }
  }

  /// 계정 삭제
  Future<void> deleteAccount() async {
    if (!_isFirebaseAvailable) {
      debugPrint('AuthService: 웹 플랫폼에서는 계정 삭제를 지원하지 않습니다.');
      _currentUser = null;
      _authStateController.add(null);
      return;
    }

    try {
      if (_auth.currentUser == null) {
        throw Exception('로그인된 사용자가 없습니다.');
      }

      await _auth.currentUser!.delete();
    } on firebase_auth.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'requires-recent-login':
          throw Exception('보안을 위해 재로그인이 필요합니다.');
        default:
          throw Exception('계정 삭제 실패: ${e.message}');
      }
    } catch (e) {
      throw Exception('계정 삭제 실패: $e');
    }
  }
}
