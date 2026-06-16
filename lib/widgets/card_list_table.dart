import 'package:flutter/material.dart';
import '../models/card_model.dart';

class CardListTable extends StatelessWidget {
  final List<VirtualCard> cards;
  final void Function(int cardId) onActivate;
  const CardListTable({super.key, required this.cards, required this.onActivate});

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
            0: FixedColumnWidth(50),
            1: FlexColumnWidth(1.6),
            2: FlexColumnWidth(1.6),
            3: FixedColumnWidth(72),
            4: FixedColumnWidth(52),
            5: FlexColumnWidth(1.6),
            6: FlexColumnWidth(1.0),
            7: FixedColumnWidth(88),
            8: FixedColumnWidth(90),
          },
          children: [
            _headerRow(['ID', 'ຊື່ລູກຄ້າ', 'PAN', 'Expire', 'CVV', 'Product Code', 'Status', 'Issued', 'Action']),
            ...cards.map((c) => TableRow(
              decoration: BoxDecoration(
                  color: c.cardStatus == 'ACTIVE' ? const Color(0xFFF8FFF8) : null,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
              children: [
                _cell('${c.cardId}', mono: true),
                _cell(c.fullName),
                _cell(c.maskedDisplay, mono: true),
                _cell(c.expire ?? '-', mono: true),
                _cell(c.cvv ?? '***', mono: true),
                _chipCell(c.productCode, const Color(0xFFD5E3F5), const Color(0xFF185FA5)),
                _statusChip(c.cardStatus),
                _cell(c.issuedDate != null
                    ? c.issuedDate!.substring(0, 10)
                    : '-', mono: true),
                _actionCell(c, onActivate),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(l, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
    )).toList(),
  );

  Widget _cell(String text, {bool mono = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    child: Text(text, style: TextStyle(fontSize: 12, fontFamily: mono ? 'monospace' : null)),
  );

  Widget _chipCell(String text, Color bg, Color fg) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w500)),
    ),
  );

  Widget _statusChip(String status) {
    final isActive = status == 'ACTIVE';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFD6EAD8) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(status,
            style: TextStyle(
                fontSize: 10,
                color: isActive ? const Color(0xFF1E7145) : Colors.grey.shade600,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _actionCell(VirtualCard c, void Function(int) onActivate) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: c.cardStatus == 'INACTIVE'
        ? OutlinedButton.icon(
            onPressed: () => onActivate(c.cardId),
            icon: const Icon(Icons.bolt, size: 13),
            label: const Text('Activate', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: const Color(0xFF185FA5),
            ),
          )
        : const Row(children: [
            Icon(Icons.check, size: 13, color: Color(0xFF1E7145)),
            SizedBox(width: 3),
            Text('Active', style: TextStyle(fontSize: 11, color: Color(0xFF1E7145))),
          ]),
  );
}
