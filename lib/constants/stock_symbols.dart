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

/// Default tracked Vietnamese stock symbols.
/// apiSymbol uses Yahoo Finance format: SYMBOL.VN
const List<StockSymbol> kTrackedStockSymbols = <StockSymbol>[
  StockSymbol(displaySymbol: 'VCB', apiSymbol: 'VCB.VN', companyName: 'Ngân hàng TMCP Ngoại Thương Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'BID', apiSymbol: 'BID.VN', companyName: 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'CTG', apiSymbol: 'CTG.VN', companyName: 'Ngân hàng TMCP Công thương Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'TCB', apiSymbol: 'TCB.VN', companyName: 'Ngân hàng TMCP Kỹ thương Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VPB', apiSymbol: 'VPB.VN', companyName: 'Ngân hàng TMCP Việt Nam Thịnh Vượng', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'MBB', apiSymbol: 'MBB.VN', companyName: 'Ngân hàng TMCP Quân đội', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'STB', apiSymbol: 'STB.VN', companyName: 'Ngân hàng TMCP Sài Gòn Thương Tín', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'ACB', apiSymbol: 'ACB.VN', companyName: 'Ngân hàng TMCP Á Châu', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'HDB', apiSymbol: 'HDB.VN', companyName: 'Ngân hàng TMCP Phát triển TP.HCM', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VIB', apiSymbol: 'VIB.VN', companyName: 'Ngân hàng TMCP Quốc tế Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VNM', apiSymbol: 'VNM.VN', companyName: 'CTCP Sữa Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'FPT', apiSymbol: 'FPT.VN', companyName: 'CTCP FPT', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'MWG', apiSymbol: 'MWG.VN', companyName: 'CTCP Đầu tư Thế Giới Di Động', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'PNJ', apiSymbol: 'PNJ.VN', companyName: 'CTCP Vàng bạc Đá quý Phú Nhuận', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'REE', apiSymbol: 'REE.VN', companyName: 'CTCP Cơ Điện Lạnh', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'HPG', apiSymbol: 'HPG.VN', companyName: 'CTCP Tập đoàn Hòa Phát', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'GVR', apiSymbol: 'GVR.VN', companyName: 'Tập đoàn Công nghiệp Cao su Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'DGC', apiSymbol: 'DGC.VN', companyName: 'CTCP Tập đoàn Hóa chất Đức Giang', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'GAS', apiSymbol: 'GAS.VN', companyName: 'Tổng Công ty Khí Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'POW', apiSymbol: 'POW.VN', companyName: 'Tổng Công ty Điện lực Dầu khí Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'PLX', apiSymbol: 'PLX.VN', companyName: 'Tập đoàn Xăng dầu Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VHM', apiSymbol: 'VHM.VN', companyName: 'CTCP Vinhomes', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VIC', apiSymbol: 'VIC.VN', companyName: 'Tập đoàn Vingroup', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VRE', apiSymbol: 'VRE.VN', companyName: 'CTCP Vincom Retail', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'NVL', apiSymbol: 'NVL.VN', companyName: 'CTCP Tập đoàn Đầu tư Địa ốc No Va', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'KDH', apiSymbol: 'KDH.VN', companyName: 'CTCP Đầu tư và Kinh doanh Nhà Khang Điền', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'SSI', apiSymbol: 'SSI.VN', companyName: 'CTCP Chứng khoán SSI', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VND', apiSymbol: 'VND.VN', companyName: 'CTCP Chứng khoán VNDIRECT', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'HCM', apiSymbol: 'HCM.VN', companyName: 'CTCP Chứng khoán TP.HCM', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'SAB', apiSymbol: 'SAB.VN', companyName: 'Tổng CTCP Bia – Rượu – Nước giải khát Sài Gòn', exchange: 'HOSE'),
];

final Map<String, StockSymbol> kStockSymbolLookup = <String, StockSymbol>{
  for (final StockSymbol symbol in kTrackedStockSymbols) symbol.displaySymbol: symbol,
};
