class StockSymbol {
  const StockSymbol({
    required this.displaySymbol,
    required this.apiSymbol,
    required this.companyName,
    required this.exchange,
  });

  final String displaySymbol;
  final String apiSymbol;
  final String companyName;
  final String exchange;
}

const List<StockSymbol> kTrackedStockSymbols = <StockSymbol>[
  StockSymbol(displaySymbol: 'VCB', apiSymbol: 'VCB', companyName: 'Ngân hàng TMCP Ngoại Thương Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'BID', apiSymbol: 'BID', companyName: 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'CTG', apiSymbol: 'CTG', companyName: 'Ngân hàng TMCP Công thương Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'TCB', apiSymbol: 'TCB', companyName: 'Ngân hàng TMCP Kỹ thương Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VPB', apiSymbol: 'VPB', companyName: 'Ngân hàng TMCP Việt Nam Thịnh Vượng', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'MBB', apiSymbol: 'MBB', companyName: 'Ngân hàng TMCP Quân đội', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'STB', apiSymbol: 'STB', companyName: 'Ngân hàng TMCP Sài Gòn Thương Tín', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'ACB', apiSymbol: 'ACB', companyName: 'Ngân hàng TMCP Á Châu', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'HDB', apiSymbol: 'HDB', companyName: 'Ngân hàng TMCP Phát triển TP.HCM', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VIB', apiSymbol: 'VIB', companyName: 'Ngân hàng TMCP Quốc tế Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VNM', apiSymbol: 'VNM', companyName: 'CTCP Sữa Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'FPT', apiSymbol: 'FPT', companyName: 'CTCP FPT', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'MWG', apiSymbol: 'MWG', companyName: 'CTCP Đầu tư Thế Giới Di Động', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'PNJ', apiSymbol: 'PNJ', companyName: 'CTCP Vàng bạc Đá quý Phú Nhuận', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'REE', apiSymbol: 'REE', companyName: 'CTCP Cơ Điện Lạnh', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'HPG', apiSymbol: 'HPG', companyName: 'CTCP Tập đoàn Hòa Phát', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'GVR', apiSymbol: 'GVR', companyName: 'Tập đoàn Công nghiệp Cao su Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'DGC', apiSymbol: 'DGC', companyName: 'CTCP Tập đoàn Hóa chất Đức Giang', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'GAS', apiSymbol: 'GAS', companyName: 'Tổng Công ty Khí Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'POW', apiSymbol: 'POW', companyName: 'Tổng Công ty Điện lực Dầu khí Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'PLX', apiSymbol: 'PLX', companyName: 'Tập đoàn Xăng dầu Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VHM', apiSymbol: 'VHM', companyName: 'CTCP Vinhomes', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VIC', apiSymbol: 'VIC', companyName: 'Tập đoàn Vingroup', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VRE', apiSymbol: 'VRE', companyName: 'CTCP Vincom Retail', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'NVL', apiSymbol: 'NVL', companyName: 'CTCP Tập đoàn Đầu tư Địa ốc No Va', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'KDH', apiSymbol: 'KDH', companyName: 'CTCP Đầu tư và Kinh doanh Nhà Khang Điền', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'SSI', apiSymbol: 'SSI', companyName: 'CTCP Chứng khoán SSI', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VND', apiSymbol: 'VND', companyName: 'CTCP Chứng khoán VNDIRECT', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'HCM', apiSymbol: 'HCM', companyName: 'CTCP Chứng khoán TP.HCM', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'SAB', apiSymbol: 'SAB', companyName: 'Tổng CTCP Bia – Rượu – Nước giải khát Sài Gòn', exchange: 'HOSE'),
];

final Map<String, StockSymbol> kStockSymbolLookup = <String, StockSymbol>{
  for (final StockSymbol symbol in kTrackedStockSymbols) symbol.displaySymbol: symbol,
};
