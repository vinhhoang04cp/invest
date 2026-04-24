# 📈 Stock Vision - Ứng dụng Theo dõi & Quản lý Chứng khoán Việt Nam

![Stock Vision Banner](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/firebase-ffca28?style=for-the-badge&logo=firebase&logoColor=black)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)

**Stock Vision** là một ứng dụng di động đa nền tảng được phát triển bằng Flutter, mang đến cho nhà đầu tư trải nghiệm theo dõi thị trường chứng khoán Việt Nam một cách mượt mà và trực quan nhất theo thời gian thực. Ứng dụng tích hợp các tính năng theo dõi biến động giá, quản lý danh mục đầu tư (Portfolio), cập nhật tin tức thị trường và phân tích kỹ thuật thông qua biểu đồ sinh động.

Dự án tận dụng luồng dữ liệu thời gian thực từ **Yahoo Finance API** kết hợp với kiến trúc backend linh hoạt của **Firebase** để lưu trữ và đồng bộ dữ liệu người dùng trên Cloud.

---

## ✨ Tính năng nổi bật (Features)

*   **📊 Dữ liệu thị trường Real-time:** Cập nhật giá cổ phiếu, chỉ số thị trường (VN-INDEX, HNX-INDEX, UPCOM) và tin tức tài chính nhanh chóng.
*   **📈 Biểu đồ trực quan:** Tích hợp biểu đồ xu hướng (Mini Sparkline) và biểu đồ chi tiết sử dụng `fl_chart` với độ phản hồi cao.
*   **⭐ Danh sách theo dõi (Watchlist):** Dễ dàng thêm, xóa và quản lý danh sách các mã cổ phiếu quan tâm. Dữ liệu được đồng bộ hóa với tài khoản thông qua Firebase.
*   **💼 Quản lý danh mục (Portfolio):** Theo dõi lãi/lỗ của các khoản đầu tư một cách tự động, tính toán giá trị danh mục dựa trên dữ liệu giá Real-time.
*   **👤 Quản lý hồ sơ (Profile Management):** Tùy chỉnh thông tin cá nhân và khẩu vị rủi ro đầu tư.
*   **🔐 Xác thực bảo mật:** Đăng ký, đăng nhập an toàn bằng Email/Password thông qua Firebase Authentication. Cấu hình tự động khởi tạo dữ liệu mặc định trên Cloud Firestore.

---

## 🚀 Tối ưu hóa Hiệu năng (Performance Optimizations)

Stock Vision được thiết kế để xử lý khối lượng dữ liệu lớn một cách hiệu quả, đặc biệt trong việc giao tiếp với Yahoo Finance API:

1.  **Parallel Chunk Fetching:** Tải dữ liệu cho Watchlist và Portfolio song song theo từng nhóm (chunk) 15-20 mã cổ phiếu bằng `Future.wait`, giảm thiểu đáng kể độ trễ mạng so với cách gọi tuần tự.
2.  **Smart Quote Caching (TTL-based):** Triển khai cơ chế cache dữ liệu cổ phiếu trong bộ nhớ với thời gian sống (Time-To-Live - TTL) 60 giây. Ngăn chặn việc gọi API dư thừa, giúp trải nghiệm cuộn màn hình mượt mà tuyệt đối.
3.  **Pull-to-Refresh Invalidation:** Người dùng có thể chủ động vuốt để làm mới (Pull-to-Refresh) màn hình, cơ chế này sẽ tự động xóa bộ nhớ đệm (invalidateQuoteCache) và ép tải dữ liệu mới nhất.
4.  **Batch Chart Processing:** Gộp nhóm các request biểu đồ (tăng kích thước batch lên 10 mã/lần) và xử lý song song để hiển thị Sparkline nhanh chóng.
5.  **Robust Error Handling & Timeout:** Tích hợp HTTP timeout 10 giây cho mọi request, kết hợp cơ chế **Circuit Breaker** thông minh tự động chuyển đổi giữa các endpoint của Yahoo Finance (từ `v7/quote` sang `v8/chart`) khi gặp sự cố, đảm bảo ứng dụng không bao giờ bị treo.
6.  **O(1) Symbol Lookup:** Chuyển đổi mã cổ phiếu nội địa sang định dạng API bằng Dictionary Traversal tốc độ cao (ví dụ nhận diện chính xác hậu tố `.HN` cho HNX và `.VN` cho HOSE).

---

## 🛠 Cấu trúc Dự án (Architecture & Folder Structure)

Dự án áp dụng mô hình kiến trúc phân lớp (Layered Architecture) rõ ràng, đảm bảo tính dễ đọc, khả năng mở rộng và dễ dàng bảo trì.

