# Stock Vision - Ứng dụng Theo dõi Chứng khoán Việt Nam

## 1. Giới thiệu dự án
**Stock Vision** là một ứng dụng di động đa nền tảng được phát triển bằng Flutter, cho phép người dùng theo dõi diễn biến thị trường chứng khoán Việt Nam theo thời gian thực. Ứng dụng cung cấp các công cụ cập nhật biến động giá cổ phiếu, quản lý danh mục đầu tư (Portfolio), danh sách theo dõi (Watchlist) và xem các biểu đồ phân tích kỹ thuật.
Dự án sử dụng dữ liệu trực tiếp từ **Yahoo Finance API** kết hợp với **Firebase** để xác thực người dùng và lưu trữ dữ liệu cá nhân hóa trên cloud.

## 2. Những công việc đã thực hiện

Trong quá trình phát triển dự án, các tính năng và module chính sau đây đã được hoàn thiện:

*   **Xây dựng Giao diện người dùng (UI/UX):**
    *   Phát triển hệ thống các màn hình hoàn chỉnh: Home (Tổng quan), Stock Detail (Chi tiết cổ phiếu với biểu đồ), Watchlist (Danh sách theo dõi), Portfolio (Danh mục đầu tư), Profile/Settings và các màn hình xác thực (Login/Register).
    *   Tạo các Widgets có thể tái sử dụng cao như `MiniSparkline` để vẽ nhanh xu hướng giá, `StockLineChart` sử dụng `fl_chart` để hiển thị biểu đồ chi tiết.
*   **Tích hợp Dữ liệu Thời gian thực (Yahoo Finance API):**
    *   Viết service xử lý lấy thông tin chứng khoán (Quote, Chart, News).
    *   Xây dựng cơ chế tự động giả lập Web Session để lấy Cookies và Crumbs từ Yahoo, đảm bảo việc gọi API không bị gián đoạn hay bị chặn.
*   **Hệ thống Xác thực & Lưu trữ (Firebase Integration):**
    *   Tích hợp **Firebase Authentication** cho phép người dùng đăng ký và đăng nhập bảo mật bằng Email/Mật khẩu.
    *   Tích hợp **Cloud Firestore** để khởi tạo document chứa thông tin người dùng ngay khi đăng ký thành công (Lưu trữ Cài đặt cá nhân, Watchlist,... trên Cloud).
*   **Quản lý Trạng thái (State Management):**
    *   Thiết lập luồng dữ liệu một chiều sử dụng `Provider` (`AuthProvider` cho xác thực, `WatchlistProvider` cho quản lý danh mục mã quan tâm).
*   **Tối ưu hoá & Tiện ích:**
    *   Sử dụng `shared_preferences` để lưu tạm các cấu hình cục bộ.
    *   Tích hợp hệ thống ghi log chuyên nghiệp với `talker_flutter` giúp bắt lỗi dữ liệu dễ dàng trong quá trình phát triển.
    *   Tạo Helper classes (ví dụ: `Debouncer` để tối ưu thanh tìm kiếm mã cổ phiếu).

## 3. Cấu trúc Project (Folder Structure)

Dự án được tổ chức theo mô hình phân lớp rõ ràng bên trong thư mục `lib/` nhằm tối ưu hóa việc bảo trì và mở rộng code:

