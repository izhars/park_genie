import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:park_genie/presentation/screens/PinSettingsPage.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart'; // For ZIP creation
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:sqflite/sqflite.dart';
import '../../DailyStats.dart';
import '../../DatabaseHelper.dart';
import '../../ManagementScreen.dart';
import '../../TransactionHistory.dart';
import '../../UserProfileScreen.dart';
import '../../data/GateManagementScreen.dart';
import '../../data/services/BuyPackageScreen.dart';
import '../../data/services/FindVehicleHistory.dart';
import '../../data/services/package_details_screen.dart';
import '../../printer/SavedPrintersScreen.dart';

class SettingsScreen extends StatefulWidget {
  final DatabaseHelper dbHelper;

  const SettingsScreen({Key? key, required this.dbHelper}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _syncOnStartup = true;
  bool _darkMode = false;
  String _selectedLanguage = 'English';
  final List<String> _languages = ['English', 'Hindi', 'Spanish', 'French'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('syncOnStartup')) {
      await prefs.setBool('syncOnStartup', true);
    }
    setState(() {
      _syncOnStartup = prefs.getBool('syncOnStartup') ?? true;
      _darkMode = prefs.getBool('darkMode') ?? false;
      _selectedLanguage = prefs.getString('language') ?? 'English';
      debugPrint('Loaded settings - syncOnStartup: $_syncOnStartup, darkMode: $_darkMode, language: $_selectedLanguage');
    });
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('syncOnStartup', _syncOnStartup);
    await prefs.setBool('darkMode', _darkMode);
    await prefs.setString('language', _selectedLanguage);
    debugPrint('Saved settings - syncOnStartup: $_syncOnStartup, darkMode: $_darkMode, language: $_selectedLanguage');
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _buildSectionHeader('App Settings'),
          SwitchListTile(
            title: const Text('Sync on Startup'),
            subtitle: const Text('Automatically sync data when app starts'),
            value: _syncOnStartup,
            onChanged: (value) {
              setState(() {
                _syncOnStartup = value;
                debugPrint('Sync on Startup toggled to: $value');
              });
            },
            secondary: const Icon(Icons.sync),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Enable dark theme for the app'),
            value: _darkMode,
            onChanged: (value) {
              setState(() {
                _darkMode = value;
              });
            },
            secondary: const Icon(Icons.dark_mode),
          ),
          ListTile(
            title: const Text('Language'),
            subtitle: Text(_selectedLanguage),
            leading: const Icon(Icons.language),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showLanguageDialog();
            },
          ),
          const Divider(),
          _buildSectionHeader('Management'),
          ListTile(
            leading: const Icon(Icons.workspace_premium, color: Color(0xFF546E7A)),
            title: const Text('Buy / Upgrade Package'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BuyPackageScreen(dbHelper: widget.dbHelper)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person, color: Color(0xFF546E7A)),
            title: const Text('Manage Profile Detail'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.car_crash, color: Color(0xFF546E7A)),
            title: const Text('Vehicle History'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FindVehicleHistoryScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.car_rental, color: Color(0xFF546E7A)),
            title: const Text('Manage Vehicle, Spaces'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ManagementScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet, color: Color(0xFF546E7A)),
            title: const Text('Transaction History'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TransactionHistory()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.query_stats, color: Color(0xFF546E7A)),
            title: const Text('Daily Statistics'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DailyStats()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.garage_outlined, color: Color(0xFF546E7A)),
            title: const Text('Gate Info'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GateManagementScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.print, color: Color(0xFF546E7A)),
            title: const Text('Printer'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SavedPrintersScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info, color: Color(0xFF546E7A)),
            title: const Text('Package Details'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PackageDetailsScreen(dbHelper: widget.dbHelper)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.key, color: Color(0xFF546E7A)),
            title: const Text('Pin'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PinSettingsPage()),
              );
            },
          ),
          const Divider(),
          _buildSectionHeader('System'),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Clear Cache'),
            subtitle: const Text('Delete temporary files'),
            onTap: () {
              _showClearCacheDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Backup Data'),
            subtitle: const Text('Create a backup of your data'),
            onTap: () {
              _showBackupDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore Data'),
            subtitle: const Text('Restore data from a backup file'),
            onTap: () {
              _showRestoreDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('Debug Preferences'),
            subtitle: const Text('View all stored preferences'),
            onTap: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              debugPrint('All preferences: ${prefs.getKeys().map((key) => '$key: ${prefs.get(key)}').toList()}');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Preferences logged to console')),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Language'),
          content: SizedBox(
            width: double.minPositive,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _languages.length,
              itemBuilder: (BuildContext context, int index) {
                return RadioListTile<String>(
                  title: Text(_languages[index]),
                  value: _languages[index],
                  groupValue: _selectedLanguage,
                  onChanged: (String? value) {
                    setState(() {
                      _selectedLanguage = value!;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Cache'),
          content: const Text('Are you sure you want to clear cache data? This will remove temporary files but not your saved settings or database.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final tempDir = await getTemporaryDirectory();
                  await _clearDirectory(tempDir);
                  debugPrint('Cleared temporary directory: ${tempDir.path}');
                  PaintingBinding.instance.imageCache.clear();
                  debugPrint('Cleared image cache');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cache cleared successfully')),
                  );
                } catch (e) {
                  debugPrint('Error clearing cache: $e');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear cache: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearDirectory(Directory dir) async {
    if (await dir.exists()) {
      await for (var entity in dir.list(recursive: true)) {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      }
    }
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Backup Data'),
          content: const Text('Do you want to backup all application data? The backup will be saved to your device\'s documents directory.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final backupDir = await getApplicationDocumentsDirectory();
                  final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
                  final backupPath = '${backupDir.path}/ParkingAppBackup_$timestamp.zip';
                  debugPrint('Creating backup at: $backupPath');

                  final archive = Archive();

                  // Backup Database
                  final dbPath = join(await getDatabasesPath(), 'parking.db');
                  if (await File(dbPath).exists()) {
                    final dbBytes = await File(dbPath).readAsBytes();
                    archive.addFile(ArchiveFile('parking.db', dbBytes.length, dbBytes));
                    debugPrint('Added database to backup: $dbPath');
                  } else {
                    debugPrint('Database file not found: $dbPath');
                    throw Exception('Database file not found');
                  }

                  // Backup SharedPreferences
                  final prefs = await SharedPreferences.getInstance();
                  final prefsData = prefs.getKeys().fold<Map<String, dynamic>>({}, (map, key) {
                    map[key] = prefs.get(key);
                    return map;
                  });
                  final prefsJson = jsonEncode(prefsData);
                  final prefsBytes = utf8.encode(prefsJson);
                  archive.addFile(ArchiveFile('preferences.json', prefsBytes.length, prefsBytes));
                  debugPrint('Added SharedPreferences to backup');

                  // Save ZIP file
                  final zipEncoder = ZipEncoder();
                  final zipBytes = zipEncoder.encode(archive);
                  if (zipBytes != null) {
                    await File(backupPath).writeAsBytes(zipBytes);
                    debugPrint('Backup saved successfully: $backupPath');
                  } else {
                    throw Exception('Failed to encode ZIP file');
                  }

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Backup created successfully at $backupPath')),
                  );
                } catch (e) {
                  debugPrint('Error creating backup: $e');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to create backup: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Backup'),
            ),
          ],
        );
      },
    );
  }

  void _showRestoreDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Restore Data'),
          content: const Text('Select a backup file to restore. This will overwrite existing data. The app will restart to apply changes.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['zip'],
                  );
                  if (result == null || result.files.single.path == null) {
                    throw Exception('No file selected');
                  }
                  final backupPath = result.files.single.path!;
                  debugPrint('Restoring from: $backupPath');

                  final zipBytes = await File(backupPath).readAsBytes();
                  final archive = ZipDecoder().decodeBytes(zipBytes);

                  // Restore Database
                  final dbFile = archive.findFile('parking.db');
                  if (dbFile != null) {
                    final dbPath = join(await getDatabasesPath(), 'parking.db');
                    await widget.dbHelper.close(); // Close existing database
                    await File(dbPath).writeAsBytes(dbFile.content as List<int>);
                    debugPrint('Restored database to: $dbPath');
                  } else {
                    debugPrint('No database found in backup');
                    throw Exception('No database found in backup');
                  }

                  // Restore SharedPreferences
                  final prefsFile = archive.findFile('preferences.json');
                  if (prefsFile != null) {
                    final prefsJson = utf8.decode(prefsFile.content as List<int>);
                    final prefsData = jsonDecode(prefsJson) as Map<String, dynamic>;
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    prefsData.forEach((key, value) async {
                      if (value is bool) {
                        await prefs.setBool(key, value);
                      } else if (value is String) {
                        await prefs.setString(key, value);
                      } else if (value is int) {
                        await prefs.setInt(key, value);
                      } else if (value is double) {
                        await prefs.setDouble(key, value);
                      } else if (value is List<String>) {
                        await prefs.setStringList(key, value);
                      }
                    });
                    debugPrint('Restored SharedPreferences');
                  } else {
                    debugPrint('No preferences found in backup');
                  }

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data restored successfully. Please restart the app to apply changes.')),
                  );
                } catch (e) {
                  debugPrint('Error restoring backup: $e');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to restore backup: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
  }
}