import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'screens/home_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stock_detail_screen.dart';
import 'screens/stock_list_screen.dart';
import 'screens/watchlist_manage_screen.dart';
import 'services/logger_service.dart';
import 'state/watchlist_provider.dart';

// =============================================================================
// ENTRY POINT — main.dart
//
// Luồng khởi động ứng dụng:
//   main()
//     └─ TalkerWrapper (bộc logging)
//         └─ AppBootstrap (tạo ChangeNotifierProvider)
//             └─ StockTrackerApp (MaterialApp + routing)
//                 └─ MainNavigationShell (bottom nav + 4 tabs)
// =============================================================================

/// Điểm khởi đầu chính (Entry point) của toàn bộ ứng dụng Flutter.
///
/// Khai báo `async` vì gọi [WidgetsFlutterBinding.ensureInitialized] —
/// bắt buộc phải gọi trước bất kỳ plugin nào hoạt động (như SharedPreferences,
/// camera, file I/O...) trên native platform.
///
/// [TalkerWrapper]: Widget bọc ngoài cùng cung cấp khả năng mở màn hình
/// log dạng shake-to-open hoặc gõ gesture. Nhận instance [talker] từ
/// [logger_service.dart].
Future<void> main() async {
  // Khởi tạo Flutter engine binding với platform native.
  // Nếu không gọi dòng này trước khi dùng plugin → crash.
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    // TalkerWrapper = wrapper cho toàn bộ app để intercept và log lỗi toàn cục.
    // `talker` là global instance được khai báo trong logger_service.dart
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
/// Dùng [ChangeNotifierProvider] để inject [WatchlistProvider] vào toàn bộ
/// widget tree bên dưới. Bất kỳ widget nào gọi `Provider.of<WatchlistProvider>`
/// hoặc `context.watch<WatchlistProvider>()` đều nhận được cùng 1 instance.
///
/// **Tại sao StatelessWidget?**
/// AppBootstrap chỉ thiết lập cấu trúc, không có state nội bộ cần quản lý.
class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WatchlistProvider>(
      // create: factory function — chỉ chạy 1 lần khi provider được tạo.
      // `_` là BuildContext (không dùng nên đặt tên gạch dưới).
      create: (_) => WatchlistProvider(),
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
/// - Localization (nếu cài)
///
/// **Named Routes vs onGenerateRoute:**
/// Named routes đơn giản, phù hợp với app nhỏ. Nhược điểm là không type-safe
/// với arguments. App này giải quyết bằng cách dùng wrapper class như
/// [StockDetailArgs] cho arguments phức tạp.
class StockTrackerApp extends StatelessWidget {
  const StockTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Vision',

      // useMaterial3: true — bật thiết kế Material You (Google 2021+)
      // Dùng ColorScheme.fromSeed để tạo bảng màu hài hòa từ 1 màu gốc
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),

      // routes map: ánh xạ String tên route → WidgetBuilder factory
      // Mỗi Screen tự khai báo static const routeName để tập trung route tại 1 chỗ.
      // Dùng: Navigator.of(context).pushNamed(StockDetailScreen.routeName, arguments: ...)
      routes: <String, WidgetBuilder>{
        StockDetailScreen.routeName:     (BuildContext context) => const StockDetailScreen(),
        StockListScreen.routeName:       (BuildContext context) => const StockListScreen(),
        ProfileScreen.routeName:         (BuildContext context) => const ProfileScreen(),
        WatchlistManageScreen.routeName: (BuildContext context) => const WatchlistManageScreen(),
      },

      // home: trang mặc định khi không có named route nào được push
      home: const MainNavigationShell(),
    );
  }
}

// =============================================================================
// MainNavigationShell — Bottom Navigation + Tab Manager
// =============================================================================

/// Shell điều hướng chính: thanh NavigationBar dưới cùng điều khiển 4 tab.
///
/// **Tại sao StatefulWidget?**
/// Cần lưu `_currentIndex` — chỉ số tab đang hiển thị. State này phải
/// tồn tại trong suốt lifetime của NavigationShell.
///
/// **Tại sao IndexedStack thay vì Navigator/switch-case?**
/// [IndexedStack] giữ nguyên trạng thái tất cả widget con dù chúng bị ẩn.
/// Ví dụ: HomeScreen đang scroll giữa chừng → chuyển sang tab khác → trở lại
/// → vị trí scroll vẫn được giữ nguyên (không rebuild lại từ đầu).
///
/// switch-case sẽ destroy và tạo lại widget mỗi lần chuyển tab.
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  // Chỉ số tab hiện tại (0=Home, 1=Market, 2=Portfolio, 3=Settings)
  int _currentIndex = 0;

  // Danh sách các widget tương ứng với từng tab.
  // Đây là const list — được tạo 1 lần, không rebuild.
  final List<Widget> _tabs = const <Widget>[
    HomeScreen(),        // Tab 0: Trang chủ + Watchlist
    StockListScreen(),   // Tab 1: Thị trường + Tìm kiếm
    PortfolioScreen(),   // Tab 2: Danh mục đầu tư
    SettingsScreen(),    // Tab 3: Cài đặt + Hồ sơ
  ];

  // Cấu hình hiển thị từng destination trong NavigationBar.
  // NavigationDestination cần icon thường (unselected) và selectedIcon.
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
      // IndexedStack: chỉ hiện 1 child tại index, các child còn lại ẩn nhưng vẫn tồn tại.
      // children phải khớp số lượng và thứ tự với _destinations.
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),

      // NavigationBar (Material 3): thay thế BottomNavigationBar cũ.
      bottomNavigationBar: NavigationBar(
        // alwaysShow: luôn hiện label dù đang chọn hay không.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          // setState: trigger rebuild để IndexedStack cập nhật `index`.
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: _destinations,
      ),
    );
  }
}
