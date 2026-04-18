import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/yahoo_finance_service.dart';
import 'profile_screen.dart';

// =============================================================================
// SettingsScreen — Màn hình Cài đặt Hệ thống
// =============================================================================
//
// Tính năng:
//   - Toggle Dark Mode
//   - Toggle Nhận thông báo
//   - Chọn ngôn ngữ (BottomSheet)
//   - Navigate sang ProfileScreen (chỉnh sửa thông tin cá nhân)
//   - Đăng xuất (TODO)
//
// LUỒNG PROFILE:
//   initState → fetchUserProfile() → _profileFuture
//   _loadProfile() → lưu vào _profile (local state)
//   Thay đổi toggle → _updateProfile() → setState + apiService.updateUserProfile()
//   Mở ProfileScreen → nhận kết quả (UserProfile?) khi pop → _updateProfile()
//
// LƯU Ý: fetchUserProfile / updateUserProfile hiện tại là MOCK.
// Chưa có backend authentication thật.
// =============================================================================

/// Màn hình Cài đặt — quản lý tùy chọn giao diện và thông tin người dùng.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final YahooFinanceService _apiService = YahooFinanceService.instance;

  late Future<UserProfile> _profileFuture; // Future để FutureBuilder
  UserProfile? _profile; // Local state sau khi Future complete (tôi cập nhật được ngay)

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  // ---------------------------------------------------------------------------
  // Data Operations
  // ---------------------------------------------------------------------------

  /// Tải hồ sơ người dùng và lưu vào [_profile] để cập nhật trực tiếp.
  ///
  /// Khác với chỉ dùng FutureBuilder: lưu vào _profile để setState ngay khi toggle
  /// mà không cần đợi Future mới (tránh flash loading khi chỉnh toggle).
  Future<UserProfile> _loadProfile() async {
    final UserProfile profile = await _apiService.fetchUserProfile();
    _profile = profile; // Lưu local copy
    return profile;
  }

  /// Cập nhật profile: setState để UI phản hồi ngay + gọi API lưu.
  Future<void> _updateProfile(UserProfile updated) async {
    // setState ngay → UI cập nhật tức thì (không chờ API)
    // Đây là pattern "Optimistic Update" — cập nhật UI trước, lưu sau
    setState(() {
      _profile = updated;
    });
    await _apiService.updateUserProfile(updated); // Lưu (hiện tại mock)
  }

  // ---------------------------------------------------------------------------
  // Build UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: FutureBuilder<UserProfile>(
        future: _profileFuture,
        builder: (BuildContext context, AsyncSnapshot<UserProfile> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Không thể tải cài đặt: ${snapshot.error}'));
          }
          // Ưu tiên dùng _profile (local state) thay vì snapshot.data
          // Vì _profile đã được cập nhật ngay khi toggle, còn snapshot.data cũ hơn
          final UserProfile profile = _profile ?? snapshot.data!;

          return ListView(
            children: <Widget>[
              // ── Dark Mode Toggle ──────────────────────────
              SwitchListTile(
                title: const Text('Chế độ tối'),
                value: profile.darkMode,
                onChanged: (bool value) {
                  // copyWith: tạo UserProfile mới với chỉ darkMode thay đổi
                  final UserProfile updated = profile.copyWith(darkMode: value);
                  _updateProfile(updated);
                  // TODO: Áp dụng ThemeMode thật sự vào MaterialApp (hiện chỉ lưu mock)
                },
              ),

              // ── Notifications Toggle ──────────────────────
              SwitchListTile(
                title: const Text('Nhận thông báo'),
                value: profile.receiveNotifications,
                onChanged: (bool value) {
                  final UserProfile updated =
                      profile.copyWith(receiveNotifications: value);
                  _updateProfile(updated);
                },
              ),

              // ── Language Selector ─────────────────────────
              ListTile(
                title: const Text('Ngôn ngữ'),
                subtitle: Text(
                    profile.preferredLanguage == 'vi' ? 'Tiếng Việt' : 'English'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  // showModalBottomSheet<String>: sheet trả về String? khi pop
                  final String? selected = await showModalBottomSheet<String>(
                    context: context,
                    builder: (BuildContext context) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ListTile(
                            title: const Text('Tiếng Việt'),
                            // Navigator.pop(context, 'vi') → trả về 'vi' cho await
                            onTap: () => Navigator.pop(context, 'vi'),
                          ),
                          ListTile(
                            title: const Text('English'),
                            onTap: () => Navigator.pop(context, 'en'),
                          ),
                        ],
                      );
                    },
                  );
                  // Chỉ update nếu thực sự chọn khác (không update khi dismiss)
                  if (selected != null && selected != profile.preferredLanguage) {
                    final UserProfile updated =
                        profile.copyWith(preferredLanguage: selected);
                    _updateProfile(updated);
                  }
                },
              ),

              const Divider(), // Đường kẻ phân cách

              // ── Profile Link ──────────────────────────────
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Hồ sơ cá nhân'),
                subtitle: const Text('Thông tin tài khoản, đổi mật khẩu'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  // pushNamed<UserProfile>: generic type → khi pop(result) có type-check
                  // Truyền profile hiện tại làm arguments → ProfileScreen nhận và hiển thị sẵn
                  final UserProfile? updated =
                      await Navigator.of(context).pushNamed<UserProfile>(
                    ProfileScreen.routeName,
                    arguments: profile,
                  );
                  // Nếu ProfileScreen trả về profile mới (sau khi Lưu) → cập nhật
                  if (updated != null) {
                    _updateProfile(updated);
                  }
                },
              ),

              // ── Logout ───────────────────────────────────
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Đăng xuất'),
                onTap: () {
                  // TODO: Xóa auth token, clear local storage, navigate về màn hình đăng nhập
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
