import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../model/user_model.dart';
import 'supabase_client.dart';

/// Supabase 인증 서비스
///
/// 사용자 인증 관련 기능을 제공합니다.
/// - 로그인 (이메일/비밀번호)
/// - 회원가입
/// - 로그아웃
/// - 비밀번호 재설정
/// - 현재 사용자 정보 조회
class AuthService {
  // 싱글톤 패턴
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Supabase 클라이언트
  final SupabaseClientService _supabaseClientService = SupabaseClientService();

  // 현재 로그인된 사용자 캐시
  User? _currentUser;

  /// 로그인 상태 확인
  bool get isLoggedIn => _supabaseClientService.client.auth.currentUser != null;

  /// 현재 사용자 정보 가져오기
  Future<User?> getCurrentUser() async {
    try {
      final authUser = _supabaseClientService.client.auth.currentUser;
      if (authUser == null) return null;

      // 캐시된 사용자가 있고, ID가 같으면 캐시된 정보 반환
      if (_currentUser != null && _currentUser!.id == authUser.id) {
        return _currentUser;
      }

      // 사용자 상세 정보 가져오기
      final userData = await _supabaseClientService.client
          .from('users')
          .select()
          .eq('id', authUser.id)
          .single();

      // 사용자 정보 캐싱 및 반환
      _currentUser = User.fromJson({
        ...userData,
        'id': authUser.id,
        'email': authUser.email ?? '',
        'created_at': authUser.createdAt,
      });

      return _currentUser;
    } catch (e) {
      debugPrint('AuthService: 현재 사용자 정보 가져오기 실패 - $e');
      return null;
    }
  }

  /// 이메일/비밀번호로 로그인
  Future<User> signInWithEmailAndPassword(String email, String password) async {
    try {
      final response = await _supabaseClientService.client.auth
          .signInWithPassword(email: email, password: password);

      final authUser = response.user;
      if (authUser == null) {
        throw Exception('로그인에 실패했습니다.');
      }

      // 사용자 정보 조회
      final userData = await _supabaseClientService.client
          .from('users')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();

      // users 테이블에 정보가 없는 경우 기본 정보 생성
      if (userData == null) {
        final newUserData = {
          'id': authUser.id,
          'name': email.split('@').first, // 이메일 아이디를 기본 이름으로 사용
          'email': authUser.email ?? '',
        };

        await _supabaseClientService.client.from('users').insert(newUserData);

        _currentUser = User.fromJson({
          ...newUserData,
          'created_at': authUser.createdAt,
        });
      } else {
        _currentUser = User.fromJson({
          ...userData,
          'id': authUser.id,
          'email': authUser.email ?? '',
          'created_at': authUser.createdAt,
        });
      }

      return _currentUser!;
    } catch (e) {
      debugPrint('AuthService: 로그인 실패 - $e');
      rethrow;
    }
  }

  /// 회원가입
  Future<User> signUp(String email, String password, {String? name}) async {
    try {
      final response = await _supabaseClientService.client.auth.signUp(
        email: email,
        password: password,
      );

      final authUser = response.user;
      if (authUser == null) {
        throw Exception('회원가입에 실패했습니다.');
      }

      // 사용자 기본 정보 생성
      final userData = {
        'id': authUser.id,
        'name': name ?? email.split('@').first, // 이름이 없으면 이메일 아이디 사용
        'email': email,
      };

      await _supabaseClientService.client.from('users').insert(userData);

      _currentUser = User.fromJson({
        ...userData,
        'created_at': authUser.createdAt,
      });

      return _currentUser!;
    } catch (e) {
      debugPrint('AuthService: 회원가입 실패 - $e');
      rethrow;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    try {
      await _supabaseClientService.client.auth.signOut();
      _currentUser = null;
      debugPrint('AuthService: 로그아웃 성공');
    } catch (e) {
      debugPrint('AuthService: 로그아웃 실패 - $e');
      rethrow;
    }
  }

  /// 비밀번호 재설정 이메일 전송
  Future<void> resetPassword(String email) async {
    try {
      await _supabaseClientService.client.auth.resetPasswordForEmail(email);
      debugPrint('AuthService: 비밀번호 재설정 이메일 전송 성공');
    } catch (e) {
      debugPrint('AuthService: 비밀번호 재설정 이메일 전송 실패 - $e');
      rethrow;
    }
  }

  /// 사용자 정보 업데이트
  Future<User> updateUserProfile(Map<String, dynamic> data) async {
    try {
      final authUser = _supabaseClientService.client.auth.currentUser;
      if (authUser == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // 업데이트할 필드만 추출
      final updateData = <String, dynamic>{};
      if (data.containsKey('name')) updateData['name'] = data['name'];
      if (data.containsKey('avatar_url'))
        updateData['avatar_url'] = data['avatar_url'];
      if (data.containsKey('settings'))
        updateData['settings'] = data['settings'];

      // 업데이트할 데이터가 있는 경우에만 업데이트 수행
      if (updateData.isNotEmpty) {
        await _supabaseClientService.client
            .from('users')
            .update(updateData)
            .eq('id', authUser.id);
      }

      // 업데이트된 사용자 정보 조회
      return await getCurrentUser() ?? _currentUser!;
    } catch (e) {
      debugPrint('AuthService: 사용자 정보 업데이트 실패 - $e');
      rethrow;
    }
  }
}
