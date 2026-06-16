// ── card_preview_table.dart ──────────────────────────────────
import 'package:flutter/material.dart';
import '../models/card_model.dart';

class CardPreviewTable extends StatelessWidget {
  final List<ParsedCard> cards;
  const CardPreviewTable({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.4),
            1: FlexColumnWidth(1.8),
            2: FlexColumnWidth(1.6),
            3: FlexColumnWidth(0.8),
            4: FlexColumnWidth(0.8),
            5: FlexColumnWidth(1.6),
          },
          children: [
            _headerRow(['CIF No', 'Holder Name', 'PAN', 'Expire', 'CVV', 'Product Code']),
            ...cards.map((c) => TableRow(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
              children: [
                _cell(c.cifNo, mono: true),
                _cell(c.holderName),
                _cell(c.panMasked, mono: true),
                _cell(c.expire, mono: true),
                _cell(c.cvv, mono: true),
                _chipCell(c.productCode),
              ],
            )),
          ],
        ),
      ),
    );
  }

  TableRow _headerRow(List<String> labels) => TableRow(
    decoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
    children: labels.map((l) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(l, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
    )).toList(),
  );

  Widget _cell(String text, {bool mono = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    child: Text(text,
        style: TextStyle(
          fontSize: 12,
          fontFamily: mono ? 'monospace' : null,
          color: const Color(0xFF1a1a1a),
        )),
  );

  Widget _chipCell(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFD5E3F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(fontSize: 10, color: Color(0xFF185FA5), fontWeight: FontWeight.w500)),
    ),
  );
}
