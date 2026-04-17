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

  final String fullName;          // Họ và tên
  final String email;             // Địa chỉ email
  final String phone;             // Số điện thoại
  final bool receiveNotifications;// Tùy chọn nhận thông báo push hay không
  final String preferredLanguage; // Ngôn ngữ ưu tiên (vi, en)
  final bool darkMode;            // Cài đặt giao diện Tối/Sáng

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
