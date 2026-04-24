/// Model đại diện cho một mã thông tin chứng khoán cơ bản.
/// Các thông tin này thường cố định và ít thay đổi (tên tĩnh, mã trên sàn).
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

/// Danh sách các mã chứng khoán Việt Nam.
/// `apiSymbol` của các mã này sử dụng định dạng bắt buộc của Yahoo Finance (VD: FPT.VN, PVS.HN) để gọi API.
const List<StockSymbol> kTrackedStockSymbols = <StockSymbol>[
  // VN30 & Large Caps - Ngân hàng
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
  StockSymbol(displaySymbol: 'TPB', apiSymbol: 'TPB.VN', companyName: 'Ngân hàng TMCP Tiên Phong', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'LPB', apiSymbol: 'LPB.VN', companyName: 'Ngân hàng TMCP Bưu điện Liên Việt', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'SHB', apiSymbol: 'SHB.VN', companyName: 'Ngân hàng TMCP Sài Gòn - Hà Nội', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'EIB', apiSymbol: 'EIB.VN', companyName: 'Ngân hàng TMCP Xuất Nhập khẩu Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'MSB', apiSymbol: 'MSB.VN', companyName: 'Ngân hàng TMCP Hàng Hải Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'OCB', apiSymbol: 'OCB.VN', companyName: 'Ngân hàng TMCP Phương Đông', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'SSB', apiSymbol: 'SSB.VN', companyName: 'Ngân hàng TMCP Đông Nam Á', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'NAB', apiSymbol: 'NAB.VN', companyName: 'Ngân hàng TMCP Nam Á', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'BVB', apiSymbol: 'BVB.VN', companyName: 'Ngân hàng TMCP Bản Việt', exchange: 'UPCOM'),
  StockSymbol(displaySymbol: 'VAB', apiSymbol: 'VAB.VN', companyName: 'Ngân hàng TMCP Việt Á', exchange: 'UPCOM'),
  StockSymbol(displaySymbol: 'ABB', apiSymbol: 'ABB.VN', companyName: 'Ngân hàng TMCP An Bình', exchange: 'UPCOM'),

  // Bất động sản / Xây dựng
  StockSymbol(displaySymbol: 'VHM', apiSymbol: 'VHM.VN', companyName: 'CTCP Vinhomes', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VIC', apiSymbol: 'VIC.VN', companyName: 'Tập đoàn Vingroup', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VRE', apiSymbol: 'VRE.VN', companyName: 'CTCP Vincom Retail', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'NVL', apiSymbol: 'NVL.VN', companyName: 'CTCP Tập đoàn Đầu tư Địa ốc No Va', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'KDH', apiSymbol: 'KDH.VN', companyName: 'CTCP Đầu tư và Kinh doanh Nhà Khang Điền', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'NLG', apiSymbol: 'NLG.VN', companyName: 'CTCP Đầu tư Nam Long', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'PDR', apiSymbol: 'PDR.VN', companyName: 'CTCP Phát triển Bất động sản Phát Đạt', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'DIG', apiSymbol: 'DIG.VN', companyName: 'Tổng CTCP Đầu tư Phát triển Xây dựng', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'CEO', apiSymbol: 'CEO.HN', companyName: 'CTCP Tập đoàn C.E.O', exchange: 'HNX'),
  StockSymbol(displaySymbol: 'DXG', apiSymbol: 'DXG.VN', companyName: 'CTCP Tập đoàn Đất Xanh', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'L14', apiSymbol: 'L14.HN', companyName: 'CTCP Licogi 14', exchange: 'HNX'),
  StockSymbol(displaySymbol: 'HDG', apiSymbol: 'HDG.VN', companyName: 'CTCP Tập đoàn Hà Đô', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'KBC', apiSymbol: 'KBC.VN', companyName: 'Tổng Công ty Phát triển Đô thị Kinh Bắc', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'IDC', apiSymbol: 'IDC.HN', companyName: 'Tổng Công ty IDICO', exchange: 'HNX'),
  StockSymbol(displaySymbol: 'VCG', apiSymbol: 'VCG.VN', companyName: 'Tổng CTCP Xuất nhập khẩu và Xây dựng Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'CTD', apiSymbol: 'CTD.VN', companyName: 'CTCP Xây dựng Coteccons', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'HBC', apiSymbol: 'HBC.VN', companyName: 'CTCP Tập đoàn Xây dựng Hòa Bình', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'HUT', apiSymbol: 'HUT.HN', companyName: 'CTCP Tasco', exchange: 'HNX'),
  StockSymbol(displaySymbol: 'CII', apiSymbol: 'CII.VN', companyName: 'CTCP Đầu tư Hạ tầng Kỹ thuật TP.HCM', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'SCR', apiSymbol: 'SCR.VN', companyName: 'CTCP Địa ốc Sài Gòn Thương Tín', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'SZC', apiSymbol: 'SZC.VN', companyName: 'CTCP Sonadezi Châu Đức', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'NTL', apiSymbol: 'NTL.VN', companyName: 'CTCP Phát triển Đô thị Từ Liêm', exchange: 'HOSE'),

  // Chứng khoán
  StockSymbol(displaySymbol: 'SSI', apiSymbol: 'SSI.VN', companyName: 'CTCP Chứng khoán SSI', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VND', apiSymbol: 'VND.VN', companyName: 'CTCP Chứng khoán VNDIRECT', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'HCM', apiSymbol: 'HCM.VN', companyName: 'CTCP Chứng khoán TP.HCM', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VCI', apiSymbol: 'VCI.VN', companyName: 'CTCP Chứng khoán Bản Việt', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'SHS', apiSymbol: 'SHS.HN', companyName: 'CTCP Chứng khoán Sài Gòn - Hà Nội', exchange: 'HNX'),
  StockSymbol(displaySymbol: 'MBS', apiSymbol: 'MBS.HN', companyName: 'CTCP Chứng khoán MB', exchange: 'HNX'),
  StockSymbol(displaySymbol: 'VIX', apiSymbol: 'VIX.VN', companyName: 'CTCP Chứng khoán VIX', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'FTS', apiSymbol: 'FTS.VN', companyName: 'CTCP Chứng khoán FPT', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'CTS', apiSymbol: 'CTS.VN', companyName: 'CTCP Chứng khoán Ngân hàng Công thương Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'BSI', apiSymbol: 'BSI.VN', companyName: 'CTCP Chứng khoán Ngân hàng Đầu tư và Phát triển Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'AGR', apiSymbol: 'AGR.VN', companyName: 'CTCP Chứng khoán Agribank', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VDS', apiSymbol: 'VDS.VN', companyName: 'CTCP Chứng khoán Rồng Việt', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'ORS', apiSymbol: 'ORS.VN', companyName: 'CTCP Chứng khoán Tiên Phong', exchange: 'HOSE'),

  // Thép / Vật liệu xây dựng
  StockSymbol(displaySymbol: 'HPG', apiSymbol: 'HPG.VN', companyName: 'CTCP Tập đoàn Hòa Phát', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'HSG', apiSymbol: 'HSG.VN', companyName: 'CTCP Tập đoàn Hoa Sen', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'NKG', apiSymbol: 'NKG.VN', companyName: 'CTCP Thép Nam Kim', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'POM', apiSymbol: 'POM.VN', companyName: 'CTCP Thép Pomina', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'TLH', apiSymbol: 'TLH.VN', companyName: 'CTCP Tập đoàn Thép Tiến Lên', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'SMC', apiSymbol: 'SMC.VN', companyName: 'CTCP Đầu tư Thương mại SMC', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VGS', apiSymbol: 'VGS.HN', companyName: 'CTCP Ống thép Việt Đức VG PIPE', exchange: 'HNX'),
  StockSymbol(displaySymbol: 'HT1', apiSymbol: 'HT1.VN', companyName: 'CTCP Xi măng Vicem Hà Tiên', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'BCC', apiSymbol: 'BCC.HN', companyName: 'CTCP Xi măng Bỉm Sơn', exchange: 'HNX'),
  StockSymbol(displaySymbol: 'KSB', apiSymbol: 'KSB.VN', companyName: 'CTCP Khoáng sản và Xây dựng Bình Dương', exchange: 'HOSE'),

  // Bán lẻ
  StockSymbol(displaySymbol: 'MWG', apiSymbol: 'MWG.VN', companyName: 'CTCP Đầu tư Thế Giới Di Động', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'PNJ', apiSymbol: 'PNJ.VN', companyName: 'CTCP Vàng bạc Đá quý Phú Nhuận', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'FRT', apiSymbol: 'FRT.VN', companyName: 'CTCP Bán lẻ Kỹ thuật số FPT', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'DGW', apiSymbol: 'DGW.VN', companyName: 'CTCP Thế Giới Số', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'PET', apiSymbol: 'PET.VN', companyName: 'Tổng CTCP Dịch vụ Tổng hợp Dầu khí', exchange: 'HOSE'),

  // Công nghệ / Viễn thông
  StockSymbol(displaySymbol: 'FPT', apiSymbol: 'FPT.VN', companyName: 'CTCP FPT', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'CMG', apiSymbol: 'CMG.VN', companyName: 'CTCP Tập đoàn Công nghệ CMC', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VGI', apiSymbol: 'VGI.VN', companyName: 'Tổng CTCP Đầu tư Quốc tế Viettel', exchange: 'UPCOM'),
  StockSymbol(displaySymbol: 'CTR', apiSymbol: 'CTR.VN', companyName: 'Tổng CTCP Công trình Viettel', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'ELC', apiSymbol: 'ELC.VN', companyName: 'CTCP Công nghệ – Viễn thông Elcom', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'FOX', apiSymbol: 'FOX.VN', companyName: 'CTCP Viễn thông FPT', exchange: 'UPCOM'),

  // Năng lượng / Dầu khí
  StockSymbol(displaySymbol: 'GAS', apiSymbol: 'GAS.VN', companyName: 'Tổng Công ty Khí Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'POW', apiSymbol: 'POW.VN', companyName: 'Tổng Công ty Điện lực Dầu khí Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'PLX', apiSymbol: 'PLX.VN', companyName: 'Tập đoàn Xăng dầu Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'PVS', apiSymbol: 'PVS.HN', companyName: 'Tổng CTCP Dịch vụ Kỹ thuật Dầu khí Việt Nam', exchange: 'HNX'),
  StockSymbol(displaySymbol: 'PVD', apiSymbol: 'PVD.VN', companyName: 'Tổng CTCP Khoan và Dịch vụ Khoan Dầu khí', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'BSR', apiSymbol: 'BSR.VN', companyName: 'CTCP Lọc Hóa dầu Bình Sơn', exchange: 'UPCOM'),
  StockSymbol(displaySymbol: 'OIL', apiSymbol: 'OIL.VN', companyName: 'Tổng Công ty Dầu Việt Nam', exchange: 'UPCOM'),
  StockSymbol(displaySymbol: 'PVT', apiSymbol: 'PVT.VN', companyName: 'Tổng CTCP Vận tải Dầu khí', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'PVC', apiSymbol: 'PVC.HN', companyName: 'Tổng công ty Hóa chất và Dịch vụ Dầu khí', exchange: 'HNX'),
  StockSymbol(displaySymbol: 'NT2', apiSymbol: 'NT2.VN', companyName: 'CTCP Điện lực Dầu khí Nhơn Trạch 2', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'GEG', apiSymbol: 'GEG.VN', companyName: 'CTCP Điện Gia Lai', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'QTP', apiSymbol: 'QTP.VN', companyName: 'CTCP Nhiệt điện Quảng Ninh', exchange: 'UPCOM'),

  // Hóa chất / Phân bón
  StockSymbol(displaySymbol: 'DGC', apiSymbol: 'DGC.VN', companyName: 'CTCP Tập đoàn Hóa chất Đức Giang', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'DCM', apiSymbol: 'DCM.VN', companyName: 'CTCP Phân bón Dầu khí Cà Mau', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'DPM', apiSymbol: 'DPM.VN', companyName: 'Tổng Công ty Phân bón và Hóa chất Dầu khí', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'BFC', apiSymbol: 'BFC.VN', companyName: 'CTCP Phân bón Bình Điền', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'CSV', apiSymbol: 'CSV.VN', companyName: 'CTCP Hóa chất Cơ bản Miền Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'LAS', apiSymbol: 'LAS.HN', companyName: 'CTCP Supe Phốt phát và Hóa chất Lâm Thao', exchange: 'HNX'),

  // Thực phẩm / Đồ uống / Nông nghiệp
  StockSymbol(displaySymbol: 'VNM', apiSymbol: 'VNM.VN', companyName: 'CTCP Sữa Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'SAB', apiSymbol: 'SAB.VN', companyName: 'Tổng CTCP Bia – Rượu – Nước giải khát Sài Gòn', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'MSN', apiSymbol: 'MSN.VN', companyName: 'CTCP Tập đoàn Masan', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'DBC', apiSymbol: 'DBC.VN', companyName: 'CTCP Tập đoàn Dabaco Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'HAG', apiSymbol: 'HAG.VN', companyName: 'CTCP Hoàng Anh Gia Lai', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'HNG', apiSymbol: 'HNG.VN', companyName: 'CTCP Nông nghiệp Quốc tế Hoàng Anh Gia Lai', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'BAF', apiSymbol: 'BAF.VN', companyName: 'CTCP Nông nghiệp BAF Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'PAN', apiSymbol: 'PAN.VN', companyName: 'CTCP Tập đoàn PAN', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'LTG', apiSymbol: 'LTG.VN', companyName: 'CTCP Tập đoàn Lộc Trời', exchange: 'UPCOM'),
  StockSymbol(displaySymbol: 'TAR', apiSymbol: 'TAR.HN', companyName: 'CTCP Nông nghiệp Công nghệ cao Trung An', exchange: 'HNX'),
  StockSymbol(displaySymbol: 'SBT', apiSymbol: 'SBT.VN', companyName: 'CTCP Thành Thành Công - Biên Hòa', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'QNS', apiSymbol: 'QNS.VN', companyName: 'CTCP Đường Quảng Ngãi', exchange: 'UPCOM'),
  StockSymbol(displaySymbol: 'KDC', apiSymbol: 'KDC.VN', companyName: 'CTCP Tập đoàn KIDO', exchange: 'HOSE'),

  // Hàng không / Vận tải / Logistics
  StockSymbol(displaySymbol: 'VJC', apiSymbol: 'VJC.VN', companyName: 'CTCP Hàng không Vietjet', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'HVN', apiSymbol: 'HVN.VN', companyName: 'Tổng Công ty Hàng không Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'ACV', apiSymbol: 'ACV.VN', companyName: 'Tổng Công ty Cảng Hàng không Việt Nam', exchange: 'UPCOM'),
  StockSymbol(displaySymbol: 'AST', apiSymbol: 'AST.VN', companyName: 'CTCP Dịch vụ Hàng không Taseco', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'SCS', apiSymbol: 'SCS.VN', companyName: 'CTCP Dịch vụ Hàng hóa Sài Gòn', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'GMD', apiSymbol: 'GMD.VN', companyName: 'CTCP Gemadept', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'HAH', apiSymbol: 'HAH.VN', companyName: 'CTCP Vận tải và Xếp dỡ Hải An', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'VSC', apiSymbol: 'VSC.VN', companyName: 'CTCP Tập đoàn Container Việt Nam', exchange: 'HOSE'),

  // Dệt may
  StockSymbol(displaySymbol: 'VGT', apiSymbol: 'VGT.VN', companyName: 'Tập đoàn Dệt may Việt Nam', exchange: 'UPCOM'),
  StockSymbol(displaySymbol: 'TNG', apiSymbol: 'TNG.HN', companyName: 'CTCP Đầu tư và Thương mại TNG', exchange: 'HNX'),
  StockSymbol(displaySymbol: 'TCM', apiSymbol: 'TCM.VN', companyName: 'CTCP Dệt may Đầu tư Thương mại Thành Công', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'MSH', apiSymbol: 'MSH.VN', companyName: 'CTCP May Sông Hồng', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'GIL', apiSymbol: 'GIL.VN', companyName: 'CTCP Sản xuất Kinh doanh Xuất nhập khẩu Bình Thạnh', exchange: 'HOSE'),

  // Thủy sản
  StockSymbol(displaySymbol: 'VHC', apiSymbol: 'VHC.VN', companyName: 'CTCP Vĩnh Hoàn', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'ANV', apiSymbol: 'ANV.VN', companyName: 'CTCP Nam Việt', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'IDI', apiSymbol: 'IDI.VN', companyName: 'CTCP Đầu tư và Phát triển Đa Quốc Gia I.D.I', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'FMC', apiSymbol: 'FMC.VN', companyName: 'CTCP Thực phẩm Sao Ta', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'MPC', apiSymbol: 'MPC.VN', companyName: 'CTCP Tập đoàn Thủy sản Minh Phú', exchange: 'UPCOM'),

  // Cao su
  StockSymbol(displaySymbol: 'GVR', apiSymbol: 'GVR.VN', companyName: 'Tập đoàn Công nghiệp Cao su Việt Nam', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'PHR', apiSymbol: 'PHR.VN', companyName: 'CTCP Cao su Phước Hòa', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'DPR', apiSymbol: 'DPR.VN', companyName: 'CTCP Cao su Đồng Phú', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'TRC', apiSymbol: 'TRC.VN', companyName: 'CTCP Cao su Tây Ninh', exchange: 'HOSE'),

  // Nhựa / Bao bì
  StockSymbol(displaySymbol: 'BMP', apiSymbol: 'BMP.VN', companyName: 'CTCP Nhựa Bình Minh', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'NTP', apiSymbol: 'NTP.HN', companyName: 'CTCP Nhựa Thiếu niên Tiền Phong', exchange: 'HNX'),
  StockSymbol(displaySymbol: 'AAA', apiSymbol: 'AAA.VN', companyName: 'CTCP Nhựa An Phát Xanh', exchange: 'HOSE'),

  // Đa ngành / Khác
  StockSymbol(displaySymbol: 'REE', apiSymbol: 'REE.VN', companyName: 'CTCP Cơ Điện Lạnh', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'GEX', apiSymbol: 'GEX.VN', companyName: 'CTCP Tập đoàn GELEX', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'SAM', apiSymbol: 'SAM.VN', companyName: 'CTCP SAM HOLDINGS', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'HQC', apiSymbol: 'HQC.VN', companyName: 'CTCP Tư vấn - Thương mại - Dịch vụ Địa ốc Hoàng Quân', exchange: 'HOSE'),
  StockSymbol(displaySymbol: 'ITA', apiSymbol: 'ITA.VN', companyName: 'CTCP Đầu tư và Công nghiệp Tân Tạo', exchange: 'HOSE'),
];

/// Map hỗ trợ tra cứu nhanh (Lookup Map) mã chứng khoán dựa theo symbol (ví dụ 'FPT').
/// Giúp tìm kiếm mã nhanh với độ phức tạp O(1) thay vì phải dùng vòng lặp (O(n)).
final Map<String, StockSymbol> kStockSymbolLookup = <String, StockSymbol>{
  for (final StockSymbol symbol in kTrackedStockSymbols) symbol.displaySymbol: symbol,
};
