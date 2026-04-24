/// Mô hình đại diện cho hồ sơ, thông tin cá nhân và cài đặt ứng dụng của người dùng.
class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.receiveNotifications,
    required this.preferredLanguage,
    required this.darkMode,
    this.avatarUrl,
    this.bio,
    this.experience,
    this.strategy,
    this.address,
    this.dob,
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
      avatarUrl: data['avatarUrl'] as String?,
      bio: data['bio'] as String?,
      experience: data['experience'] as String?,
      strategy: data['strategy'] as String?,
      address: data['address'] as String?,
      dob: data['dob'] != null ? DateTime.tryParse(data['dob'] as String) : null,
    );
  }

  final String fullName;          // Họ và tên
  final String email;             // Địa chỉ email
  final String phone;             // Số điện thoại
  final bool receiveNotifications;// Tùy chọn nhận thông báo push hay không
  final String preferredLanguage; // Ngôn ngữ ưu tiên (vi, en)
  final bool darkMode;            // Cài đặt giao diện Tối/Sáng
  final String? avatarUrl;        // Link ảnh đại diện
  final String? bio;              // Giới thiệu bản thân
  final String? experience;       // Kinh nghiệm đầu tư (F0, Intermediate, Expert)
  final String? strategy;         // Chiến thuật (Growth, Value, Dividend, etc.)
  final String? address;          // Địa chỉ
  final DateTime? dob;            // Ngày sinh

  /// Chuyển UserProfile thành Map để lưu lên Firestore.
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'receiveNotifications': receiveNotifications,
      'preferredLanguage': preferredLanguage,
      'darkMode': darkMode,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'experience': experience,
      'strategy': strategy,
      'address': address,
      'dob': dob?.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? phone,
    bool? receiveNotifications,
    String? preferredLanguage,
    bool? darkMode,
    String? avatarUrl,
    String? bio,
    String? experience,
    String? strategy,
    String? address,
    DateTime? dob,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      receiveNotifications: receiveNotifications ?? this.receiveNotifications,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      darkMode: darkMode ?? this.darkMode,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      experience: experience ?? this.experience,
      strategy: strategy ?? this.strategy,
      address: address ?? this.address,
      dob: dob ?? this.dob,
    );
  }
}
