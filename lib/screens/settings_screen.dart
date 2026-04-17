import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/yahoo_finance_service.dart';
import 'profile_screen.dart';

/// Màn hình Cài đặt hệ thống.
/// Tập trung quản lý cấu hình giao diện Dark Mode, đổi Ngôn ngữ hoặc mở trang sửa Hồ sơ cá nhân.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final YahooFinanceService _apiService = YahooFinanceService.instance;
  late Future<UserProfile> _profileFuture;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<UserProfile> _loadProfile() async {
    final UserProfile profile = await _apiService.fetchUserProfile();
    _profile = profile;
    return profile;
  }

  Future<void> _updateProfile(UserProfile updated) async {
    setState(() {
      _profile = updated;
    });
    await _apiService.updateUserProfile(updated);
  }

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
              SwitchListTile(
                title: const Text('Chế độ tối'),
                value: profile.darkMode,
                onChanged: (bool value) {
                  final UserProfile updated = profile.copyWith(darkMode: value);
                  _updateProfile(updated);
                },
              ),
              SwitchListTile(
                title: const Text('Nhận thông báo'),
                value: profile.receiveNotifications,
                onChanged: (bool value) {
                  final UserProfile updated = profile.copyWith(receiveNotifications: value);
                  _updateProfile(updated);
                },
              ),
              ListTile(
                title: const Text('Ngôn ngữ'),
                subtitle: Text(profile.preferredLanguage == 'vi' ? 'Tiếng Việt' : 'English'),
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
                    final UserProfile updated = profile.copyWith(preferredLanguage: selected);
                    _updateProfile(updated);
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Hồ sơ cá nhân'),
                subtitle: const Text('Thông tin tài khoản, đổi mật khẩu'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final UserProfile? updated = await Navigator.of(context).pushNamed<UserProfile>(
                    ProfileScreen.routeName,
                    arguments: profile,
                  );
                  if (updated != null) {
                    _updateProfile(updated);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Đăng xuất'),
                onTap: () {
                  // TODO: Xử lý đăng xuất.
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
