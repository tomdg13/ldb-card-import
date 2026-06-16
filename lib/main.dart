import 'package:flutter/material.dart';
import 'screens/import_screen.dart';
import 'screens/sftp_screen.dart';
import 'screens/schedule_screen.dart';

void main() {
  runApp(const LdbCardImportApp());
}

class LdbCardImportApp extends StatelessWidget {
  const LdbCardImportApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LDB Virtual Card Import',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B3A6B)),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.upload_file),
            label: 'Upload File',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_download),
            label: 'SFTP Import',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule),
            label: 'Schedule',
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          ImportScreen(),
          SftpScreen(),
          ScheduleScreen(),
        ],
      ),
    );
  }
}
