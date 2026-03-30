class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.receiveNotifications,
    required this.preferredLanguage,
    required this.darkMode,
  });

  final String fullName;
  final String email;
  final String phone;
  final bool receiveNotifications;
  final String preferredLanguage;
  final bool darkMode;

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? phone,
    bool? receiveNotifications,
    String? preferredLanguage,
    bool? darkMode,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      receiveNotifications: receiveNotifications ?? this.receiveNotifications,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      darkMode: darkMode ?? this.darkMode,
    );
  }
}
