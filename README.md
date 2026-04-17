# Stock Vision - Ứng dụng Theo dõi Chứng khoán Việt Nam (Flutter)

## 1. Giới thiệu dự án
**Stock Vision** là một ứng dụng di động được phát triển bằng Flutter, cho phép người dùng theo dõi biến động thị trường chứng khoán Việt Nam theo thời gian thực sử dụng API của **Yahoo Finance**. Ứng dụng cung cấp các công cụ quản lý danh mục đầu tư (Portfolio), danh sách theo dõi (Watchlist) và cập nhật tin tức tài chính.

- **Nhà phát triển**: 1 người (Cá nhân)
- **Mục tiêu**: Xây dựng một ứng dụng theo dõi tài chính chuyên nghiệp, không phụ thuộc vào các API mất phí, có hiệu năng cao và trải nghiệm người dùng tối ưu.

## 2. Tính năng chính
- **Tổng quan thị trường**: Theo dõi các chỉ số và biến động cổ phiếu theo thời gian thực mạnh mẽ thông qua Yahoo Finance API.
- **Quản lý Watchlist**: Tùy chỉnh danh sách các mã cổ phiếu quan tâm (Thêm/Xóa/Sắp xếp).
- **Chi tiết cổ phiếu**: Biểu đồ giá trực quan, các thông số kỹ thuật và biểu đồ đường xu hướng.
- **Danh mục đầu tư (Portfolio)**: Quản lý tài sản, tính toán lãi/lỗ dựa trên giá thị trường hiện tại.
- **Dữ liệu mượt mà**: Tự động quản lý Cookies & Crumbs của Yahoo Finance để lấy thông tin chính xác, nhanh chóng.

## 3. Cấu trúc thư mục chi tiết (Folder Structure)

Dự án được tổ chức theo kiến trúc phân lớp rõ ràng để dễ dàng bảo trì và mở rộng:

```text
lib/
 ├── main.dart                  # Điểm khởi đầu của ứng dụng, cấu hình Theme và Router.
 ├── constants/                 # Chứa các giá trị cố định, cấu hình tĩnh.
 │    └── stock_symbols.dart    # Định nghĩa danh sách các mã chứng khoán mặc định và mapping.
 ├── models/                    # Lớp dữ liệu (Data Layer) - Định nghĩa các đối tượng.
 │    ├── stock.dart            # Thông tin về một mã cổ phiếu (giá, thay đổi, ...).
 │    ├── stock_symbol_model.dart # Cấu trúc dữ liệu cho danh mục mã.
 │    ├── market_index.dart     # Dữ liệu các chỉ số thị trường.
 │    ├── market_news.dart      # Cấu trúc dữ liệu bài báo, tin tức.
 │    ├── portfolio.dart        # Dữ liệu tài sản trong danh mục đầu tư.
 │    └── user.dart             # Thông tin cá nhân người dùng.
 ├── screens/                   # Giao diện người dùng (Presentation Layer) - Từng màn hình cụ thể.
 │    ├── home_screen.dart      # Màn hình chính (Dashboard).
 │    ├── stock_list_screen.dart # Danh sách thị trường và tìm kiếm mã.
 │    ├── stock_detail_screen.dart # Chi tiết về một mã chứng khoán cụ thể.
 │    ├── portfolio_screen.dart  # Quản lý tài sản cá nhân.
 │    └── ...                   # Các màn hình chức năng khác.
 ├── services/                  # Xử lý Logic và Dữ liệu ngoại vi (Service Layer).
 │    ├── yahoo_finance_service.dart # Giao tiếp với Yahoo Finance, lấy lịch sử giá, cookie/crumbs...
 │    └── logger_service.dart   # Dịch vụ ghi log cho hệ thống (Talker).
 ├── state/                     # Quản lý trạng thái ứng dụng (State Management).
 │    └── watchlist_provider.dart # Quản lý và đồng bộ Watchlist toàn app.
 ├── widgets/                   # Các thành phần giao diện dùng chung (Re-usable Widgets).
 │    ├── mini_sparkline.dart   # Biểu đồ đường nhỏ hiển thị xu hướng giá.
 │    └── section_header.dart   # Tiêu đề cho các phần trong trang.
 └── utils/                     # Các hàm tiện ích (Helper functions).
      └── formatters.dart       # Định dạng tiền tệ, ngày tháng, số liệu.
```

## 4. Giải thích cụ thể các thành phần

