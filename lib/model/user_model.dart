// 사용자 모델 클래스
import 'dart:convert';

class UserModel {
  /// 사용자 ID
  final String id;

  /// 사용자 이메일
  final String email;

  /// 사용자 이름
  final String displayName;

  /// 프로필 이미지 URL
  final String profileUrl;

  /// 이메일 인증 여부
  final bool isEmailVerified;

  /// 생성 시간
  final DateTime createdAt;

  /// 마지막 로그인 시간
  final DateTime lastLoginAt;

  /// 즐겨찾기 코인 목록
  final List<String> favoriteCoins;

  /// 사용자 설정
  final Map<String, dynamic> settings;

  /// 생성자
  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.profileUrl = '',
    this.isEmailVerified = false,
    required this.createdAt,
    required this.lastLoginAt,
    this.favoriteCoins = const [],
    this.settings = const {},
  });

  /// JSON으로부터 UserModel 객체 생성
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String,
      profileUrl: json['profile_url'] as String? ?? '',
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : DateTime.now(),
      favoriteCoins: json['favorite_coins'] != null
          ? List<String>.from(json['favorite_coins'] as List)
          : [],
      settings: json['settings'] != null
          ? Map<String, dynamic>.from(json['settings'] as Map)
          : {},
    );
  }

  /// UserModel 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'profile_url': profileUrl,
      'is_email_verified': isEmailVerified,
      'created_at': createdAt.toIso8601String(),
      'last_login_at': lastLoginAt.toIso8601String(),
      'favorite_coins': favoriteCoins,
      'settings': settings,
    };
  }

  /// 특정 필드만 업데이트된 새 UserModel 객체 생성
  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? profileUrl,
    bool? isEmailVerified,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    List<String>? favoriteCoins,
    Map<String, dynamic>? settings,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      profileUrl: profileUrl ?? this.profileUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      favoriteCoins: favoriteCoins ?? this.favoriteCoins,
      settings: settings ?? this.settings,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, displayName: $displayName)';
  }
}
