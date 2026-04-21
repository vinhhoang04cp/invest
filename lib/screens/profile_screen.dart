import 'package:flutter/material.dart';

import '../models/user.dart';

// =============================================================================
// ProfileScreen — Màn hình Hồ sơ Cá nhân (Form chỉnh sửa)
// =============================================================================
//
// Nhận dữ liệu từ navigation arguments (UserProfile từ SettingsScreen).
// Khi Lưu → pop với UserProfile đã cập nhật → SettingsScreen nhận và lưu Firestore.
//
// PATTERN: Form validation với GlobalKey<FormState>
//   _formKey.currentState!.validate() → chạy tất cả validator của TextFormField
//   → Nếu tất cả pass → true; có field fail → false (và hiện error message)
// =============================================================================

/// Màn hình chỉnh sửa hồ sơ cá nhân.
///
/// Nhận [UserProfile] qua navigation arguments.
/// Khi lưu thành công → `Navigator.pop(updatedProfile)` trả về profile mới.
/// SettingsScreen nhận và ghi lên Firestore.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const String routeName = '/profile';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Key để truy cập Form state và trigger validation.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controllers cho từng TextField (phải dispose khi xong)
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  late UserProfile _profile;           // Profile gốc nhận từ args
  bool _notifications = false;         // State riêng cho Switch
  bool _initialized = false;           // Cờ tránh init lại nhiều lần

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    // Lấy UserProfile từ navigation arguments (SettingsScreen truyền vào)
    final UserProfile profile =
        ModalRoute.of(context)!.settings.arguments as UserProfile;
    _profile = profile;

    // Khởi tạo controllers với giá trị từ profile
    _nameController = TextEditingController(text: profile.fullName);
    _emailController = TextEditingController(text: profile.email);
    _phoneController = TextEditingController(text: profile.phone);
    _notifications = profile.receiveNotifications;
    _initialized = true;
  }

  @override
  void dispose() {
    // BẮTT BUỘC: dispose tất cả TextEditingController
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Business Logic
  // ---------------------------------------------------------------------------

  /// Validate form và pop với UserProfile đã cập nhật nếu hợp lệ.
  void _saveProfile() {
    if (!_formKey.currentState!.validate()) return;

    // copyWith: immutable update — tạo object mới với chỉ các field được thay đổi
    final UserProfile updated = _profile.copyWith(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      receiveNotifications: _notifications,
    );

    // pop(result): đóng màn hình và trả về result cho SettingsScreen
    // SettingsScreen sẽ gọi _updateProfile() → lưu lên Firestore
    Navigator.of(context).pop(updated);
  }

  // ---------------------------------------------------------------------------
  // Build UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        actions: <Widget>[
          TextButton(
            onPressed: _saveProfile,
            child: const Text('Lưu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              // ── Họ tên ──────────────────────────────────
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập họ tên';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Email (chỉ đọc — email từ Firebase Auth) ──
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  helperText: 'Email không thể thay đổi (liên kết với tài khoản)',
                ),
                readOnly: true, // Email đăng ký không cho sửa
                enabled: false,
              ),
              const SizedBox(height: 16),

              // ── Số điện thoại ─────────────────────────────
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                keyboardType: TextInputType.phone,
                validator: (String? value) {
                  // Phone là tùy chọn, không bắt buộc
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ── Nhận thông báo ────────────────────────────
              SwitchListTile(
                title: const Text('Nhận thông báo từ ứng dụng'),
                value: _notifications,
                onChanged: (bool value) {
                  setState(() {
                    _notifications = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
