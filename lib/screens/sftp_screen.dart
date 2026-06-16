import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/card_model.dart';

class SftpScreen extends StatefulWidget {
  const SftpScreen({super.key});
  @override
  State<SftpScreen> createState() => _SftpScreenState();
}

class _SftpScreenState extends State<SftpScreen> {
  final ApiService _api = ApiService();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '22');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pathCtrl = TextEditingController(
    text: '/cardzone/oneswitch_batch/log/batch_output',
  );

  bool _obscurePass    = true;
  bool _connecting     = false;
  bool _connected      = false;
  bool _loadingFolders = false;
  bool _loadingFiles   = false;
  bool _importing      = false;
  bool _saved          = false;

  List<String>       _folders        = [];
  List<String>       _files          = [];
  String?            _selectedFolder;
  String?            _selectedFile;
  List<ParsedCard>   _previewCards   = [];
  List<ImportResult> _results        = [];

  final List<_LogEntry>  _logs      = [];
  final ScrollController _logScroll = ScrollController();

  static const _primary = Color(0xFF1B3A6B);
  static const _accent  = Color(0xFF2E75B6);
  static const _kHost   = 'sftp_host';
  static const _kPort   = 'sftp_port';
  static const _kUser   = 'sftp_user';
  static const _kPass   = 'sftp_pass';
  static const _kPath   = 'sftp_path';

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
    _log('info', 'App started — LDB SFTP Import v1.0');
  }

  void _log(String type, String msg) {
    final now = DateTime.now();
    final t = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final prefix = type == 'success' ? '✓ [OK] ' : type == 'error' ? '✗ [ERR]' : type == 'warn' ? '⚠ [WRN]' : '→ [LOG]';
    debugPrint('$t $prefix $msg');
    setState(() => _logs.add(_LogEntry(type: type, time: t, msg: msg)));
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_logScroll.hasClients) {
        _logScroll.animateTo(_logScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _loadSavedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hostCtrl.text = prefs.getString(_kHost) ?? '';
      _portCtrl.text = prefs.getString(_kPort) ?? '22';
      _userCtrl.text = prefs.getString(_kUser) ?? '';
      _passCtrl.text = prefs.getString(_kPass) ?? '';
      _pathCtrl.text = prefs.getString(_kPath) ?? '/cardzone/oneswitch_batch/log/batch_output';
    });
    if (_hostCtrl.text.isNotEmpty) {
      _log('info', 'Config loaded: host=${_hostCtrl.text}');
    } else {
      _log('warn', 'No saved config — please enter SFTP details');
    }
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHost, _hostCtrl.text.trim());
    await prefs.setString(_kPort, _portCtrl.text.trim());
    await prefs.setString(_kUser, _userCtrl.text.trim());
    await prefs.setString(_kPass, _passCtrl.text);
    await prefs.setString(_kPath, _pathCtrl.text.trim());
    setState(() => _saved = true);
    _log('success', 'Config saved: host=${_hostCtrl.text.trim()}');
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _saved = false);
  }

  Future<void> _clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in [_kHost, _kPort, _kUser, _kPass, _kPath]) await prefs.remove(k);
    setState(() {
      _hostCtrl.clear(); _portCtrl.text = '22'; _userCtrl.clear();
      _passCtrl.clear(); _pathCtrl.text = '/cardzone/oneswitch_batch/log/batch_output';
      _connected = false; _folders = []; _files = [];
      _selectedFolder = null; _selectedFile = null; _previewCards = [];
    });
    _log('warn', 'Config cleared');
  }

  Map<String, dynamic> get _sftpBody => {
    'host':     _hostCtrl.text.trim(),
    'port':     int.tryParse(_portCtrl.text.trim()) ?? 22,
    'username': _userCtrl.text.trim(),
    'password': _passCtrl.text,
    'basePath': _pathCtrl.text.trim(),
  };

  Future<void> _testConnection() async {
    if (_hostCtrl.text.isEmpty || _userCtrl.text.isEmpty) {
      _log('error', 'Missing Host or Username'); return;
    }
    setState(() { _connecting = true; _connected = false; _folders = []; _files = []; _selectedFolder = null; _selectedFile = null; _previewCards = []; });
    _log('info', 'Connecting: ${_userCtrl.text.trim()}@${_hostCtrl.text.trim()}:${_portCtrl.text}');
    try {
      await _api.sftpPost('sftp/test', _sftpBody);
      setState(() { _connected = true; _connecting = false; });
      _log('success', 'SFTP connected successfully');
      await _loadFolders();
    } catch (e) {
      setState(() => _connecting = false);
      _log('error', 'Connection failed: $e');
    }
  }

  Future<void> _loadFolders() async {
    setState(() { _loadingFolders = true; _folders = []; });
    _log('info', 'Loading date folders from: ${_pathCtrl.text.trim()}');
    try {
      final res = await _api.sftpPost('sftp/folders', _sftpBody);
      final f = List<String>.from(res['folders'] ?? []);
      setState(() { _folders = f; _loadingFolders = false; });
      _log('success', 'Found ${f.length} folders');
    } catch (e) {
      setState(() => _loadingFolders = false);
      _log('error', 'Load folders failed: $e');
    }
  }

  Future<void> _loadFiles(String folder) async {
    setState(() {
      _loadingFiles = true; _files = []; _selectedFolder = folder;
      _selectedFile = null; _previewCards = []; _results = [];
    });
    _log('info', 'Loading files: ${_pathCtrl.text.trim()}/$folder/emboss');
    try {
      final res = await _api.sftpPost('sftp/files', {..._sftpBody, 'dateFolder': folder});
      final f = List<String>.from(res['files'] ?? []);
      setState(() { _files = f; _loadingFiles = false; });
      if (f.isEmpty) {
        _log('warn', 'No files in emboss');
      } else {
        _log('success', 'Found ${f.length} file(s):');
        for (final x in f) _log('info', '  $x');
      }
    } catch (e) {
      setState(() => _loadingFiles = false);
      _log('error', 'Load files failed: $e');
    }
  }

  Future<void> _previewFile(String fileName) async {
    setState(() { _selectedFile = fileName; _previewCards = []; _results = []; });
    _log('info', 'Previewing file: $fileName');
    try {
      // Download content via preview endpoint
      final res = await _api.sftpPost('sftp/preview', {
        ..._sftpBody,
        'dateFolder': _selectedFolder!,
        'fileName':   fileName,
      });
      final cards = (res['cards'] as List).map((c) => ParsedCard(
        cmsRef:      c['cmsRef'] ?? '',
        cifNo:       c['cifNo'] ?? '',
        pan:         c['pan'] ?? '',
        panMasked:   c['panMasked'] ?? '',
        expire:      c['expire'] ?? '',
        cvv:         c['cvv'] ?? '',
        holderName:  c['holderName'] ?? '',
        productCode: c['productCode'] ?? '',
      )).toList();
      setState(() => _previewCards = cards);
      _log('success', 'Preview: ${cards.length} cards found');
      for (final c in cards) {
        _log('info', '  ${c.cifNo} | ${c.holderName} | ${c.panMasked} | ${c.expire} | CVV:${c.cvv}');
      }
    } catch (e) {
      _log('error', 'Preview failed: $e');
    }
  }

  Future<void> _importFile() async {
    if (_selectedFile == null || _previewCards.isEmpty) return;
    setState(() { _importing = true; _results = []; });
    _log('info', 'Importing: $_selectedFile');
    _log('info', 'AES-256-CBC encrypting ${_previewCards.length} cards...');
    try {
      final res = await _api.sftpPost('sftp/import', {
        ..._sftpBody,
        'dateFolder': _selectedFolder!,
        'fileName':   _selectedFile!,
      });
      final cards = (res['cards'] as List).map((c) => ImportResult.fromJson(c)).toList();
      setState(() { _results = cards; _importing = false; });
      _log('success', 'Import complete: ${cards.length} cards to Oracle');
      for (final c in cards) _log('success', '  Card #${c.cardId} ${c.panMasked}');
    } catch (e) {
      setState(() => _importing = false);
      _log('error', 'Import failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _primary, elevation: 0,
        title: const Row(children: [
          Icon(Icons.cloud_download, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('SFTP Import', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white70, size: 20),
            tooltip: 'Clear console',
            onPressed: () => setState(() => _logs.clear()),
          ),
        ],
      ),
      body: Row(children: [

        // ── Left ─────────────────────────────────
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // SFTP Config
              _section('SFTP Connection', Icons.settings_ethernet, Column(children: [
                Row(children: [
                  Expanded(flex: 3, child: _field('Host', _hostCtrl, hint: '10.0.3.24')),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Port', _portCtrl, hint: '22')),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field('Username', _userCtrl, hint: 'cardzone')),
                  const SizedBox(width: 10),
                  Expanded(child: _passwordField()),
                ]),
                const SizedBox(height: 10),
                _field('Base Path', _pathCtrl, hint: '/cardzone/oneswitch_batch/log/batch_output'),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: ElevatedButton.icon(
                    onPressed: _saveConfig,
                    icon: Icon(_saved ? Icons.check : Icons.save, size: 15),
                    label: Text(_saved ? 'Saved ✓' : 'Save', style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _saved ? const Color(0xFF1E7145) : _accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: _clearConfig,
                    icon: const Icon(Icons.delete_outline, size: 15),
                    label: const Text('Clear', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(flex: 2, child: ElevatedButton.icon(
                    onPressed: _connecting ? null : _testConnection,
                    icon: _connecting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_connected ? Icons.check_circle : Icons.wifi, size: 16),
                    label: Text(_connecting ? 'Connecting...' : _connected ? 'Connected ✓' : 'Connect',
                        style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _connected ? const Color(0xFF1E7145) : _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                  )),
                ]),
              ])),

              // Step 1: Date folders
              if (_connected) ...[
                const SizedBox(height: 12),
                _section('Step 1 — ເລືອກ Date', Icons.folder_open,
                  _loadingFolders
                    ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                    : _folders.isEmpty
                        ? Text('No folders', style: TextStyle(color: Colors.grey.shade400, fontSize: 12))
                        : Wrap(spacing: 6, runSpacing: 6, children: _folders.map((f) =>
                            GestureDetector(
                              onTap: () => _loadFiles(f),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _selectedFolder == f ? _primary : Colors.white,
                                  border: Border.all(color: _selectedFolder == f ? _primary : Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.folder, size: 14,
                                      color: _selectedFolder == f ? Colors.white : Colors.amber.shade700),
                                  const SizedBox(width: 5),
                                  Text(f, style: TextStyle(fontSize: 12, fontFamily: 'monospace',
                                      color: _selectedFolder == f ? Colors.white : Colors.black87,
                                      fontWeight: _selectedFolder == f ? FontWeight.w600 : FontWeight.normal)),
                                ]),
                              ),
                            )).toList(),
                ),
                ),
              ],

              // Step 2: Files
              if (_selectedFolder != null) ...[
                const SizedBox(height: 12),
                _section('Step 2 — ເລືອກ File', Icons.description,
                  _loadingFiles
                    ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                    : _files.isEmpty
                        ? Text('No files in emboss', style: TextStyle(color: Colors.grey.shade400, fontSize: 12))
                        : Column(children: _files.map((f) => GestureDetector(
                            onTap: () => _previewFile(f),
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedFile == f ? const Color(0xFFEEF4FB) : Colors.white,
                                border: Border.all(
                                    color: _selectedFile == f ? _accent : Colors.grey.shade200,
                                    width: _selectedFile == f ? 1.5 : 0.5),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Row(children: [
                                Icon(Icons.insert_drive_file, size: 16,
                                    color: _selectedFile == f ? _accent : Colors.grey.shade400),
                                const SizedBox(width: 8),
                                Expanded(child: Text(f, style: TextStyle(
                                    fontSize: 12, fontFamily: 'monospace',
                                    color: _selectedFile == f ? _accent : Colors.black87,
                                    fontWeight: _selectedFile == f ? FontWeight.w500 : FontWeight.normal))),
                                if (_selectedFile == f) ...[
                                  const Icon(Icons.check_circle, size: 16, color: Color(0xFF2E75B6)),
                                ],
                              ]),
                            ),
                          )).toList(),
                ),),

              ],

              // Step 3: Preview cards
              if (_previewCards.isNotEmpty) ...[
                const SizedBox(height: 12),
                _section('Step 3 — Preview Cards (${_previewCards.length} cards)', Icons.preview,
                  Column(children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFD5E3F5), borderRadius: BorderRadius.circular(6)),
                      child: const Row(children: [
                        SizedBox(width: 110, child: Text('CIF No', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF185FA5)))),
                        SizedBox(width: 160, child: Text('Holder Name', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF185FA5)))),
                        SizedBox(width: 160, child: Text('PAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF185FA5)))),
                        SizedBox(width: 60,  child: Text('Expire', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF185FA5)))),
                        SizedBox(width: 50,  child: Text('CVV', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF185FA5)))),
                        Expanded(child: Text('Product', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF185FA5)))),
                      ]),
                    ),
                    const SizedBox(height: 4),
                    // Rows
                    ..._previewCards.asMap().entries.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: e.key % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                        border: Border.all(color: Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(children: [
                        SizedBox(width: 110, child: Text(e.value.cifNo, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF185FA5)))),
                        SizedBox(width: 160, child: Text(e.value.holderName, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 160, child: Text(e.value.panMasked, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                        SizedBox(width: 60,  child: Text(e.value.expire, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                        SizedBox(width: 50,  child: Text(e.value.cvv, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                        Expanded(child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFD5E3F5), borderRadius: BorderRadius.circular(8)),
                          child: Text(e.value.productCode, style: const TextStyle(fontSize: 9, color: Color(0xFF185FA5)), overflow: TextOverflow.ellipsis),
                        )),
                      ]),
                    )),
                    const SizedBox(height: 12),
                    // Import button
                    SizedBox(width: double.infinity, child: ElevatedButton.icon(
                      onPressed: !_importing ? _importFile : null,
                      icon: _importing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.cloud_upload, size: 18),
                      label: Text(_importing
                          ? 'ກຳລັງ encrypt ແລະ insert ລົງ Oracle...'
                          : 'Import ${_previewCards.length} Cards ລົງ Oracle DB',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E7145),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                    )),
                  ]),
                ),
              ],

              // Step 4: Results
              if (_results.isNotEmpty) ...[
                const SizedBox(height: 12),
                _section('Step 4 — Import Result', Icons.check_circle_outline,
                  Column(children: [
                    // Stats
                    Row(children: [
                      _stat('${_results.length}', 'Inserted', const Color(0xFF1B3A6B)),
                      const SizedBox(width: 8),
                      _stat('AES-256', 'Encrypted', const Color(0xFF1E7145)),
                      const SizedBox(width: 8),
                      _stat('0', 'Errors', const Color(0xFF854F0B)),
                    ]),
                    const SizedBox(height: 10),
                    ..._results.map((c) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: const Color(0xFFD6EAD8),
                          border: Border.all(color: const Color(0xFF97C459), width: 0.5),
                          borderRadius: BorderRadius.circular(7)),
                      child: Row(children: [
                        const Icon(Icons.credit_card, size: 15, color: Color(0xFF1E7145)),
                        const SizedBox(width: 8),
                        Text('#${c.cardId}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text(c.panMasked, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                        const SizedBox(width: 8),
                        Text(c.expire, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFD5E3F5), borderRadius: BorderRadius.circular(8)),
                          child: const Text('INACTIVE', style: TextStyle(fontSize: 9, color: Color(0xFF185FA5), fontWeight: FontWeight.w500)),
                        ),
                      ]),
                    )),
                  ]),
                ),
              ],

            ]),
          ),
        ),

        // ── Right: Console ───────────────────────
        Container(
          width: 360,
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            border: Border(left: BorderSide(color: Color(0xFF333333))),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF2D2D2D),
                border: Border(bottom: BorderSide(color: Color(0xFF444444))),
              ),
              child: Row(children: [
                const Icon(Icons.terminal, size: 15, color: Color(0xFF4EC9B0)),
                const SizedBox(width: 8),
                const Text('Console', style: TextStyle(fontSize: 13, color: Color(0xFFD4D4D4), fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('${_logs.length} lines', style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _logs.clear()),
                  child: const Icon(Icons.clear_all, size: 16, color: Color(0xFF666666)),
                ),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                controller: _logScroll,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _logs.length,
                itemBuilder: (_, i) {
                  final log = _logs[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1.5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(log.time, style: const TextStyle(fontSize: 10, color: Color(0xFF555555), fontFamily: 'monospace')),
                      const SizedBox(width: 8),
                      Text(log.prefix, style: TextStyle(fontSize: 10, color: log.prefixColor, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(log.msg, style: TextStyle(fontSize: 11, color: log.color, fontFamily: 'monospace'), softWrap: true)),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),

      ]),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String hint = ''}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
      const SizedBox(height: 3),
      TextField(
        controller: ctrl,
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), isDense: true,
        ),
        style: const TextStyle(fontSize: 13),
      ),
    ]);
  }

  Widget _passwordField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Password', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
      const SizedBox(height: 3),
      TextField(
        controller: _passCtrl, obscureText: _obscurePass,
        decoration: InputDecoration(
          hintText: '••••••••', hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), isDense: true,
          suffixIcon: IconButton(
            icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, size: 16, color: Colors.grey),
            onPressed: () => setState(() => _obscurePass = !_obscurePass),
          ),
        ),
        style: const TextStyle(fontSize: 13),
      ),
    ]);
  }

  Widget _section(String title, IconData icon, Widget child) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _stat(String val, String label, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
    ));
  }
}

class _LogEntry {
  final String type, time, msg;
  _LogEntry({required this.type, required this.time, required this.msg});

  String get prefix => switch (type) {
    'success' => '[OK]  ',
    'error'   => '[ERR] ',
    'warn'    => '[WARN]',
    _         => '[LOG] ',
  };

  Color get prefixColor => switch (type) {
    'success' => const Color(0xFF4EC9B0),
    'error'   => const Color(0xFFF44747),
    'warn'    => const Color(0xFFCE9178),
    _         => const Color(0xFF569CD6),
  };

  Color get color => switch (type) {
    'success' => const Color(0xFFB5CEA8),
    'error'   => const Color(0xFFF44747),
    'warn'    => const Color(0xFFCE9178),
    _         => const Color(0xFFD4D4D4),
  };
}