```text
lib/
 ├── main.dart                  # Entry point, khởi tạo Firebase, cấu hình Theme & MultiProvider
 ├── firebase_options.dart      # File cấu hình kết nối Firebase (tạo tự động bằng FlutterFire CLI)
 │
 ├── constants/                 # Chứa cấu hình tĩnh
 │    └── stock_symbols.dart    # Danh sách các mã cổ phiếu VN mặc định
 │
 ├── models/                    # Data Layer - Các lớp mô hình hoá JSON data
 │    ├── market_index.dart     # Model chỉ số thị trường (VN-INDEX, HNX...)
 │    ├── market_news.dart      # Model bản tin tài chính
 │    ├── portfolio.dart        # Model danh mục đầu tư
 │    ├── stock.dart            # Model đối tượng cổ phiếu chi tiết
 │    ├── stock_symbol_model.dart
 │    └── user.dart             # Model thông tin người dùng ứng dụng
 │
 ├── screens/                   # Presentation Layer - Giao diện từng trang
 │    ├── auth/                 # Nhóm màn hình Xác thực
 │    │    ├── login_screen.dart
 │    │    └── register_screen.dart
 │    ├── home_screen.dart      # Trang chủ (Overview/News)
 │    ├── portfolio_screen.dart # Trang Danh mục đầu tư
 │    ├── profile_screen.dart   # Trang Thông tin cá nhân
 │    ├── settings_screen.dart  # Trang Cài đặt ứng dụng
 │    ├── stock_detail_screen.dart # Trang Chi tiết (Biểu đồ lớn)
 │    ├── stock_list_screen.dart   # Danh sách và Tìm kiếm chứng khoán
 │    └── watchlist_manage_screen.dart # Quản lý danh mục theo dõi
 │
 ├── services/                  # Business Logic Layer - Giao tiếp với External API
 │    ├── logger_service.dart   # Service quản lý log (Talker)
 │    └── yahoo_finance_service.dart # Service gọi API Yahoo (Fetch Cookie, Crumb, Quote)
 │
 ├── state/                     # State Management - Quản lý trạng thái
 │    ├── auth_provider.dart    # Xử lý Logic Login/Logout và kết nối Firestore users
 │    └── watchlist_provider.dart # Theo dõi và đồng bộ Watchlist
 │
 ├── utils/                     # Utility functions (Hàm tiện ích)
 │    └── debouncer.dart        # Chống gọi hàm liên tục (tốt cho search)
 │
 └── widgets/                   # Reusable Components (Thành phần UI dùng chung)
      ├── mini_sparkline.dart   # Biểu đồ xu hướng nhỏ gọn
      ├── section_header.dart   # Header dùng chung
      └── stock_line_chart.dart # Biểu đồ lớn từ thư viện fl_chart
```

## 4. Các Công nghệ sử dụng (Tech Stack)

Dự án áp dụng các framework, thư viện và service hiện đại:

*   **Core Framework**:
    *   [Flutter](https://flutter.dev/) (Phiên bản SDK `^3.11.4`) - Xây dựng giao diện ứng dụng.
    *   Ngôn ngữ lập trình: **Dart**.
*   **Backend & BaaS (Backend as a Service)**:
    *   **Firebase Core** (`firebase_core`): Nền tảng kết nối.
    *   **Firebase Authentication** (`firebase_auth`): Quản lý định danh người dùng.
    *   **Cloud Firestore** (`cloud_firestore`): NoSQL Database lưu trữ thông tin User và Watchlist trên đám mây.
*   **Quản lý Trạng thái (State Management)**:
    *   [`provider`](https://pub.dev/packages/provider): Giải pháp state management chính, lắng nghe (listen) và cập nhật UI hiệu quả.
*   **Giao tiếp Mạng & API (Networking)**:
    *   [`http`](https://pub.dev/packages/http): Thư viện gửi REST requests lấy dữ liệu từ Yahoo Finance.
*   **Giao diện & Biểu đồ (UI & Charts)**:
    *   [`fl_chart`](https://pub.dev/packages/fl_chart): Thư viện vẽ biểu đồ đường (Line chart) mạnh mẽ để hiển thị biến động giá.
    *   [`cupertino_icons`](https://pub.dev/packages/cupertino_icons): Bộ icon chuẩn của Apple.
*   **Tiện ích & Lưu trữ cục bộ (Utils & Local Storage)**:
    *   [`shared_preferences`](https://pub.dev/packages/shared_preferences): Lưu trữ cục bộ dữ liệu nhẹ (local cache).
    *   [`talker_flutter`](https://pub.dev/packages/talker_flutter): Công cụ logging và debug mạnh mẽ, giúp theo dõi lỗi HTTP requests dễ dàng.
    *   [`url_launcher`](https://pub.dev/packages/url_launcher): Mở các liên kết bên ngoài (như bài viết tin tức) bằng trình duyệt web của thiết bị.

## 5. Hướng dẫn cài đặt & Chạy ứng dụng

1. **Clone dự án**:
   ```bash
   git clone <đường_dẫn_git_của_bạn>
   cd chungkhoan
   ```
2. **Cài đặt các gói phụ thuộc (Dependencies)**:
   ```bash
   flutter pub get
   ```
3. **Cấu hình Firebase (Nếu cần thiết)**:
   *   Đảm bảo bạn đã có các file `.firebaserc`, `firebase.json` và đã cấu hình Firebase trên máy hoặc liên kết bằng CLI `flutterfire configure`.
4. **Chạy ứng dụng**:
   ```bash
   flutter run
   ```
