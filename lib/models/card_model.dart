class ParsedCard {
  final String cmsRef;
  final String cifNo;
  final String pan;
  final String panMasked;
  final String expire;
  final String cvv;
  final String holderName;
  final String productCode;

  ParsedCard({
    required this.cmsRef,
    required this.cifNo,
    required this.pan,
    required this.panMasked,
    required this.expire,
    required this.cvv,
    required this.holderName,
    required this.productCode,
  });

  static String maskPan(String pan) {
    if (pan.length < 10) return pan;
    return pan.substring(0, 6) + 'x' * (pan.length - 10) + pan.substring(pan.length - 4);
  }

  static List<ParsedCard> fromFileContent(String content) {
    final lines = content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.contains('#END#'))
        .toList();

    return lines.map((line) {
      final cmsRef    = RegExp(r'^(\d+)\$').firstMatch(line)?.group(1) ?? '';
      final pan       = RegExp(r';(\d{16})=').firstMatch(line)?.group(1) ?? '';
      final expire    = RegExp(r'(\d{2}/\d{2})!').firstMatch(line)?.group(1) ?? '';
      final cvv       = RegExp(r'!(\d{3})\*').firstMatch(line)?.group(1) ?? '';
      final nameMatch = RegExp(r'\*([A-Z][A-Z ]+?)\s{2,}').firstMatch(line);
      final name      = nameMatch?.group(1)?.trim() ?? '';

      return ParsedCard(
        cmsRef:      cmsRef,
        cifNo:       'LDB-$cmsRef',
        pan:         pan,
        panMasked:   maskPan(pan),
        expire:      expire,
        cvv:         cvv,
        holderName:  name,
        productCode: '08 Virtual Card UPI',
      );
    }).toList();
  }
}

class VirtualCard {
  final int cardId;
  final String fullName;
  final String panMasked;
  final String cardScheme;
  final String productCode;
  final String cardStatus;
  final String? issuedDate;
  String? fullPan;
  String? cvv;
  String? expire;

  VirtualCard({
    required this.cardId,
    required this.fullName,
    required this.panMasked,
    required this.cardScheme,
    required this.productCode,
    required this.cardStatus,
    this.issuedDate,
    this.fullPan,
    this.cvv,
    this.expire,
  });

  factory VirtualCard.fromJson(Map<String, dynamic> j) => VirtualCard(
    cardId:      j['CARD_ID'] as int,
    fullName:    j['FULL_NAME'] ?? '-',
    panMasked:   j['PAN_MASKED'] ?? '',
    cardScheme:  j['CARD_SCHEME'] ?? '',
    productCode: j['PRODUCT_CODE'] ?? '',
    cardStatus:  j['CARD_STATUS'] ?? '',
    issuedDate:  j['ISSUED_DATE'],
  );

  String get maskedDisplay {
    if (fullPan != null && fullPan!.length >= 10) {
      return fullPan!.substring(0, 6) +
          'x' * (fullPan!.length - 10) +
          fullPan!.substring(fullPan!.length - 4);
    }
    return panMasked;
  }
}

class ImportResult {
  final int cardId;
  final String panMasked;
  final String expire;
  final String productCode;
  final String cardStatus;
  final String cmsRef;

  ImportResult({
    required this.cardId,
    required this.panMasked,
    required this.expire,
    required this.productCode,
    required this.cardStatus,
    required this.cmsRef,
  });

  factory ImportResult.fromJson(Map<String, dynamic> j) => ImportResult(
    cardId:      j['cardId'] as int,
    panMasked:   j['panMasked'] ?? '',
    expire:      j['expire'] ?? '',
    productCode: j['productCode'] ?? '',
    cardStatus:  j['cardStatus'] ?? '',
    cmsRef:      j['cmsRef'] ?? '',
  );
}
