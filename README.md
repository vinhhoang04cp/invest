# Stock Vision - Ứng dụng Theo dõi Chứng khoán Việt Nam (Flutter)

## 1. Giới thiệu dự án
**Stock Vision** là một ứng dụng di động được phát triển bằng Flutter, cho phép người dùng theo dõi biến động thị trường chứng khoán Việt Nam theo thời gian thực. Ứng dụng cung cấp các công cụ quản lý danh mục đầu tư (Portfolio), danh sách theo dõi (Watchlist) và cập nhật tin tức tài chính mới nhất.

- **Nhà phát triển**: 1 người (Cá nhân)
- **Mục tiêu**: Xây dựng một ứng dụng theo dõi tài chính chuyên nghiệp, có hiệu năng cao và trải nghiệm người dùng tối ưu.

## 2. Tính năng chính
- **Tổng quan thị trường**: Theo dõi các chỉ số VN-Index, HNX-Index, UPCoM.
- **Quản lý Watchlist**: Tùy chỉnh danh sách các mã cổ phiếu quan tâm (Thêm/Xóa/Sắp xếp).
- **Chi tiết cổ phiếu**: Biểu đồ giá trực quan, các thông số kỹ thuật (P/E, EPS, Vốn hóa) và tin tức liên quan.
- **Danh mục đầu tư (Portfolio)**: Quản lý tài sản, tính toán lãi/lỗ dựa trên giá thị trường hiện tại.
- **Tin tức**: Cập nhật tin tức thị trường từ các nguồn uy tín.
- **Cài đặt cá nhân**: Chỉnh sửa hồ sơ người dùng và tùy chọn giao diện.

## 3. Cấu trúc thư mục chi tiết (Folder Structure)

Dự án được tổ chức theo kiến trúc phân lớp rõ ràng để dễ dàng bảo trì và mở rộng:

```text
lib/
 ├── main.dart                  # Điểm khởi đầu của ứng dụng, cấu hình Theme và Router.
 ├── constants/                 # Chứa các giá trị cố định, cấu hình tĩnh.
 │    └── stock_symbols.dart    # Định nghĩa danh sách các mã chứng khoán mặc định và mapping.
 ├── models/                    # Lớp dữ liệu (Data Layer) - Định nghĩa các đối tượng.
 │    ├── stock.dart            # Thông tin về một mã cổ phiếu (giá, thay đổi, ...).
 │    ├── stock_symbol_model.dart # Cấu trúc dữ liệu cho danh mục mã (symbol, tên cty, sàn).
 │    ├── market_index.dart     # Dữ liệu các chỉ số thị trường (VN-Index, ...).
 │    ├── market_news.dart      # Cấu trúc dữ liệu bài báo, tin tức.
 │    ├── portfolio.dart        # Dữ liệu tài sản trong danh mục đầu tư.
 │    └── user.dart             # Thông tin cá nhân người dùng.
 ├── screens/                   # Giao diện người dùng (Presentation Layer) - Từng màn hình cụ thể.
 │    ├── home_screen.dart      # Màn hình chính (Dashboard).
 │    ├── stock_list_screen.dart # Danh sách thị trường và tìm kiếm mã.
 │    ├── stock_detail_screen.dart # Chi tiết về một mã chứng khoán cụ thể.
 │    ├── portfolio_screen.dart  # Quản lý tài sản cá nhân.
 │    ├── watchlist_manage_screen.dart # Giao diện quản lý/sắp xếp Watchlist.
 │    ├── settings_screen.dart  # Cài đặt ứng dụng.
 │    └── profile_screen.dart   # Chỉnh sửa thông tin cá nhân.
 ├── services/                  # Xử lý Logic và Dữ liệu ngoại vi (Service Layer).
 │    ├── api_service.dart      # Gọi API (Finnhub/VNDirect) để lấy dữ liệu thực tế.
 │    └── stock_symbol_repository.dart # Quản lý bộ nhớ đệm (Cache) và danh sách mã toàn thị trường.
 ├── state/                     # Quản lý trạng thái ứng dụng (State Management).
 │    └── watchlist_provider.dart # Sử dụng Provider để quản lý và đồng bộ Watchlist toàn app.
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
Tách biệt logic xử lý mạng và lưu trữ:
- `ApiService`: Đóng gói các phương thức gọi HTTP, xử lý lỗi và parsing dữ liệu thô.
- `StockSymbolRepository`: Đóng vai trò như một kho dữ liệu trung gian, lưu trữ danh sách mã cổ phiếu vào bộ nhớ máy (SharedPreferences) để giảm thiểu việc gọi API liên tục.

### **State Management (Quản lý trạng thái)**
Sử dụng **Provider**. Đây là lựa chọn tối ưu cho dự án này vì tính đơn giản và hiệu quả. `WatchlistProvider` chịu trách nhiệm thông báo cho toàn bộ các màn hình liên quan khi người dùng thêm hoặc xóa một mã chứng khoán khỏi danh sách yêu thích.

### **Screens & Widgets**
- **Screens**: Chứa logic điều hướng và bố cục chính của từng trang.
- **Widgets**: Chứa các UI components nhỏ hơn. Ví dụ: `MiniSparkline` được dùng lại ở cả Trang chủ và Danh sách cổ phiếu để hiển thị biểu đồ xu hướng.

## 5. Công nghệ sử dụng
- **Framework**: Flutter (v3.x)
- **State Management**: Provider
- **Local Storage**: SharedPreferences (Lưu watchlist và cache)
- **Networking**: Http, Flutter Dotenv (Quản lý API Key)
- **Charts**: fl_chart / custom painter (cho sparkline)

## 6. Hướng dẫn cài đặt

1. **Clone dự án và cài đặt thư viện**:
   ```bash
   flutter pub get
   ```

2. **Cấu hình biến môi trường**:
   Tạo file `.env` tại thư mục gốc và thêm API Key (Lấy từ Finnhub hoặc nguồn tương đương):
   ```text
   FINNHUB_API_KEY=your_api_key_here
   ```

3. **Chạy ứng dụng**:
   ```bash
   flutter run
   ```

---
*Dự án được xây dựng với tư duy "Clean Architecture" tối giản, phù hợp để mở rộng thêm các tính năng như giao dịch giả lập hoặc thông báo đẩy trong tương lai.*