### **Models (Dữ liệu)**
Đây là nơi định nghĩa các Class để chuyển đổi dữ liệu từ API (JSON) sang đối tượng Dart. Việc tách riêng Model giúp ứng dụng kiểm soát dữ liệu chặt chẽ và tận dụng tính năng Type-safety của Dart.

### **Services (Dịch vụ)**
Logic lấy thông tin được chuyển lên class cung cấp thống nhất:
- `YahooFinanceService`: Đóng gói các phương thức nhận diện cookie, crumb từ Yahoo Finance. Xử lý HTTP requests trực tiếp đến các endpoint của Yahoo (ví dụ: `v8/finance/chart`, `v7/finance/quote`,...) để lấy thiết lập giá realtime hoặc dữ liệu biểu đồ.
- `LoggerService`: Giúp theo dõi debug, sự cố với Talker trong việc xử lý Data.

### **State Management (Quản lý trạng thái)**
Sử dụng **Provider**. Đây là lựa chọn tối ưu cho dự án vì tính đơn giản và hiệu quả. Các provider thực hiện lắng nghe và thông báo cho toàn bộ màn hình liên quan khi cần cập nhật dữ liệu.

### **Screens & Widgets**
- Các UI Components tái sử dụng linh hoạt như `MiniSparkline` cùng với `fl_chart` mang đến giao diện trực quan và thân thiện.

## 5. Luồng hoạt động của ứng dụng (Data Flow)

Để giúp bạn dễ dàng nắm bắt logic code, đây là luồng hoạt động chính:

1. **Khởi động App (`main.dart`)**:
   - `WidgetsFlutterBinding.ensureInitialized()` được gọi để chuẩn bị môi trường.
   - Khởi tạo thư viện `Talker` (thông qua `LoggerService`) để ghi chép log.
   - Bọc toàn bộ ứng dụng (`AppBootstrap`) bằng `ChangeNotifierProvider<WatchlistProvider>`. Điều này giúp danh sách theo dõi chứng khoán khả dụng ở mọi màn hình.

2. **Quản lý State Toàn cục (`WatchlistProvider`)**:
   - Ngay từ khi được khởi tạo, provider sẽ đọc dữ liệu từ `SharedPreferences` để biết người dùng đang theo dõi mã nào.
   - Đồng thời, provider gọi đến `YahooFinanceService` để lấy danh sách mã toàn thị trường từ Yahoo (cache lại nếu có) để phục vụ cho tính năng tìm kiếm.

3. **Giao tiếp Dữ liệu (`YahooFinanceService`)**:
   - Khi bất kỳ màn hình nào cần lấy Giá hiện tại, Biểu đồ lịch sử, hoặc Thông tin cổ phiếu, nó sẽ gọi các hàm trong `YahooFinanceService`.
   - Lớp này sử dụng `_YahooAuthManager` tự động gọi một session request ẩn đến máy chủ Yahoo để chộp lấy (fetch) một Cookies và Crumb hợp lệ (đây là cách cấp quyền ngầm của Yahoo Finance).
   - Sau đó kèm Cookie & Crumb đó vào request (ví dụ: `v8/finance/chart/FPT.VN`) để lấy chuỗi JSON trả về. Cuối cùng parse JSON thành Model (như `Stock`, `MarketIndex`).

4. **Hiển thị Dữ liệu (Ví dụ `HomeScreen`)**:
   - Màn hình chính sử dụng `FutureBuilder` để tải đồng thời nhiều phần (Chỉ số TT, Tin tức, Danh mục Watchlist).
   - Provider lắng nghe và báo với `HomeScreen` mỗi khi danh sách Watchlist bị đổi đi (Thêm, Xóa), sau đó `HomeScreen` sẽ re-fetch giá cho các mã đó.
   - Component con `MiniSparkline` độc lập gọi API riêng lẻ để lấy biểu đồ thu nhỏ (sparkline) trong 7 ngày, với cache tránh gọi trùng lặp.

## 6. Công nghệ sử dụng
- **Framework**: Flutter (v3.x)
- **State Management**: Provider
- **Local Storage**: SharedPreferences (Lưu watchlist và cấu hình cục bộ)
- **Networking**: Http (Xử lý giao tiếp Data linh hoạt & Headers)
- **Log Management**: Talker
- **Charts**: fl_chart / CustomPaint (Cho sparkline)

## 7. Hướng dẫn cài đặt

1. **Clone dự án và cài đặt thư viện**:
   ```bash
   flutter pub get
   ```

2. **Chạy ứng dụng**:
   Nhấn chạy ứng dụng bằng lệnh:
   ```bash
   flutter run
   ```

---
