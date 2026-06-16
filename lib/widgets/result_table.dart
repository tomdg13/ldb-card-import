import 'package:flutter/material.dart';
import '../models/card_model.dart';

class ResultTable extends StatelessWidget {
  final List<ImportResult> results;
  final List<ParsedCard>   parsedCards;
  const ResultTable({super.key, required this.results, required this.parsedCards});

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
            0: FixedColumnWidth(60),
            1: FlexColumnWidth(1.8),
            2: FlexColumnWidth(1.6),
            3: FlexColumnWidth(0.8),
            4: FlexColumnWidth(1.6),
            5: FlexColumnWidth(1.0),
            6: FlexColumnWidth(1.0),
          },
          children: [
            _headerRow(['Card ID', 'Holder Name', 'PAN', 'Expire', 'Product Code', 'CMS Ref', 'Status']),
            ...results.asMap().entries.map((e) {
              final c = e.value;
              final p = e.key < parsedCards.length ? parsedCards[e.key] : null;
              return TableRow(
                decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
                children: [
                  _cell('${c.cardId}', mono: true),
                  _cell(p?.holderName ?? '-'),
                  _cell(p?.panMasked ?? c.panMasked, mono: true),
                  _cell(c.expire, mono: true),
                  _chipCell(c.productCode, const Color(0xFFD5E3F5), const Color(0xFF185FA5)),
                  _cell(c.cmsRef, mono: true),
                  _chipCell('INACTIVE', const Color(0xFFD5E3F5), const Color(0xFF185FA5)),
                ],
              );
            }),
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
    child: Text(text, style: TextStyle(fontSize: 12, fontFamily: mono ? 'monospace' : null)),
  );

  Widget _chipCell(String text, Color bg, Color fg) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w500)),
    ),
  );
}
