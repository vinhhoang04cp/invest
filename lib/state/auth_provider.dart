import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// =============================================================================
// AuthProvider — Quản lý trạng thái xác thực Firebase
// =============================================================================
//
// PATTERN: ChangeNotifier + Provider
//
// Lắng nghe authStateChanges() stream từ FirebaseAuth:
//   - User đăng nhập  → _user != null → isAuthenticated = true
//   - User đăng xuất  → _user = null  → isAuthenticated = false
//
// Khi auth state thay đổi, gọi notifyListeners() → tất cả widget listening rebuild.
//
// FIRESTORE USER DOCUMENT:
//   Mỗi user mới đăng ký sẽ được tạo 1 document trong collection "users"
//   với document ID = Firebase Auth UID.
// =============================================================================

/// Provider quản lý xác thực người dùng (đăng nhập, đăng ký, đăng xuất).
class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    // Lắng nghe stream auth state changes từ Firebase
    // Mỗi khi user đăng nhập/đăng xuất → callback được gọi
    _authSubscription = FirebaseAuth.instance
        .authStateChanges()
        .listen(_onAuthStateChanged);
  }

  // ---------------------------------------------------------------------------
  // Private State
  // ---------------------------------------------------------------------------

  User? _user;                    // Firebase User object (null = chưa đăng nhập)
  bool _isLoading = true;         // true khi đang kiểm tra auth state lần đầu
  String? _errorMessage;          // Thông báo lỗi gần nhất (hiển thị trên UI)
  StreamSubscription<User?>? _authSubscription;

  // ---------------------------------------------------------------------------
  // Public Getters
  // ---------------------------------------------------------------------------

  /// Firebase User hiện tại (null nếu chưa đăng nhập).
  User? get user => _user;

  /// UID của user hiện tại (null nếu chưa đăng nhập).
  String? get uid => _user?.uid;

  /// true khi user đã đăng nhập.
  bool get isAuthenticated => _user != null;

  /// true khi đang xử lý (kiểm tra auth / đang đăng nhập / đăng ký).
  bool get isLoading => _isLoading;

  /// Thông báo lỗi gần nhất (null = không có lỗi).
  String? get errorMessage => _errorMessage;

  // ---------------------------------------------------------------------------
  // Auth State Listener
  // ---------------------------------------------------------------------------

  /// Callback khi auth state thay đổi (đăng nhập / đăng xuất).
  void _onAuthStateChanged(User? user) {
    _user = user;
    _isLoading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Public Actions
  // ---------------------------------------------------------------------------

  /// Xóa thông báo lỗi (gọi khi user bắt đầu nhập lại form).
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Đăng nhập bằng Email + Password.
  ///
  /// Trả về `true` nếu thành công, `false` nếu thất bại.
  /// Lỗi được lưu vào [errorMessage] để UI hiển thị.
  Future<bool> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // authStateChanges stream sẽ tự cập nhật _user → notifyListeners
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Đã xảy ra lỗi không xác định. Vui lòng thử lại.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Đăng ký tài khoản mới bằng Email + Password.
  ///
  /// Sau khi tạo tài khoản Firebase Auth thành công:
  /// 1. Tạo document user trên Firestore (users/{uid})
  /// 2. authStateChanges tự cập nhật → user đã đăng nhập
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Tạo tài khoản trên Firebase Auth
      final UserCredential credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Cập nhật displayName trên Firebase Auth profile
      await credential.user?.updateDisplayName(fullName.trim());

      // Tạo document trên Firestore cho user mới
      if (credential.user != null) {
        await _createUserDocument(
          uid: credential.user!.uid,
          email: email.trim(),
          fullName: fullName.trim(),
        );
      }

      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Đã xảy ra lỗi không xác định. Vui lòng thử lại.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Đăng xuất.
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    // authStateChanges stream sẽ tự cập nhật _user = null → notifyListeners
  }

  // ---------------------------------------------------------------------------
  // Firestore Helpers
  // ---------------------------------------------------------------------------

  /// Tạo document user mới trên Firestore khi đăng ký.
  ///
  /// Document ID = UID từ Firebase Auth.
  /// watchlist khởi tạo rỗng → user tự thêm sau.
  Future<void> _createUserDocument({
    required String uid,
    required String email,
    required String fullName,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set(<String, dynamic>{
      'email': email,
      'fullName': fullName,
      'phone': '',
      'preferredLanguage': 'vi',
      'receiveNotifications': true,
      'darkMode': false,
      'watchlist': <String>[], // Danh sách theo dõi rỗng ban đầu
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // Error Mapping
  // ---------------------------------------------------------------------------

  /// Chuyển mã lỗi Firebase Auth sang thông báo tiếng Việt thân thiện.
  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này.';
      case 'wrong-password':
        return 'Mật khẩu không chính xác.';
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không chính xác.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng.';
      case 'weak-password':
        return 'Mật khẩu quá yếu (tối thiểu 6 ký tự).';
      case 'invalid-email':
        return 'Định dạng email không hợp lệ.';
      case 'too-many-requests':
        return 'Quá nhiều lần thử. Vui lòng thử lại sau.';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng. Vui lòng kiểm tra internet.';
      default:
        return 'Lỗi xác thực: $code';
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
