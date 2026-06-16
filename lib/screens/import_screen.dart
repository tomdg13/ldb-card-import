import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/card_model.dart';
import '../services/api_service.dart';
import '../widgets/card_preview_table.dart';
import '../widgets/result_table.dart';
import '../widgets/card_list_table.dart';
import '../widgets/status_chip.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final ApiService _api = ApiService();
  final _apiUrlCtrl = TextEditingController(text: 'http://localhost:2115');

  bool _apiOk       = false;
  bool _checking    = false;
  bool _importing   = false;
  bool _loadingList = false;

  String?            _fileName;
  List<int>?         _fileBytes;
  List<ParsedCard>   _parsedCards = [];
  List<ImportResult> _results     = [];
  List<VirtualCard>  _allCards    = [];
  String?            _errorMsg;
  String?            _successMsg;

  static const _primary = Color(0xFF1B3A6B);

  @override
  void initState() {
    super.initState();
    _checkApi();
  }

  Future<void> _checkApi() async {
    setState(() => _checking = true);
    _api.baseUrl = _apiUrlCtrl.text.trim();
    final ok = await _api.checkHealth();
    setState(() { _apiOk = ok; _checking = false; });
    if (ok) _loadList();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,  // ✅ ຮັບທຸກໄຟລ໌ ບໍ່ຈຳກັດ extension
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file    = result.files.first;
    final content = String.fromCharCodes(file.bytes!);
    final cards   = ParsedCard.fromFileContent(content);

    setState(() {
      _fileName    = file.name;
      _fileBytes   = file.bytes!.toList();
      _parsedCards = cards;
      _results     = [];
      _errorMsg    = null;
      _successMsg  = null;
    });
  }

  Future<void> _doImport() async {
    if (_fileBytes == null || _parsedCards.isEmpty) return;
    final first = _parsedCards.first;
    setState(() { _importing = true; _errorMsg = null; _successMsg = null; });
    try {
      final results = await _api.importFile(
        fileBytes:   _fileBytes!,
        fileName:    _fileName!,
        cifNo:       first.cifNo,
        fullName:    first.holderName,
        productCode: first.productCode,
      );
      setState(() {
        _results    = results;
        _successMsg = 'ສຳເລັດ! Insert ${results.length} cards ລົງ Oracle DB ດ້ວຍ AES-256';
        _importing  = false;
      });
      _loadList();
    } catch (e) {
      setState(() { _errorMsg = e.toString(); _importing = false; });
    }
  }

  Future<void> _loadList() async {
    setState(() => _loadingList = true);
    try {
      final cards = await _api.listCards();
      for (final c in cards) {
        try {
          final d = await _api.decryptCard(c.cardId);
          c.fullPan = d['pan'];
          c.cvv     = d['cvv'];
          c.expire  = d['expire'];
        } catch (_) {}
      }
      setState(() { _allCards = cards; _loadingList = false; });
    } catch (e) {
      setState(() => _loadingList = false);
    }
  }

  Future<void> _activateCard(int cardId) async {
    try {
      await _api.activateCard(cardId);
      setState(() => _successMsg = 'Card $cardId activated ສຳເລັດ');
      _loadList();
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    }
  }

  void _resetForm() {
    setState(() {
      _fileName    = null;
      _fileBytes   = null;
      _parsedCards = [];
      _results     = [];
      _errorMsg    = null;
      _successMsg  = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _primary,
        elevation: 0,
        title: Row(children: [
          const Icon(Icons.credit_card, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          const Text('LDB Virtual Card Import',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              _checking
                  ? const SizedBox(width: 8, height: 8,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.amber))
                  : Container(width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _apiOk ? Colors.greenAccent : Colors.redAccent)),
              const SizedBox(width: 6),
              Text(_checking ? 'ກຳລັງເຊື່ອມຕໍ່...' : _apiOk ? 'API ພ້ອມ ✓' : 'API ບໍ່ຕອບ',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ]),
          ),
        ]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              _sectionCard(
                title: 'ຕັ້ງຄ່າ API',
                icon: Icons.settings,
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _apiUrlCtrl,
                      decoration: _inputDeco('API Base URL'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _checkApi,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('ທົດສອບ'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              _sectionCard(
                title: 'ຂໍ້ມູນ Product',
                icon: Icons.info_outline,
                child: Wrap(spacing: 10, runSpacing: 8, children: const [
                  StatusChip(label: '08 Virtual Card UPI', color: Color(0xFF1B3A6B)),
                  StatusChip(label: 'Name: Parse ຈາກໄຟລ໌', color: Color(0xFF1E7145)),
                  StatusChip(label: 'CIF: Auto ຈາກ CMS Ref', color: Color(0xFF185FA5)),
                ]),
              ),
              const SizedBox(height: 12),

              _sectionCard(
                title: 'Upload CMS Card File',
                icon: Icons.upload_file,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  GestureDetector(
                    onTap: _pickFile,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _fileName != null ? const Color(0xFF1E7145) : Colors.grey.shade300,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: _fileName != null ? const Color(0xFFF0FAF4) : const Color(0xFFFAFAFA),
                      ),
                      child: Column(children: [
                        Icon(
                          _fileName != null ? Icons.check_circle_outline : Icons.upload_file,
                          size: 44,
                          color: _fileName != null ? const Color(0xFF1E7145) : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _fileName ?? 'ຄລິກເພື່ອເລືອກ CMS card file',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _fileName != null ? const Color(0xFF1E7145) : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fileName != null
                              ? '${_parsedCards.length} cards ພ້ອມ import'
                              : 'ຮອງຮັບທຸກໄຟລ໌ CMS format (ບໍ່ຈຳກັດ extension)',
                          style: TextStyle(
                            fontSize: 12,
                            color: _fileName != null ? const Color(0xFF1E7145) : Colors.grey.shade400,
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_parsedCards.isNotEmpty) ...[
                    Text('Preview Cards (${_parsedCards.length} cards)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 8),
                    CardPreviewTable(cards: _parsedCards),
                    const SizedBox(height: 16),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_parsedCards.isNotEmpty && !_importing) ? _doImport : null,
                      icon: _importing
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.storage, size: 18),
                      label: Text(_importing ? 'ກຳລັງ encrypt ແລະ insert...' : 'Import ລົງ Oracle DB'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              if (_errorMsg != null)   _alertBanner(_errorMsg!, isError: true),
              if (_successMsg != null) _alertBanner(_successMsg!, isError: false),

              if (_results.isNotEmpty) ...[
                const SizedBox(height: 4),
                _statsRow(_results.length),
                const SizedBox(height: 12),
                _sectionCard(
                  title: 'ຜົນ Import',
                  icon: Icons.check_circle_outline,
                  child: Column(children: [
                    ResultTable(results: _results, parsedCards: _parsedCards),
                    const SizedBox(height: 12),
                    Row(children: [
                      OutlinedButton.icon(
                        onPressed: _resetForm,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Import ໃໝ່'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _loadList,
                        icon: const Icon(Icons.list, size: 16),
                        label: const Text('Refresh list'),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 12),
              ],

              _sectionCard(
                title: 'Cards ທັງໝົດໃນ Oracle',
                icon: Icons.credit_card,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('${_allCards.length} cards',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _loadingList ? null : _loadList,
                      icon: _loadingList
                          ? const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 1.5))
                          : const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  if (_loadingList)
                    const Center(child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator()))
                  else if (_allCards.isEmpty)
                    Center(child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('ຍັງບໍ່ມີ cards',
                            style: TextStyle(color: Colors.grey.shade400))))
                  else
                    CardListTable(cards: _allCards, onActivate: _activateCard),
                ]),
              ),

            ]),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _alertBanner(String msg, {required bool isError}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFDECEA) : const Color(0xFFD6EAD8),
        border: Border.all(color: isError ? const Color(0xFFF09595) : const Color(0xFF97C459)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(isError ? Icons.warning_amber : Icons.check_circle,
            color: isError ? const Color(0xFFA32D2D) : const Color(0xFF1E7145), size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: TextStyle(
                fontSize: 13,
                color: isError ? const Color(0xFFA32D2D) : const Color(0xFF1E7145)))),
      ]),
    );
  }

  Widget _statsRow(int count) {
    final stats = [
      ('$count', 'Cards inserted', const Color(0xFF1B3A6B)),
      ('AES-256', 'Encryption',    const Color(0xFF1E7145)),
      ('08 UPI',  'Product Code',  const Color(0xFF185FA5)),
      ('0',       'Errors',        const Color(0xFF854F0B)),
    ];
    return Row(children: stats.map((s) => Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text(s.$1, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: s.$3)),
          const SizedBox(height: 4),
          Text(s.$2, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    )).toList());
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );
}
