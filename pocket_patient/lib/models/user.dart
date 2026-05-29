class AppUser {
  final String id;
  final String email;
  final String? role;
  final String? displayName;
  final bool isVerified;

  const AppUser({
    required this.id,
    required this.email,
    this.role,
    this.displayName,
    required this.isVerified,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        role: json['role'] as String?,
        displayName: json['display_name'] as String?,
        isVerified: json['is_verified'] as bool? ?? false,
      );

  AppUser copyWith({String? role, String? displayName, bool? isVerified}) =>
      AppUser(
        id: id,
        email: email,
        role: role ?? this.role,
        displayName: displayName ?? this.displayName,
        isVerified: isVerified ?? this.isVerified,
      );
}
