import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stock_detail_screen.dart';
import 'screens/stock_list_screen.dart';
import 'screens/watchlist_manage_screen.dart';
import 'services/logger_service.dart';
import 'state/auth_provider.dart';
import 'state/watchlist_provider.dart';

// =============================================================================
// ENTRY POINT — main.dart
//
// Luồng khởi động ứng dụng:
//   main()
//     └─ Firebase.initializeApp()
//     └─ TalkerWrapper (bộc logging)
//         └─ AppBootstrap (MultiProvider: AuthProvider + WatchlistProvider)
//             └─ StockTrackerApp (MaterialApp + routing)
//                 └─ AuthGate (kiểm tra đăng nhập)
//                     ├─ LoginScreen (chưa đăng nhập)
//                     └─ MainNavigationShell (đã đăng nhập)
// =============================================================================

/// Điểm khởi đầu chính (Entry point) của toàn bộ ứng dụng Flutter.
///
/// Khai báo `async` vì gọi [WidgetsFlutterBinding.ensureInitialized] —
/// bắt buộc phải gọi trước bất kỳ plugin nào hoạt động (như Firebase,
/// SharedPreferences, camera...) trên native platform.
Future<void> main() async {
  // Khởi tạo Flutter engine binding với platform native.
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase — BẮT BUỘC gọi trước khi dùng bất kỳ service Firebase nào
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    // TalkerWrapper = wrapper cho toàn bộ app để intercept và log lỗi toàn cục.
    TalkerWrapper(
      talker: talker,
      child: const AppBootstrap(),
    ),
  );
}

// =============================================================================
// AppBootstrap — Dependency Injection Layer
// =============================================================================

/// Lớp khởi động ứng dụng — nơi thiết lập Dependency Injection (DI).
///
/// Dùng [MultiProvider] để inject nhiều providers vào widget tree:
/// - [AuthProvider]: quản lý trạng thái đăng nhập/đăng ký
/// - [WatchlistProvider]: quản lý danh sách cổ phiếu theo dõi (phụ thuộc vào AuthProvider)
///
/// [ChangeNotifierProxyProvider]: tự động tạo lại WatchlistProvider
/// mỗi khi AuthProvider.uid thay đổi (đăng nhập user khác / đăng xuất).
class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        // AuthProvider: quản lý Firebase Auth state
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),
        // WatchlistProvider: phụ thuộc vào AuthProvider để lấy UID
        // ProxyProvider: khi AuthProvider thay đổi → update WatchlistProvider
        ChangeNotifierProxyProvider<AuthProvider, WatchlistProvider>(
          create: (_) => WatchlistProvider(),
          update: (_, AuthProvider auth, WatchlistProvider? previous) {
            // Nếu UID thay đổi (đăng nhập/đăng xuất) → tạo provider mới
            final String? newUid = auth.uid;
            if (previous == null || newUid != previous.uid) {
              return WatchlistProvider(uid: newUid);
            }
            return previous;
          },
        ),
      ],
      child: const StockTrackerApp(),
    );
  }
}

// =============================================================================
// StockTrackerApp — MaterialApp Root
// =============================================================================

/// Widget gốc toàn ứng dụng.
///
/// [MaterialApp] cung cấp:
/// - Theme toàn cục (Material 3 + seed color indigo)
/// - Navigator stack (điều hướng trang)
/// - Named routes map
class StockTrackerApp extends StatelessWidget {
  const StockTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Vision',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),

      routes: <String, WidgetBuilder>{
        StockDetailScreen.routeName:     (BuildContext context) => const StockDetailScreen(),
        StockListScreen.routeName:       (BuildContext context) => const StockListScreen(),
        ProfileScreen.routeName:         (BuildContext context) => const ProfileScreen(),
        WatchlistManageScreen.routeName: (BuildContext context) => const WatchlistManageScreen(),
      },

      // AuthGate: kiểm tra user đăng nhập → hiện app hoặc login screen
      home: const AuthGate(),
    );
  }
}

// =============================================================================
// AuthGate — Bộ lọc xác thực
// =============================================================================

/// Widget quyết định hiển thị LoginScreen hay MainNavigationShell
/// dựa trên trạng thái đăng nhập từ [AuthProvider].
///
/// - AuthProvider.isLoading → hiện loading spinner (đang kiểm tra auth state)
/// - AuthProvider.isAuthenticated → hiện app chính
/// - Chưa đăng nhập → hiện LoginScreen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (BuildContext context, AuthProvider auth, Widget? child) {
        // Đang kiểm tra auth state (lần đầu mở app)
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Đã đăng nhập → hiện app chính
        if (auth.isAuthenticated) {
          return const MainNavigationShell();
        }

        // Chưa đăng nhập → hiện trang login
        return const LoginScreen();
      },
    );
  }
}

// =============================================================================
// MainNavigationShell — Bottom Navigation + Tab Manager
// =============================================================================

/// Shell điều hướng chính: thanh NavigationBar dưới cùng điều khiển 4 tab.
///
/// [IndexedStack] giữ nguyên trạng thái tất cả widget con dù chúng bị ẩn.
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  // Chỉ số tab hiện tại (0=Home, 1=Market, 2=Portfolio, 3=Settings)
  int _currentIndex = 0;

  // Theo dõi tab nào đã từng được mở (để giữ state sau lần đầu)
  final Set<int> _initializedTabs = <int>{0}; // Tab 0 (Home) luôn được tạo

  // Danh sách widget builder cho từng tab — chỉ gọi khi tab được chọn lần đầu.
  // Lazy loading: tránh tạo tất cả 4 tab cùng lúc → giảm RAM đáng kể.
  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const StockListScreen();
      case 2:
        return const PortfolioScreen();
      case 3:
        return const SettingsScreen();
      default:
        return const HomeScreen();
    }
  }

  // Cấu hình hiển thị từng destination trong NavigationBar.
  final List<NavigationDestination> _destinations = const <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Trang chủ',
    ),
    NavigationDestination(
      icon: Icon(Icons.search),
      selectedIcon: Icon(Icons.search),
      label: 'Thị trường',
    ),
    NavigationDestination(
      icon: Icon(Icons.pie_chart_outline),
      selectedIcon: Icon(Icons.pie_chart),
      label: 'Danh mục',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Cài đặt',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Lazy IndexedStack: chỉ build tab khi nó đã từng được chọn.
      // Tab chưa mở → hiển thị SizedBox.shrink() (gần như 0 bộ nhớ).
      // Tab đã mở → giữ nguyên widget (không rebuild khi chuyển tab khác).
      body: IndexedStack(
        index: _currentIndex,
        children: List<Widget>.generate(4, (int index) {
          if (_initializedTabs.contains(index)) {
            return _buildTab(index);
          }
          return const SizedBox.shrink();
        }),
      ),

      bottomNavigationBar: NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _initializedTabs.add(index); // Đánh dấu tab đã được mở
            _currentIndex = index;
          });
        },
        destinations: _destinations,
      ),
    );
  }
}
