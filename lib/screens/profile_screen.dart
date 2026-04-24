import 'package:flutter/material.dart';
import '../models/user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const String routeName = '/profile';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  late TextEditingController _addressController;

  late UserProfile _profile;
  bool _notifications = false;
  String? _experience;
  String? _strategy;
  DateTime? _dob;
  bool _initialized = false;

  final List<String> _experienceLevels = ['F0 (Mới bắt đầu)', 'Trung cấp', 'Chuyên nghiệp'];
  final List<String> _strategies = ['Đầu tư giá trị', 'Đầu tư tăng trưởng', 'Lướt sóng (T+)', 'Cổ tức'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final UserProfile profile = ModalRoute.of(context)!.settings.arguments as UserProfile;
    _profile = profile;

    _nameController = TextEditingController(text: profile.fullName);
    _emailController = TextEditingController(text: profile.email);
    _phoneController = TextEditingController(text: profile.phone);
    _bioController = TextEditingController(text: profile.bio ?? '');
    _addressController = TextEditingController(text: profile.address ?? '');
    _notifications = profile.receiveNotifications;
    _experience = profile.experience;
    _strategy = profile.strategy;
    _dob = profile.dob;
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) return;

    final UserProfile updated = _profile.copyWith(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      bio: _bioController.text.trim(),
      address: _addressController.text.trim(),
      receiveNotifications: _notifications,
      experience: _experience,
      strategy: _strategy,
      dob: _dob,
    );

    Navigator.of(context).pop(updated);
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dob) {
      setState(() {
        _dob = picked;
      });
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: const Text('LƯU', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Avatar ──────────────────────────────────
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _emailController.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
                
                // ── Thông tin tài khoản ────────────────────────
                _buildSectionHeader('Thông tin tài khoản'),
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên',
                            prefixIcon: Icon(Icons.person_outline),
                            border: InputBorder.none,
                          ),
                          validator: (value) => value!.isEmpty ? 'Vui lòng nhập họ tên' : null,
                        ),
                        const Divider(),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại',
                            prefixIcon: Icon(Icons.phone_outlined),
                            border: InputBorder.none,
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.cake_outlined),
                          title: const Text('Ngày sinh', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          subtitle: Text(
                            _dob == null ? 'Chưa thiết lập' : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          trailing: const Icon(Icons.calendar_today, size: 18),
                          onTap: _selectDate,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Hồ sơ đầu tư ─────────────────────────────
                _buildSectionHeader('Hồ sơ đầu tư'),
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _experience,
                          decoration: const InputDecoration(
                            labelText: 'Kinh nghiệm',
                            prefixIcon: Icon(Icons.trending_up),
                            border: InputBorder.none,
                          ),
                          items: _experienceLevels.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (val) => setState(() => _experience = val),
                        ),
                        const Divider(),
                        DropdownButtonFormField<String>(
                          value: _strategy,
                          decoration: const InputDecoration(
                            labelText: 'Chiến thuật ưu tiên',
                            prefixIcon: Icon(Icons.psychology_outlined),
                            border: InputBorder.none,
                          ),
                          items: _strategies.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (val) => setState(() => _strategy = val),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Thông tin thêm ─────────────────────────────
                _buildSectionHeader('Thông tin khác'),
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _bioController,
                          decoration: const InputDecoration(
                            labelText: 'Giới thiệu ngắn',
                            prefixIcon: Icon(Icons.edit_note),
                            border: InputBorder.none,
                          ),
                          maxLines: 3,
                        ),
                        const Divider(),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Địa chỉ',
                            prefixIcon: Icon(Icons.location_on_outlined),
                            border: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
