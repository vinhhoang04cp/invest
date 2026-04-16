import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
    // Nếu thiếu file .env, vẫn chạy ứng dụng nhưng sẽ báo lỗi khi gọi API.
    debugPrint('Không thể tải file .env: $error');
  }
  runApp(
    TalkerWrapper(
      talker: talker,
      child: const AppBootstrap(),
    ),
  );
}

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WatchlistProvider>(
      create: (_) => WatchlistProvider(),
      child: const StockTrackerApp(),
    );
  }
}

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
        StockDetailScreen.routeName: (BuildContext context) => const StockDetailScreen(),
        StockListScreen.routeName: (BuildContext context) => const StockListScreen(),
        ProfileScreen.routeName: (BuildContext context) => const ProfileScreen(),
        WatchlistManageScreen.routeName: (BuildContext context) => const WatchlistManageScreen(),
      },
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const <Widget>[
    HomeScreen(),
    StockListScreen(),
    PortfolioScreen(),
    SettingsScreen(),
  ];

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
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: _destinations,
      ),
    );
  }
}
