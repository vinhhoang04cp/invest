import 'package:flutter/material.dart';

import '../models/user.dart';

// =============================================================================
// ProfileScreen — Màn hình Hồ sơ Cá nhân (Form chỉnh sửa)
// =============================================================================
//
// Nhận dữ liệu từ navigation arguments (UserProfile từ SettingsScreen).
// Khi Lưu → pop với UserProfile đã cập nhật → SettingsScreen nhận và cập nhật.
//
// PATTERN: Form validation với GlobalKey<FormState>
//   _formKey.currentState!.validate() → chạy tất cả validator của TextFormField
//   → Nếu tất cả pass → true; có field fail → false (và hiện error message)
//
// LƯU Ý: Màn hình này chỉ CHỈNH SỬA thông tin trong bộ nhớ.
// Chưa có tích hợp backend (auth, storage) thật sự.
// =============================================================================

/// Màn hình chỉnh sửa hồ sơ cá nhân.
///
/// Nhận [UserProfile] qua navigation arguments.
/// Khi lưu thành công → `Navigator.pop(updatedProfile)` trả về profile mới.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const String routeName = '/profile';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Key để truy cập Form state và trigger validation.
  /// GlobalKey<FormState>: typed key đảm bảo type-safe khi gọi validate()/save()
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controllers cho từng TextField (phải dispose khi xong)
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  late UserProfile _profile;           // Profile gốc nhận từ args
  bool _notifications = false;         // State riêng cho Switch (không dùng TextEditingController)
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
    // Mỗi controller có Timer và listener references → leak nếu không dispose
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Business Logic
  // ---------------------------------------------------------------------------

  /// Validate form và pop với UserProfile đã cập nhật nếu hợp lệ.
  ///
  /// Form.validate() chạy tất cả validator functions của TextFormField con.
  /// Nếu pass hết → pop với updated profile → SettingsScreen nhận.
  void _saveProfile() {
    // validate() trả về false nếu có field nào fail → hiển thị error dưới field
    if (!_formKey.currentState!.validate()) return;

    // copyWith: immutable update — tạo object mới với chỉ các field được chỉ định thay đổi
    final UserProfile updated = _profile.copyWith(
      fullName: _nameController.text.trim(),       // trim() xóa khoảng trắng thừa
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      receiveNotifications: _notifications,
    );

    // pop(result): đóng màn hình và trả về result cho await ở SettingsScreen
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
        // Form widget: bọc các TextFormField để quản lý validation chung
        child: Form(
          key: _formKey, // Link Form với GlobalKey để gọi validate() từ ngoài
          child: ListView(
            children: <Widget>[
              // ── Họ tên ──────────────────────────────────
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                // validator: function chạy khi Form.validate() được gọi
                // Trả về String (error message) nếu không hợp lệ, null nếu OK
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập họ tên'; // Hiển thị dưới field
                  }
                  return null; // null = hợp lệ
                },
              ),
              const SizedBox(height: 16),

              // ── Email ────────────────────────────────────
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress, // Bàn phím ưu tiên @ ký tự
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập email';
                  }
                  // RegExp: validate format email đơn giản (xxx@xxx.xxx)
                  // `r'...'`: raw string, \ không bị escape → dùng cho regex
                  final bool isValid = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim());
                  if (!isValid) {
                    return 'Email không hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Số điện thoại ─────────────────────────────
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                keyboardType: TextInputType.phone, // Bàn phím số điện thoại
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập số điện thoại';
                  }
                  return null; // TODO: Thêm validate format số điện thoại VN
                },
              ),
              const SizedBox(height: 24),

              // ── Nhận thông báo ────────────────────────────
              SwitchListTile(
                title: const Text('Nhận thông báo từ ứng dụng'),
                value: _notifications,
                onChanged: (bool value) {
                  setState(() {
                    _notifications = value; // Local state → rebuild Switch
                  });
                },
              ),
              const SizedBox(height: 24),

              // Ghi chú TODO cho developer
              const Text(
                  'TODO(thanhvien5): Bổ sung thay đổi mật khẩu, ảnh đại diện, liên kết tài khoản...'),
            ],
          ),
        ),
      ),
    );
  }
}