```text
lib/
 ├── main.dart                  # Entry point, khởi tạo Firebase, cấu hình Theme & MultiProvider
 ├── firebase_options.dart      # File cấu hình kết nối Firebase
 │
 ├── constants/                 # Chứa cấu hình tĩnh (Themes, API Constants, Default Symbols)
 │    └── stock_symbols.dart    # Danh sách các mã cổ phiếu VN mặc định & Lookup logic
 │
 ├── models/                    # Data Layer - Các lớp mô hình hoá (Data Classes)
 │    ├── market_index.dart     # Chỉ số thị trường (VN-INDEX, HNX...)
 │    ├── market_news.dart      # Bản tin tài chính
 │    ├── portfolio.dart        # Models danh mục đầu tư & giao dịch (Transaction)
 │    ├── stock.dart            # Model cổ phiếu chi tiết (Immutable classes)
 │    ├── stock_symbol_model.dart 
 │    └── user.dart             # Model thông tin hồ sơ (Profile) người dùng
 │
 ├── screens/                   # Presentation Layer - Giao diện từng trang
 │    ├── auth/                 # Nhóm màn hình Xác thực (Login, Register)
 │    ├── home_screen.dart      # Trang chủ (Overview, News, Market Indices)
 │    ├── portfolio_screen.dart # Trang Danh mục đầu tư & Quản lý giao dịch
 │    ├── profile_screen.dart   # Trang Cập nhật hồ sơ cá nhân
 │    ├── settings_screen.dart  # Trang Cài đặt ứng dụng
 │    ├── stock_detail_screen.dart # Trang Phân tích chi tiết mã cổ phiếu
 │    ├── stock_list_screen.dart   # Màn hình Tìm kiếm chứng khoán
 │    └── watchlist_manage_screen.dart # Quản lý danh mục theo dõi
 │
 ├── services/                  # Business Logic Layer - Giao tiếp với External APIs & DB
 │    ├── logger_service.dart   # Service quản lý log trung tâm (Talker)
 │    └── yahoo_finance_service.dart # Core logic kết nối Yahoo Finance (Fetch, Cache, Batch)
 │
 ├── state/                     # State Management Layer
 │    ├── auth_provider.dart    # Xử lý Logic Login/Logout & Firestore Sync
 │    ├── portfolio_provider.dart # Trạng thái danh mục đầu tư
 │    └── watchlist_provider.dart # Trạng thái danh mục theo dõi
 │
 ├── utils/                     # Utility functions (Hàm tiện ích)
 │    └── debouncer.dart        # Delay execution (tối ưu thanh tìm kiếm)
 │
 └── widgets/                   # Reusable Components (Thành phần UI tái sử dụng)
      ├── mini_sparkline.dart   # Biểu đồ xu hướng rút gọn
      ├── section_header.dart   # Header phân mục UI
      └── stock_line_chart.dart # Biểu đồ diện rộng từ fl_chart
```

---

## 💻 Công nghệ sử dụng (Tech Stack)

Ứng dụng được xây dựng trên nền tảng các công nghệ và thư viện hàng đầu:

*   **Core Framework**:
    *   [Flutter](https://flutter.dev/) (SDK `^3.11.4`) & Ngôn ngữ lập trình **Dart**.
*   **Backend & Cloud Database**:
    *   **Firebase Core** & **Firebase Authentication**: Định danh và bảo mật tài khoản.
    *   **Cloud Firestore**: Cơ sở dữ liệu NoSQL phân tương để lưu thông tin tài khoản, danh mục đầu tư và watchlist.
*   **State Management (Quản lý trạng thái)**:
    *   [`provider`](https://pub.dev/packages/provider): Xử lý dependency injection và quản lý state tập trung.
*   **Networking & Data Parsing**:
    *   [`http`](https://pub.dev/packages/http): Thư viện xử lý HTTP REST requests.
*   **UI Components & Charting**:
    *   [`fl_chart`](https://pub.dev/packages/fl_chart): Hệ thống vẽ biểu đồ đường (Line chart) mượt mà và đa tùy biến.
    *   [`cupertino_icons`](https://pub.dev/packages/cupertino_icons): Bộ icon chuẩn của Apple.
*   **Utility & Debugging**:
    *   [`shared_preferences`](https://pub.dev/packages/shared_preferences): Local Storage cho cấu hình tạm thời.
    *   [`talker_flutter`](https://pub.dev/packages/talker_flutter): Advanced logging framework hỗ trợ bắt lỗi, track HTTP request dễ dàng trong quá trình debug.
    *   [`url_launcher`](https://pub.dev/packages/url_launcher): Xử lý deep link và mở Web browser an toàn.

---

## ⚙️ Hướng dẫn cài đặt & Khởi chạy (Installation & Setup)

1. **Clone dự án về máy:**
   ```bash
   git clone <đường_dẫn_git_của_bạn>
   cd chungkhoan
   ```

2. **Cài đặt các gói phụ thuộc (Dependencies):**
   ```bash
   flutter pub get
   ```

3. **Cấu hình biến môi trường và Firebase:**
   Dự án sử dụng Firebase. API Key hiện đã được gỡ bỏ khỏi mã nguồn (`firebase_options.dart`) vì lý do bảo mật. Để chạy dự án, bạn cần tự tạo một dự án Firebase và cấu hình lại.
   * Cài đặt [Firebase CLI](https://firebase.google.com/docs/cli).
   * Chạy công cụ cấu hình:
     ```bash
     flutterfire configure
     ```
   * Hoặc truyền API key thông qua **Dart Define** khi khởi chạy nếu bạn đã thiết lập CI/CD.

4. **Khởi chạy ứng dụng:**
   ```bash
   flutter run
   ```
   *Lưu ý: Nếu gặp cảnh báo linter về các hàm bị "deprecated" (như `withOpacity`), ứng dụng vẫn hoạt động bình thường, và sẽ được nâng cấp lên `.withValues()` trong các phiên bản tối ưu UI tiếp theo.*

---

## 🔮 Roadmap Phát triển tiếp theo
* [ ] Kiểm thử tự động (Unit Test) chuyên sâu cho module Cache và YahooFinanceService.
* [ ] Nâng cấp UI để loại bỏ toàn bộ các phương thức bị deprecated theo chuẩn Material 3 mới nhất.
* [ ] Thêm tính năng Cảnh báo giá (Price Alerts) qua Push Notifications.
* [ ] Hỗ trợ đa ngôn ngữ (Localization) cho tiếng Anh và tiếng Việt.

