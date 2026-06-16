import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/card_model.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ApiService _api = ApiService();

  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '22');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pathCtrl = TextEditingController(
    text: '/cardzone/oneswitch_batch/log/batch_output',
  );

  bool   _scheduleEnabled  = false;
  String _scheduleTime     = '08:00';
  String _scheduleInterval = 'daily';
  bool   _autoImportAll    = true;
  bool   _obscurePass      = true;
  bool   _saved            = false;
  bool   _running          = false;
  bool   _connected        = false;
  bool   _connecting       = false;

  // Countdown
  Timer?   _countdownTimer;
  Duration _countdown = Duration.zero;
  DateTime? _nextRun;

  // Stats
  String? _lastRun;
  int _totalImported = 0;
  int _totalCards    = 0;

  final List<_ScheduleLog> _logs      = [];
  final ScrollController   _logScroll = ScrollController();

  static const _primary = Color(0xFF1B3A6B);
  static const _accent  = Color(0xFF2E75B6);
  static const _kHost    = 'sch_sftp_host';
  static const _kPort    = 'sch_sftp_port';
  static const _kUser    = 'sch_sftp_user';
  static const _kPass    = 'sch_sftp_pass';
  static const _kPath    = 'sch_sftp_path';
  static const _kTime    = 'sch_time';
  static const _kIntvl   = 'sch_interval';
  static const _kAuto    = 'sch_auto';
  static const _kEnabled = 'sch_enabled';

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _addLog('info', 'Schedule Import initialized');
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _addLog(String type, String msg) {
    final now = DateTime.now();
    final t = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}';
    final prefix = type == 'success' ? '✓ [OK] ' : type == 'error' ? '✗ [ERR]' : type == 'warn' ? '⚠ [WRN]' : '→ [LOG]';
    debugPrint('$t $prefix $msg');
    setState(() => _logs.insert(0, _ScheduleLog(type: type, time: t, msg: msg)));
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hostCtrl.text    = prefs.getString(_kHost) ?? '';
      _portCtrl.text    = prefs.getString(_kPort) ?? '22';
      _userCtrl.text    = prefs.getString(_kUser) ?? '';
      _passCtrl.text    = prefs.getString(_kPass) ?? '';
      _pathCtrl.text    = prefs.getString(_kPath) ?? '/cardzone/oneswitch_batch/log/batch_output';
      _scheduleTime     = prefs.getString(_kTime)  ?? '08:00';
      _scheduleInterval = prefs.getString(_kIntvl) ?? 'daily';
      _autoImportAll    = prefs.getBool(_kAuto)    ?? true;
      _scheduleEnabled  = prefs.getBool(_kEnabled) ?? false;
    });
    if (_hostCtrl.text.isNotEmpty) _addLog('info', 'Config loaded: host=${_hostCtrl.text}');
    if (_scheduleEnabled) _startCountdown();
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHost,  _hostCtrl.text.trim());
    await prefs.setString(_kPort,  _portCtrl.text.trim());
    await prefs.setString(_kUser,  _userCtrl.text.trim());
    await prefs.setString(_kPass,  _passCtrl.text);
    await prefs.setString(_kPath,  _pathCtrl.text.trim());
    await prefs.setString(_kTime,  _scheduleTime);
    await prefs.setString(_kIntvl, _scheduleInterval);
    await prefs.setBool(_kAuto,    _autoImportAll);
    await prefs.setBool(_kEnabled, _scheduleEnabled);
    setState(() => _saved = true);
    _addLog('success', 'Config saved');
    if (_scheduleEnabled) _startCountdown();
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _saved = false);
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _nextRun = _calcNextRun();
    _addLog('info', 'Next run scheduled: ${_fmtDt(_nextRun!)}');
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      if (_nextRun == null) return;
      final diff = _nextRun!.difference(now);
      if (diff.isNegative) {
        // Time to run!
        _runNow();
        _nextRun = _calcNextRun();
        _addLog('info', 'Next run: ${_fmtDt(_nextRun!)}');
      } else {
        setState(() => _countdown = diff);
      }
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = Duration.zero);
  }

  DateTime _calcNextRun() {
    final now = DateTime.now();
    if (_scheduleInterval == 'hourly') {
      return now.add(const Duration(hours: 1));
    }
    // daily — ໃຊ້ _scheduleTime
    final parts  = _scheduleTime.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    var next = DateTime(now.year, now.month, now.day, h, m);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));
    return next;
  }

  String _fmtDt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')} '
      '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

  String _fmtCountdown(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
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
      _addLog('error', 'Missing Host or Username'); return;
    }
    setState(() { _connecting = true; _connected = false; });
    _addLog('info', 'Testing: ${_userCtrl.text.trim()}@${_hostCtrl.text.trim()}');
    try {
      await _api.sftpPost('sftp/test', _sftpBody);
      setState(() { _connected = true; _connecting = false; });
      _addLog('success', 'SFTP connected');
    } catch (e) {
      setState(() => _connecting = false);
      _addLog('error', 'Connection failed: $e');
    }
  }

  Future<void> _runNow() async {
    if (_running) return;
    setState(() => _running = true);
    final today      = DateTime.now();
    final dateFolder = '${today.year}${today.month.toString().padLeft(2,'0')}${today.day.toString().padLeft(2,'0')}';
    _addLog('info', '=== Run Started: $dateFolder ===');

    try {
      final filesRes = await _api.sftpPost('sftp/files', {..._sftpBody, 'dateFolder': dateFolder});
      final files    = List<String>.from(filesRes['files'] ?? []);

      if (files.isEmpty) {
        _addLog('warn', 'No files found for $dateFolder');
        setState(() { _running = false; _lastRun = _fmtDt(today); });
        return;
      }

      _addLog('success', 'Found ${files.length} file(s)');
      int totalCards = 0;

      for (final fileName in files) {
        _addLog('info', 'Importing: $fileName');
        try {
          final res   = await _api.sftpPost('sftp/import', {..._sftpBody, 'dateFolder': dateFolder, 'fileName': fileName});
          final cards = (res['cards'] as List);
          totalCards += cards.length;
          _addLog('success', '  ✓ $fileName → ${cards.length} cards');
          for (final c in cards) {
            _addLog('success', '    Card #${c['cardId']} ${c['panMasked']} ${c['expire']}');
          }
        } catch (e) {
          _addLog('error', '  ✗ $fileName → $e');
        }
      }

      setState(() {
        _running       = false;
        _lastRun       = _fmtDt(today);
        _totalImported += files.length;
        _totalCards    += totalCards;
      });
      _addLog('success', '=== Done: $totalCards cards from ${files.length} files ===');
    } catch (e) {
      setState(() => _running = false);
      _addLog('error', 'Run failed: $e');
    }
  }

  String _todayFolder() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _primary, elevation: 0,
        title: const Row(children: [
          Icon(Icons.schedule, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('Schedule Import', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white70),
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
            child: Column(children: [

              // ── Countdown Box ─────────────────
              if (_scheduleEnabled) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B3A6B), Color(0xFF2E75B6)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: const Color(0xFF1B3A6B).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.timer, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _running ? 'ກຳລັງ Import...' : 'Next Import In',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    if (_running)
                      const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    else
                      Text(
                        _countdown == Duration.zero ? '--:--:--' : _fmtCountdown(_countdown),
                        style: const TextStyle(
                          color: Colors.white, fontSize: 52, fontWeight: FontWeight.w700,
                          fontFamily: 'monospace', letterSpacing: 4,
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (_nextRun != null && !_running)
                      Text(
                        'Next: ${_fmtDt(_nextRun!)}',
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    const SizedBox(height: 12),
                    // Progress bar
                    if (!_running && _nextRun != null && _countdown != Duration.zero) ...[
                      Builder(builder: (_) {
                        final total = _scheduleInterval == 'hourly'
                            ? const Duration(hours: 1).inSeconds.toDouble()
                            : const Duration(days: 1).inSeconds.toDouble();
                        final remaining = _countdown.inSeconds.toDouble();
                        final progress = 1.0 - (remaining / total).clamp(0.0, 1.0);
                        return Column(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${(progress * 100).toStringAsFixed(1)}% elapsed',
                              style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        ]);
                      }),
                    ],
                  ]),
                ),
                const SizedBox(height: 12),
              ],

              // Stats
              if (_lastRun != null) ...[
                Row(children: [
                  _statBox('Last Run', _lastRun!, const Color(0xFF1B3A6B)),
                  const SizedBox(width: 8),
                  _statBox('Files', '$_totalImported', const Color(0xFF2E75B6)),
                  const SizedBox(width: 8),
                  _statBox('Cards', '$_totalCards', const Color(0xFF1E7145)),
                ]),
                const SizedBox(height: 12),
              ],

              // SFTP Config
              _card('SFTP Connection', Icons.settings_ethernet, Column(children: [
                Row(children: [
                  Expanded(flex: 3, child: _field('Host', _hostCtrl, hint: '10.0.3.24')),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Port', _portCtrl, hint: '22')),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field('Username', _userCtrl, hint: 'cardzone')),
                  const SizedBox(width: 10),
                  Expanded(child: _pwField()),
                ]),
                const SizedBox(height: 10),
                _field('Base Path', _pathCtrl, hint: '/cardzone/oneswitch_batch/log/batch_output'),
                const SizedBox(height: 4),
                Text('System append /YYYYMMDD/emboss ອັດຕະໂນມັດ',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                const SizedBox(height: 12),
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
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: _connecting ? null : _testConnection,
                    icon: _connecting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_connected ? Icons.check_circle : Icons.wifi_tethering, size: 16),
                    label: Text(_connecting ? 'Testing...' : _connected ? 'Connected ✓' : 'Test',
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
              const SizedBox(height: 12),

              // Schedule Settings
              _card('Schedule Settings', Icons.timer, Column(children: [
                // Toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _scheduleEnabled ? const Color(0xFFD6EAD8) : const Color(0xFFF5F5F5),
                    border: Border.all(color: _scheduleEnabled ? const Color(0xFF97C459) : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(_scheduleEnabled ? Icons.play_circle : Icons.pause_circle,
                        color: _scheduleEnabled ? const Color(0xFF1E7145) : Colors.grey, size: 22),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      _scheduleEnabled ? 'Schedule Active — Countdown Running' : 'Schedule Disabled',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: _scheduleEnabled ? const Color(0xFF1E7145) : Colors.grey.shade600),
                    )),
                    Switch(
                      value: _scheduleEnabled,
                      onChanged: (v) {
                        setState(() => _scheduleEnabled = v);
                        if (v) { _startCountdown(); } else { _stopCountdown(); }
                        _saveConfig();
                      },
                      activeColor: const Color(0xFF1E7145),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),

                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Interval', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _scheduleInterval,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'hourly', child: Text('Every Hour', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'daily',  child: Text('Daily',      style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'manual', child: Text('Manual',     style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (v) {
                        setState(() => _scheduleInterval = v!);
                        if (_scheduleEnabled) _startCountdown();
                      },
                    ),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Time (HH:MM)', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () async {
                        final parts = _scheduleTime.split(':');
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
                        );
                        if (picked != null) {
                          setState(() => _scheduleTime =
                              '${picked.hour.toString().padLeft(2,'0')}:${picked.minute.toString().padLeft(2,'0')}');
                          if (_scheduleEnabled) _startCountdown();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(7)),
                        child: Row(children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(_scheduleTime, style: const TextStyle(fontSize: 13)),
                        ]),
                      ),
                    ),
                  ])),
                ]),
              ])),
              const SizedBox(height: 12),

              // Manual Run
              _card('Manual Run', Icons.play_arrow, Column(children: [
                Text('Import emboss ວັນນີ້ (${_todayFolder()}) ທັນທີ',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: _running ? null : _runNow,
                  icon: _running
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_circle, size: 20),
                  label: Text(_running ? 'ກຳລັງ import...' : 'Run Now',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E7145), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                )),
              ])),

            ]),
          ),
        ),

        // ── Right: Log ───────────────────────────
        Container(
          width: 380,
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
                const Icon(Icons.history, size: 15, color: Color(0xFF4EC9B0)),
                const SizedBox(width: 8),
                const Text('Import Log', style: TextStyle(fontSize: 13, color: Color(0xFFD4D4D4), fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('${_logs.length}', style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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

  Widget _pwField() {
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

  Widget _card(String title, IconData icon, Widget child) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
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

  Widget _statBox(String label, String val, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color), overflow: TextOverflow.ellipsis),
      ]),
    ));
  }
}

class _ScheduleLog {
  final String type, time, msg;
  _ScheduleLog({required this.type, required this.time, required this.msg});

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
