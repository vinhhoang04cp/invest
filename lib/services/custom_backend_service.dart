import '../models/market_index.dart';
import '../models/market_news.dart';
import '../models/portfolio.dart';
import '../models/stock.dart';
import '../models/stock_symbol_model.dart';
import '../models/user.dart';

/// Mock backend service - Replace with real API calls when backend is ready
///
/// Usage: Change BASE_URL to your backend server
/// Example: http://api.yourdomain.com/api/v1
///
/// Backend should implement these endpoints:
/// GET    /api/v1/stocks/symbols           - Get all stock symbols
/// GET    /api/v1/stocks/indices           - Get market indices
/// GET    /api/v1/stocks/quote?symbols=    - Get stock quotes
/// GET    /api/v1/stocks/candle?symbol=    - Get candle data
/// GET    /api/v1/news                     - Get market news
/// GET    /api/v1/portfolio                - Get user portfolio
/// POST   /api/v1/portfolio                - Update portfolio
/// GET    /api/v1/user/profile             - Get user profile
/// PUT    /api/v1/user/profile             - Update user profile

class CustomBackendService {
  CustomBackendService._internal();

  static final CustomBackendService instance = CustomBackendService._internal();

  /// Change this to your real backend URL
  /// For local development: http://localhost:3000
  /// For production: https://api.yourdomain.com
  static const String baseUrl = 'http://localhost:3000/api/v1';

  /// Get all Vietnamese stock symbols
  Future<List<StockSymbolModel>> fetchAllVietnamSymbols() async {
    // Return mock data for now
    // When backend is ready, replace with:
    // final response = await http.get(Uri.parse('$baseUrl/stocks/symbols'));

    return _getMockSymbols();
  }

  /// Get market indices (VN-Index, HNX, UPCoM)
  Future<List<MarketIndex>> fetchMarketIndices() async {
    // TODO: Replace with real backend call
    // final response = await http.get(Uri.parse('$baseUrl/stocks/indices'));

    return _getMockMarketIndices();
  }

  /// Fetch stock quotes
  Future<List<Stock>> fetchStockQuotes({
    required List<StockSymbolModel> symbols,
  }) async {
    // TODO: Replace with real backend call
    // final params = symbols.map((s) => s.displaySymbol).join(',');
    // final response = await http.get(
    //   Uri.parse('$baseUrl/stocks/quote?symbols=$params')
    // );

    return _getMockStocks(symbols);
  }

  /// Fetch single stock quote
  Future<Stock?> fetchSingleQuote(StockSymbolModel symbol) async {
    // TODO: Replace with real backend call
    // final response = await http.get(
    //   Uri.parse('$baseUrl/stocks/quote?symbol=${symbol.displaySymbol}')
    // );

    final stocks = _getMockStocks([symbol]);
    return stocks.isNotEmpty ? stocks.first : null;
  }

  /// Fetch intraday price data (30-minute candles)
  Future<List<StockPricePoint>> fetchIntradayPrices({
    required String displaySymbol,
    String? apiSymbol,
  }) async {
    // TODO: Replace with real backend call
    // final response = await http.get(
    //   Uri.parse('$baseUrl/stocks/candle?symbol=$displaySymbol&resolution=30')
    // );

    return _getMockIntradayPrices();
  }

  /// Fetch historical price data (daily candles, 30 days)
  Future<List<StockPricePoint>> fetchHistoricalPrices({
    required String displaySymbol,
    String? apiSymbol,
  }) async {
    // TODO: Replace with real backend call
    // final response = await http.get(
    //   Uri.parse('$baseUrl/stocks/candle?symbol=$displaySymbol&resolution=D&days=30')
    // );

    return _getMockHistoricalPrices();
  }

  /// Fetch market news
  Future<List<MarketNews>> fetchMarketNews() async {
    // TODO: Replace with real backend call
    // final response = await http.get(Uri.parse('$baseUrl/news'));

    return _getMockNews();
  }

  /// Fetch user portfolio
  Future<PortfolioSummary> fetchPortfolio() async {
    // TODO: Replace with real backend call
    // final response = await http.get(
    //   Uri.parse('$baseUrl/portfolio'),
    //   headers: {'Authorization': 'Bearer $token'}
    // );

    return _getMockPortfolio();
  }

  /// Update portfolio
  Future<PortfolioSummary> updatePortfolio(PortfolioSummary portfolio) async {
    // TODO: Replace with real backend call
    // final response = await http.post(
    //   Uri.parse('$baseUrl/portfolio'),
    //   body: jsonEncode(portfolio.toJson()),
    //   headers: {'Authorization': 'Bearer $token'}
    // );

    return portfolio;
  }

  /// Fetch user profile
  Future<UserProfile> fetchUserProfile() async {
    // TODO: Replace with real backend call
    // final response = await http.get(
    //   Uri.parse('$baseUrl/user/profile'),
    //   headers: {'Authorization': 'Bearer $token'}
    // );

    return _getMockUserProfile();
  }

  /// Update user profile
  Future<UserProfile> updateUserProfile(UserProfile profile) async {
    // TODO: Replace with real backend call
    // final response = await http.put(
    //   Uri.parse('$baseUrl/user/profile'),
    //   body: jsonEncode(profile.toJson()),
    //   headers: {'Authorization': 'Bearer $token'}
    // );

    return profile;
  }

  // ====== MOCK DATA GENERATION (Remove when backend is ready) ======

