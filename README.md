# Stock Vision - Ứng dụng theo dõi chứng khoán (Flutter)

## 1. Giới thiệu dự án
- **Môn học**: Lập trình ứng dụng di động (Flutter)
- **Đề tài**: Ứng dụng theo dõi chứng khoán, theo dõi danh mục đầu tư, quản lý hồ sơ người dùng
- **Số lượng thành viên**: 5
- **Mục tiêu**: Hoàn thiện ứng dụng Flutter có cấu trúc chuẩn, đáp ứng yêu cầu về UI, xử lý dữ liệu, tương tác người dùng

Ứng dụng tạm thời sử dụng dữ liệu giả lập thông qua `ApiService`. Khi cần, có thể kết nối tới các API thực như Finnhub, Alpha Vantage, TwelveData...

## 2. Cấu trúc thư mục chính
```
lib/
 ├── main.dart                     // Khởi tạo ứng dụng, định nghĩa điều hướng chính
 ├── screens/                      // Màn hình theo từng tính năng (chia task cho từng thành viên)
 │    ├── home_screen.dart         // Thành viên 1
 │    ├── stock_list_screen.dart   // Thành viên 2
 │    ├── stock_detail_screen.dart // Thành viên 3
 │    ├── portfolio_screen.dart    // Thành viên 4
 │    ├── settings_screen.dart     // Thành viên 5
 │    ├── profile_screen.dart      // Thành viên 5 (phụ)
 │    └── watchlist_manage_screen.dart // Thành viên 1 (quản lý danh mục yêu thích)
 ├── models/                       // Định nghĩa model dữ liệu
 │    ├── stock.dart
 │    ├── market_index.dart
 │    ├── market_news.dart
 │    ├── portfolio.dart
 │    └── user.dart
 ├── constants/
 │    └── stock_symbols.dart       // Danh sách 30 mã cổ phiếu phổ biến (map sang API symbol)
 ├── services/
 │    └── api_service.dart         // Gọi Finnhub API (dữ liệu thời gian thực)
 └── widgets/
      └── section_header.dart      // Dùng chung cho các màn hình
```

## 3. Phân công nhiệm vụ chi tiết
| Thành viên | Màn hình/Module            | Nhiệm vụ chính |
|------------|----------------------------|----------------|
| 1          | `HomeScreen`               | Tổng quan thị trường, chỉ số VN-Index/HNX/UPCoM, top watchlist, tin tức nổi bật. Hoàn thiện UI/UX, tích hợp biểu đồ tổng quát nếu cần |
| 2          | `StockListScreen`          | Danh sách mã cổ phiếu, lọc/tìm kiếm, tích hợp refresh, điều hướng sang chi tiết |
| 3          | `StockDetailScreen`        | Chi tiết mã: biểu đồ giá, dữ liệu trong ngày/lịch sử, tin tức liên quan. Hoàn thiện TODO biểu đồ & link tin tức |
| 4          | `PortfolioScreen`          | Quản lý danh mục: thống kê tổng giá trị, lãi/lỗ, biểu đồ phân bổ, thêm/sửa/xóa mã |
| 5          | `SettingsScreen` & `ProfileScreen` | Cài đặt ứng dụng, quản lý hồ sơ, chế độ tối, thông báo, đăng xuất. Hoàn thiện biểu mẫu hồ sơ, TODO liên quan |

### Các TODO quan trọng cho từng thành viên
- **Member 1** (`home_screen.dart`)
  - [x] Thiết kế trang chủ dạng Apple Stocks (SliverAppBar, sparkline, gradient card)
  - [x] Thêm màn quản lý Watchlist (`watchlist_manage_screen.dart`) với reorder, thêm/xóa, lưu `SharedPreferences`
  - [ ] Thêm biểu đồ xu hướng chung (dùng `fl_chart` hoặc `syncfusion_flutter_charts`)
  - [ ] Kết nối API tin tức thực (nếu được) và mở URL khi nhấn vào tin

- **Member 2** (`stock_list_screen.dart`)
  - [ ] Bổ sung bộ lọc nâng cao (theo ngành, sàn)
  - [ ] Hiển thị trạng thái tăng/giảm bằng màu sắc rõ ràng hơn (chip)
  - [ ] Phân trang hoặc lazy loading nếu kết nối API thực

- **Member 3** (`stock_detail_screen.dart`)
  - [x] Thay bảng `_PricePointsTable` bằng biểu đồ đường tương tác (sử dụng `fl_chart`)
  - [ ] Thêm các chỉ số bổ sung (P/E, EPS, vốn hóa... nếu có API)
  - [ ] Hiển thị tin tức chi tiết khi nhấn

- **Member 4** (`portfolio_screen.dart`)
  - [ ] Thêm màn hình/modal thêm mã vào danh mục (form nhập số lượng, giá mua)
  - [ ] Vẽ biểu đồ phân bổ danh mục theo tỷ trọng
  - [ ] Cho phép chỉnh sửa/xóa từng mục danh mục

- **Member 5** (`settings_screen.dart`, `profile_screen.dart`)
  - [ ] Xử lý đăng nhập/đăng xuất thực tế (có thể mock Firebase/Auth API)
  - [ ] Đồng bộ trạng thái Dark Mode cho toàn app (sử dụng Provider/Riverpod)
  - [ ] Thêm tính năng đổi mật khẩu, upload ảnh đại diện, ngôn ngữ đa dạng

## 4. Luồng điều hướng & tương tác
- `MainNavigationShell` (bottom navigation) chứa 4 tab chính: Trang chủ – Thị trường – Danh mục – Cài đặt.
- Từ `HomeScreen` hoặc `StockListScreen` có thể điều hướng tới `StockDetailScreen` thông qua route `/stock-detail`.
- `SettingsScreen` điều hướng tới `ProfileScreen` để chỉnh sửa thông tin cá nhân.

## 5. Hướng dẫn chạy dự án
1. Cài đặt dependency
   ```bash
   flutter pub get
   ```
2. Khai báo API key Finnhub (dữ liệu thời gian thực)
   ```bash
   copy env.example .env
   ```
   Sau đó mở file `.env` và thay `FINNHUB_API_KEY` bằng key của bạn (đăng ký miễn phí tại [https://finnhub.io](https://finnhub.io)).
3. Chạy ứng dụng
   ```bash
   flutter run
   ```

> Lưu ý: Tài khoản Finnhub miễn phí giới hạn 60 request/phút. Ứng dụng đã chia request thành từng nhóm nhỏ, nhưng khi implement thêm tính năng cần lưu ý điều chỉnh tần suất gọi API.

## 6. Gợi ý mở rộng
- Tích hợp dữ liệu thời gian thực (WebSocket)
- Push Notification khi có biến động mạnh
- Đăng nhập bằng Google/Apple ID
- Biểu đồ so sánh nhiều mã trên cùng một chart

## 7. Tài liệu tham khảo
- [Flutter Layout](https://docs.flutter.dev/ui/layout)
- [State Management Patterns](https://docs.flutter.dev/data-and-backend/state-mgmt/intro)
- [fl_chart package](https://pub.dev/packages/fl_chart)
- [Finnhub Stock API](https://finnhub.io/docs/api)
- [Alpha Vantage](https://www.alphavantage.co/documentation/)
- [Twelve Data](https://twelvedata.com/)

---
Nếu cần mình tiếp tục tạo mock data chi tiết hoặc tích hợp package biểu đồ, hãy yêu cầu rõ phần cần hỗ trợ.
