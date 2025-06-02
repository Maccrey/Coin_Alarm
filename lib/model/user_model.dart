// 사용자 모델 클래스

class User {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;
  final String? profileImageUrl;
  final List<String> favoriteCoins;
  final Map<String, dynamic>? settings;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
    this.profileImageUrl,
    this.favoriteCoins = const [],
    this.settings,
  });

  // JSON 데이터로부터 User 객체 생성
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'] ?? '사용자',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      profileImageUrl: json['profile_image_url'],
      favoriteCoins: json['favorite_coins'] != null
          ? List<String>.from(json['favorite_coins'])
          : [],
      settings: json['settings'],
    );
  }

  // User 객체를 JSON 데이터로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'profile_image_url': profileImageUrl,
      'favorite_coins': favoriteCoins,
      'settings': settings,
    };
  }

  // User 객체 복사본 생성 (필드 업데이트 가능)
  User copyWith({
    String? id,
    String? email,
    String? name,
    DateTime? createdAt,
    String? profileImageUrl,
    List<String>? favoriteCoins,
    Map<String, dynamic>? settings,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      favoriteCoins: favoriteCoins ?? this.favoriteCoins,
      settings: settings ?? this.settings,
    );
  }
}