  List<StockSymbolModel> _getMockSymbols() {
    return [
      StockSymbolModel(displaySymbol: 'VCB', apiSymbol: 'VCB', companyName: 'Ngân hàng TMCP Ngoại Thương Việt Nam', exchange: 'HOSE'),
      StockSymbolModel(displaySymbol: 'BID', apiSymbol: 'BID', companyName: 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam', exchange: 'HOSE'),
      StockSymbolModel(displaySymbol: 'CTG', apiSymbol: 'CTG', companyName: 'Ngân hàng TMCP Công thương Việt Nam', exchange: 'HOSE'),
      StockSymbolModel(displaySymbol: 'TCB', apiSymbol: 'TCB', companyName: 'Ngân hàng TMCP Kỹ thương Việt Nam', exchange: 'HOSE'),
      StockSymbolModel(displaySymbol: 'VPB', apiSymbol: 'VPB', companyName: 'Ngân hàng TMCP Việt Nam Thịnh Vượng', exchange: 'HOSE'),
      StockSymbolModel(displaySymbol: 'MBB', apiSymbol: 'MBB', companyName: 'Ngân hàng TMCP Quân đội', exchange: 'HOSE'),
      StockSymbolModel(displaySymbol: 'STB', apiSymbol: 'STB', companyName: 'Ngân hàng TMCP Sài Gòn Thương Tín', exchange: 'HOSE'),
      StockSymbolModel(displaySymbol: 'ACB', apiSymbol: 'ACB', companyName: 'Ngân hàng TMCP Á Châu', exchange: 'HOSE'),
    ];
  }

  List<MarketIndex> _getMockMarketIndices() {
    return [
      MarketIndex(name: 'VN-Index', value: 1280.5, changePercent: 1.25),
      MarketIndex(name: 'HNX', value: 314.2, changePercent: 0.85),
      MarketIndex(name: 'UPCoM', value: 98.5, changePercent: -0.45),
    ];
  }

  List<Stock> _getMockStocks(List<StockSymbolModel> symbols) {
    final mockPrices = {
      'VCB': (216500, 0.45),
      'BID': (34200, -0.82),
      'CTG': (24500, 1.23),
      'TCB': (25800, 0.65),
      'VPB': (24300, -0.15),
      'MBB': (29700, 1.05),
      'STB': (28100, 0.35),
      'ACB': (23400, -0.95),
    };

    return symbols.map((symbol) {
      final key = symbol.displaySymbol;
      final (price, changePercent) = mockPrices[key] ?? (20000, 0.0);
      return Stock(
        symbol: symbol.displaySymbol,
        name: symbol.companyName,
        price: price.toDouble(),
        changePercent: changePercent,
        volume: 1000000,
        apiSymbol: symbol.apiSymbol,
      );
    }).toList();
  }

  List<StockPricePoint> _getMockIntradayPrices() {
    return [
      StockPricePoint(timeLabel: '09:00', price: 24500),
      StockPricePoint(timeLabel: '09:30', price: 24550),
      StockPricePoint(timeLabel: '10:00', price: 24480),
      StockPricePoint(timeLabel: '10:30', price: 24620),
      StockPricePoint(timeLabel: '11:00', price: 24700),
      StockPricePoint(timeLabel: '11:30', price: 24650),
    ];
  }

  List<StockPricePoint> _getMockHistoricalPrices() {
    return [
      StockPricePoint(timeLabel: '01/04', price: 24200),
      StockPricePoint(timeLabel: '02/04', price: 24350),
      StockPricePoint(timeLabel: '03/04', price: 24400),
      StockPricePoint(timeLabel: '04/04', price: 24550),
      StockPricePoint(timeLabel: '05/04', price: 24480),
      StockPricePoint(timeLabel: '08/04', price: 24620),
      StockPricePoint(timeLabel: '09/04', price: 24700),
      StockPricePoint(timeLabel: '10/04', price: 24650),
    ];
  }

  List<MarketNews> _getMockNews() {
    return [
      MarketNews(
        title: 'VN-Index tăng 1.25% sau công bố GDP quý I',
        source: 'VNSE',
        publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
        url: 'https://vnse.vn/news/1',
      ),
      MarketNews(
        title: 'Cổ phiếu ngân hàng tăng trưởng mạnh mẽ',
        source: 'VnEconomy',
        publishedAt: DateTime.now().subtract(const Duration(hours: 4)),
        url: 'https://vneconomy.vn/news/2',
      ),
      MarketNews(
        title: 'Dòng tiền ngoại mạnh quay trở lại thị trường',
        source: 'Cung cấp thông tin',
        publishedAt: DateTime.now().subtract(const Duration(hours: 6)),
        url: 'https://finance.com/news/3',
      ),
    ];
  }

  PortfolioSummary _getMockPortfolio() {
    return PortfolioSummary(
      entries: [
        PortfolioEntry(
          stock: Stock(
            symbol: 'VCB',
            name: 'Vietcombank',
            price: 216500,
            changePercent: 0.45,
            volume: 0,
          ),
          quantity: 120,
          averagePrice: 210000,
        ),
        PortfolioEntry(
          stock: Stock(
            symbol: 'BID',
            name: 'BIDV',
            price: 34200,
            changePercent: -0.82,
            volume: 0,
          ),
          quantity: 200,
          averagePrice: 35000,
        ),
      ],
    );
  }

  UserProfile _getMockUserProfile() {
    return const UserProfile(
      fullName: 'Nguyễn Văn A',
      email: 'vana@example.com',
      phone: '+84 912 345 678',
      receiveNotifications: true,
      preferredLanguage: 'vi',
      darkMode: false,
    );
  }
}

