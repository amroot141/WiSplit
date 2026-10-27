class UserSession {
  final String userId;
  final String email;
  final String fullName;
  final String? accessToken;
  final String? refreshToken;
  final String currency;
  final bool isLoggedIn;
  final String? avatarUrl;

  const UserSession({
    required this.userId,
    required this.email,
    required this.fullName,
    this.accessToken,
    this.refreshToken,
    this.currency = 'INR',
    this.isLoggedIn = true,
    this.avatarUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': userId,
      'email': email,
      'full_name': fullName,
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'currency': currency,
      'is_logged_in': isLoggedIn ? 1 : 0,
      'avatar_url': avatarUrl,
    };
  }

  factory UserSession.fromMap(Map<String, dynamic> map) {
    return UserSession(
      userId: map['id'] as String,
      email: map['email'] as String,
      fullName: map['full_name'] as String,
      accessToken: map['access_token'] as String?,
      refreshToken: map['refresh_token'] as String?,
      currency: (map['currency'] as String?) ?? 'INR',
      isLoggedIn: (map['is_logged_in'] as int? ?? 1) == 1,
      avatarUrl: map['avatar_url'] as String?,
    );
  }

  UserSession copyWith({
    String? userId,
    String? email,
    String? fullName,
    String? accessToken,
    String? refreshToken,
    String? currency,
    bool? isLoggedIn,
    String? avatarUrl,
  }) {
    return UserSession(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      currency: currency ?? this.currency,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
