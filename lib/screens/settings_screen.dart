import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../state/auth_provider.dart';
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
//   - Đăng xuất (Firebase Auth)
//
// LUỒNG PROFILE (Firebase):
//   initState → đọc Firestore document users/{uid} → FutureBuilder hiển thị
//   Toggle / chỉnh sửa → ghi lại lên Firestore document users/{uid}
//   Đăng xuất → AuthProvider.signOut() → AuthGate redirect về LoginScreen
// =============================================================================

/// Màn hình Cài đặt — quản lý tùy chọn giao diện và thông tin người dùng.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<UserProfile> _profileFuture;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  // ---------------------------------------------------------------------------
  // Data Operations (Firestore)
  // ---------------------------------------------------------------------------

  /// Tải hồ sơ người dùng từ Firestore document users/{uid}.
  Future<UserProfile> _loadProfile() async {
    final AuthProvider auth = context.read<AuthProvider>();
    if (auth.uid == null) {
      // Fallback nếu chưa đăng nhập (không nên xảy ra vì có AuthGate)
      return const UserProfile(
        fullName: 'Khách',
        email: '',
        phone: '',
        receiveNotifications: true,
        preferredLanguage: 'vi',
        darkMode: false,
      );
    }

    final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection('users')
        .doc(auth.uid)
        .get();

    if (doc.exists && doc.data() != null) {
      final UserProfile profile = UserProfile.fromFirestore(doc.data()!);
      _profile = profile;
      return profile;
    }

    // Document chưa tồn tại (trường hợp hiếm) → trả về default
    final UserProfile defaultProfile = UserProfile(
      fullName: auth.user?.displayName ?? '',
      email: auth.user?.email ?? '',
      phone: '',
      receiveNotifications: true,
      preferredLanguage: 'vi',
      darkMode: false,
    );
    _profile = defaultProfile;
    return defaultProfile;
  }

  /// Cập nhật profile: setState để UI phản hồi ngay + ghi lên Firestore.
  Future<void> _updateProfile(UserProfile updated) async {
    final AuthProvider auth = context.read<AuthProvider>();

    // Optimistic Update: cập nhật UI trước, lưu Firestore sau
    setState(() {
      _profile = updated;
    });

    if (auth.uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.uid)
          .set(updated.toFirestore(), SetOptions(merge: true));
    }
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
          final UserProfile profile = _profile ?? snapshot.data!;

          return ListView(
            children: <Widget>[
              // ── Thông tin user đăng nhập ────────────────
              Consumer<AuthProvider>(
                builder: (BuildContext context, AuthProvider auth, _) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        (profile.fullName.isNotEmpty
                                ? profile.fullName[0]
                                : auth.user?.email?[0] ?? '?')
                            .toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      profile.fullName.isNotEmpty
                          ? profile.fullName
                          : 'Người dùng',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(auth.user?.email ?? ''),
                  );
                },
              ),
              const Divider(),

              // ── Dark Mode Toggle ──────────────────────────
              SwitchListTile(
                title: const Text('Chế độ tối'),
                value: profile.darkMode,
                onChanged: (bool value) {
                  final UserProfile updated = profile.copyWith(darkMode: value);
                  _updateProfile(updated);
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
                  final String? selected = await showModalBottomSheet<String>(
                    context: context,
                    builder: (BuildContext context) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ListTile(
                            title: const Text('Tiếng Việt'),
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
                  if (selected != null && selected != profile.preferredLanguage) {
                    final UserProfile updated =
                        profile.copyWith(preferredLanguage: selected);
                    _updateProfile(updated);
                  }
                },
              ),

              const Divider(),

              // ── Profile Link ──────────────────────────────
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Hồ sơ cá nhân'),
                subtitle: const Text('Thông tin tài khoản'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final UserProfile? updated =
                      await Navigator.of(context).pushNamed<UserProfile>(
                    ProfileScreen.routeName,
                    arguments: profile,
                  );
                  if (updated != null) {
                    _updateProfile(updated);
                  }
                },
              ),

              // ── Logout ───────────────────────────────────
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Đăng xuất',
                    style: TextStyle(color: Colors.red)),
                onTap: () async {
                  // Xác nhận trước khi đăng xuất
                  final bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Đăng xuất'),
                        content: const Text('Bạn có chắc muốn đăng xuất?'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Hủy'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Đăng xuất'),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirm == true && context.mounted) {
                    await context.read<AuthProvider>().signOut();
                    // AuthGate sẽ tự chuyển về LoginScreen
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
