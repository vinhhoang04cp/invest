/// Mô hình đại diện cho hồ sơ, thông tin cá nhân và cài đặt ứng dụng của người dùng.
class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.receiveNotifications,
    required this.preferredLanguage,
    required this.darkMode,
  });

  /// Factory constructor: tạo UserProfile từ Firestore document data.
  factory UserProfile.fromFirestore(Map<String, dynamic> data) {
    return UserProfile(
      fullName: (data['fullName'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      receiveNotifications: (data['receiveNotifications'] as bool?) ?? true,
      preferredLanguage: (data['preferredLanguage'] as String?) ?? 'vi',
      darkMode: (data['darkMode'] as bool?) ?? false,
    );
  }

  final String fullName;          // Họ và tên
  final String email;             // Địa chỉ email
  final String phone;             // Số điện thoại
  final bool receiveNotifications;// Tùy chọn nhận thông báo push hay không
  final String preferredLanguage; // Ngôn ngữ ưu tiên (vi, en)
  final bool darkMode;            // Cài đặt giao diện Tối/Sáng

  /// Chuyển UserProfile thành Map để lưu lên Firestore.
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'receiveNotifications': receiveNotifications,
      'preferredLanguage': preferredLanguage,
      'darkMode': darkMode,
    };
  }

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
