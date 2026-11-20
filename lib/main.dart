import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const DomusiusApp());
}

class DomusiusApp extends StatelessWidget {
  const DomusiusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solarius App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
        cardColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Colors.blueAccent,
          secondary: Colors.tealAccent,
        ),
      ),
      home: const StartupRouter(),
    );
  }
}

class StartupRouter extends StatefulWidget {
  const StartupRouter({super.key});

  @override
  State<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<StartupRouter> {
  bool _isLoading = true;
  String? _baseUrl;
  bool _isLoggedIn = false;
  String _username = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('base_url');
    final loginTime = prefs.getInt('login_timestamp');

    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;

      if (loginTime != null) {
        final loginDate = DateTime.fromMillisecondsSinceEpoch(loginTime);
        final difference = DateTime.now().difference(loginDate).inDays;
        if (difference < 30) {
          _isLoggedIn = true;
          _username = prefs.getString('username') ?? '';
          _role = prefs.getString('role') ?? 'user';
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_baseUrl == null || _baseUrl!.isEmpty) {
      return ConnectionScreen(onConnected: (url) {
        setState(() {
          _baseUrl = url;
        });
      });
    }

    if (!_isLoggedIn) {
      return LoginScreen(
        baseUrl: _baseUrl!,
        onLoggedIn: (username, role) {
          setState(() {
            _isLoggedIn = true;
            _username = username;
            _role = role;
          });
        },
        onChangeUrl: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('base_url');
          setState(() {
            _baseUrl = null;
          });
        },
      );
    }

    return MainDashboardScreen(
      baseUrl: _baseUrl!,
      username: _username,
      role: _role,
      onLogout: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('login_timestamp');
        await prefs.remove('username');
        await prefs.remove('role');
        setState(() {
          _isLoggedIn = false;
        });
      },
    );
  }
}

class ConnectionScreen extends StatefulWidget {
  final Function(String) onConnected;
  const ConnectionScreen({super.key, required this.onConnected});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _urlController =
      TextEditingController(text: 'http://100.67.19.24/Solar/api');
  bool _isLoading = false;
  String _statusMessage = '';

  Future<void> _testAndSaveConnection() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    final url = _urlController.text.trim();

    try {
      final response = await http
          .get(Uri.parse('$url/test_sti.php'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('base_url', url);
        widget.onConnected(url);
      } else {
        setState(() {
          _statusMessage =
              'Server svarede med statuskode ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Kunne ikke oprette forbindelse: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solarius - Forbindelse')),
      body: Center(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.router, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 24),
              const Text('Indtast sti til din API-mappe',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 24),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 16),
              if (_statusMessage.isNotEmpty)
                Text(_statusMessage,
                    style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _testAndSaveConnection,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Forbind til Server',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final String baseUrl;
  final Function(String, String) onLoggedIn;
  final VoidCallback onChangeUrl;

  const LoginScreen({
    super.key,
    required this.baseUrl,
    required this.onLoggedIn,
    required this.onChangeUrl,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/login.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          final user = data['user'];
          final username = user['username']?.toString() ?? '';
          final role = user['role']?.toString() ?? 'user';

          if (_rememberMe) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt(
                'login_timestamp', DateTime.now().millisecondsSinceEpoch);
            await prefs.setString('username', username);
            await prefs.setString('role', role);
          }

          widget.onLoggedIn(username, role);
        } else {
          setState(() {
            _errorMessage = data['message']?.toString() ?? 'Fejl ved login';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Serverfejl (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Kunne ikke oprette forbindelse: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solarius Login'),
        actions: [
          TextButton.icon(
            onPressed: widget.onChangeUrl,
            icon: const Icon(Icons.settings, color: Colors.white70),
            label: const Text('Skift API-sti',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline,
                  size: 80, color: Colors.blueAccent),
              const SizedBox(height: 24),
              const Text('Log ind på Solarius',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 24),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                    labelText: 'Brugernavn', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Adgangskode', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (val) =>
                        setState(() => _rememberMe = val ?? true),
                  ),
                  const Text('Husk mig i 30 dage',
                      style: TextStyle(color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 12),
              if (_errorMessage.isNotEmpty)
                Text(_errorMessage,
                    style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Log ind', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainDashboardScreen extends StatefulWidget {
  final String baseUrl;
  final String username;
  final String role;
  final VoidCallback onLogout;

  const MainDashboardScreen({
    super.key,
    required this.baseUrl,
    required this.username,
    required this.role,
    required this.onLogout,
  });

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  List<dynamic> _moduler = [];
  bool _isLoading = true;
  String _error = '';

  String _siteTitle = 'Solarius';
  String? _aktivtModulNoegle;
  String _standardModulVedStart = 'Dashboard';

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _hentDataFraServer();
    _indlaesStandardModulValg();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _indlaesStandardModulValg() async {
    final prefs = await SharedPreferences.getInstance();
    final gemtStartModul = prefs.getString('standard_modul');
    if (gemtStartModul != null && gemtStartModul.isNotEmpty) {
      setState(() {
        _standardModulVedStart = gemtStartModul;
        if (gemtStartModul != 'Dashboard') {
          _aktivtModulNoegle = gemtStartModul;
        }
      });
    }
  }

  Future<void> _gemStandardModulValg(String modulNavn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('standard_modul', modulNavn);
    setState(() {
      _standardModulVedStart = modulNavn;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Standard start-modul sat til: $modulNavn')),
    );
  }

  Future<void> _hentDataFraServer() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response =
          await http.get(Uri.parse('${widget.baseUrl}/hent_moduler.php'));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          setState(() {
            _moduler = decoded;
            _isLoading = false;
          });
        } else if (decoded is Map) {
          setState(() {
            _moduler = decoded['moduler'] ?? [];
            final titleVal = decoded['site_title'];
            if (titleVal != null &&
                titleVal.toString() != 'null' &&
                titleVal.toString() != 'undefined' &&
                titleVal.toString().trim().isNotEmpty) {
              _siteTitle = titleVal.toString();
            }
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'Ugyldigt dataformat fra server';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Fejl ved hentning af data (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Fejl: $e';
        _isLoading = false;
      });
    }
  }

  void _vaelgModul(String? modulNoegle) {
    setState(() {
      _aktivtModulNoegle = modulNoegle;
    });
  }

  Widget _bygModulIndhold() {
    if (_aktivtModulNoegle == null) {
      return _bygRigtigtDashboardTab();
    }

    final keyLower = _aktivtModulNoegle!.toLowerCase();

    if (keyLower.contains('bruger')) {
      return BrugerGodkendelseScreen(baseUrl: widget.baseUrl);
    } else if (keyLower.contains('moduler')) {
      return ModulStyringScreen(baseUrl: widget.baseUrl, moduler: _moduler);
    } else {
      final match = _moduler.firstWhere(
        (m) =>
            (m['module_key']?.toString().toLowerCase() == keyLower) ||
            (m['menu_title']?.toString().toLowerCase() == keyLower),
        orElse: () => {
          'module_key': _aktivtModulNoegle,
          'menu_title': _aktivtModulNoegle,
          'version': '0.00'
        },
      );
      return StandardModulScreen(
        key: ValueKey(match['module_key'] ?? _aktivtModulNoegle),
        baseUrl: widget.baseUrl,
        modulInfo: match,
      );
    }
  }

  void _visIndstillingerDialog() {
    final valgbareModuler = _moduler
        .map((m) =>
            m['menu_title']?.toString() ?? m['module_key']?.toString() ?? '')
        .toList();
    String midlertidigStartModul =
        (valgbareModuler.contains(_standardModulVedStart) ||
                _standardModulVedStart == 'Dashboard')
            ? _standardModulVedStart
            : 'Dashboard';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings, color: Colors.blueAccent),
              SizedBox(width: 10),
              Text('App Indstillinger'),
            ],
          ),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Vælg standard start-modul:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    const SizedBox(height: 8),
                    const Text(
                        'Dette modul vises automatisk, når du åbner appen fremover.',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: midlertidigStartModul,
                      decoration:
                          const InputDecoration(border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(
                            value: 'Dashboard',
                            child: Text('Dashboard (Startsiden)')),
                        ...valgbareModuler.map((mName) {
                          return DropdownMenuItem(
                            value: mName,
                            child: Text(mName),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            midlertidigStartModul = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuller'),
            ),
            ElevatedButton(
              onPressed: () {
                _gemStandardModulValg(midlertidigStartModul);
                Navigator.pop(context);
              },
              child: const Text('Gem'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final synligeModuler = _moduler.where((modul) {
      final key = (modul['module_key']?.toString() ?? '').toLowerCase();
      bool erInterntSystem = key == 'system' || key == 'kerne-system';
      return !erInterntSystem && modul['menu_title'] != null;
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _siteTitle,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                Row(
                  children: [
                    const Icon(Icons.person, size: 18, color: Colors.black54),
                    const SizedBox(width: 6),
                    Text(widget.username,
                        style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.settings,
                          size: 20, color: Colors.black54),
                      tooltip: 'Indstillinger',
                      onPressed: _visIndstillingerDialog,
                    ),
                    const Text(' | ', style: TextStyle(color: Colors.black38)),
                    TextButton.icon(
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.logout,
                          size: 16, color: Colors.blueAccent),
                      label: const Text('Log ud',
                          style: TextStyle(color: Colors.black87)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            color: const Color(0xFF1E1E2D),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => _vaelgModul(null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _aktivtModulNoegle == null
                            ? Colors.blueAccent
                            : const Color(0xFF2C2C3E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Dashboard'),
                    ),
                    const SizedBox(width: 8),
                    ...synligeModuler.map((modul) {
                      final menuTitel = modul['menu_title']?.toString() ??
                          modul['module_key']?.toString() ??
                          'Modul';
                      final erValgt = _aktivtModulNoegle == menuTitel;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ElevatedButton(
                          onPressed: () => _vaelgModul(menuTitel),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: erValgt
                                ? Colors.blueAccent
                                : const Color(0xFF2C2C3E),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(menuTitel),
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _vaelgModul('Moduler'),
                      icon: const Icon(Icons.extension, size: 16),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _aktivtModulNoegle == 'Moduler'
                            ? Colors.blueAccent
                            : const Color(0xFF2C2C3E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      label: const Text('Moduler'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty
                      ? Center(
                          child: Text(_error,
                              style: const TextStyle(color: Colors.redAccent)))
                      : _bygModulIndhold(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bygRigtigtDashboardTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Velkommen til $_siteTitle',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          const Text('Vælg et modul i topmenuen ovenfor for at komme i gang.',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Systemoversigt',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 8),
                  Text(
                      'Der er hentet ${_moduler.length} aktive moduler/opsætninger dynamisk fra databasen.',
                      style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 16),
                  const Text(
                      'Tip: Klik på tandhjulet øverst til højre for at indstille dit foretrukne start-modul.',
                      style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ModulStyringScreen extends StatelessWidget {
  final String baseUrl;
  final List<dynamic> moduler;

  const ModulStyringScreen(
      {super.key, required this.baseUrl, required this.moduler});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.extension, color: Colors.blueAccent, size: 28),
                  SizedBox(width: 12),
                  Text('Modul Styring',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                  'Hentet direkte fra din `module_settings`-tabel i databasen.',
                  style: TextStyle(color: Colors.black54)),
              const Divider(height: 32),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: moduler.length,
                itemBuilder: (context, index) {
                  final m = moduler[index];
                  final key = m['module_key']?.toString() ?? 'ukendt';
                  final menuTitle = m['menu_title']?.toString() ?? key;
                  final adminTitle = m['admin_menu_title']?.toString() ?? '-';
                  final version = m['version']?.toString() ?? '0.00';

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const ContainerDot(),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(menuTitle,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87)),
                                const SizedBox(height: 4),
                                Text('Nøgle: $key | Admin-titel: $adminTitle',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black54)),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color:
                                      Colors.blueAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text('v$version',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent)),
                            ),
                            const SizedBox(width: 16),
                            const Text('Aktiv',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContainerDot extends StatelessWidget {
  const ContainerDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.green,
      ),
    );
  }
}

class BrugerGodkendelseScreen extends StatelessWidget {
  final String baseUrl;
  const BrugerGodkendelseScreen({super.key, required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.admin_panel_settings,
                size: 64, color: Colors.blueAccent),
            SizedBox(height: 16),
            Text('Brugerstyring & Godkendelse',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            SizedBox(height: 8),
            Text(
                'Her kan administratorer godkende brugere og tildele rettigheder.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class StandardModulScreen extends StatefulWidget {
  final String baseUrl;
  final Map<String, dynamic> modulInfo;

  const StandardModulScreen(
      {super.key, required this.baseUrl, required this.modulInfo});

  @override
  State<StandardModulScreen> createState() => _StandardModulScreenState();
}

class _StandardModulScreenState extends State<StandardModulScreen> {
  bool _isLoading = true;
  List<dynamic> _components = [];
  String _errorMessage = '';

  final Map<String, String> _queryParams = {
    'days': '7',
    'mode': 'days',
  };

  final ScrollController _barScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _hentModulLayout();
  }

  @override
  void dispose() {
    _barScrollController.dispose();
    super.dispose();
  }

  Future<void> _hentModulLayout({Map<String, String>? updates}) async {
    if (updates != null && updates.isNotEmpty) {
      _queryParams.addAll(updates);
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final moduleKey = widget.modulInfo['module_key']?.toString() ?? '';

    String cleanBaseUrl = widget.baseUrl;
    if (cleanBaseUrl.endsWith('/api')) {
      cleanBaseUrl = cleanBaseUrl.substring(0, cleanBaseUrl.length - 4);
    }

    try {
      final uri =
          Uri.parse('$cleanBaseUrl/system/modules/$moduleKey/api/api.php')
              .replace(queryParameters: _queryParams);

      final response = await http.get(uri).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final rawComps = decoded['components'];
          final comps = rawComps is List ? rawComps : <dynamic>[];

          for (final c in comps) {
            if (c is Map) {
              final cType = c['type']?.toString() ?? '';
              if (cType == 'mode_switcher' &&
                  c['selected_mode'] != null &&
                  updates == null) {
                _queryParams['mode'] = c['selected_mode'].toString();
              } else if (cType == 'filter_buttons' &&
                  c['selected_days'] != null &&
                  updates == null) {
                _queryParams['days'] = c['selected_days'].toString();
              } else if (cType == 'comparison_filter' &&
                  c['selected_years'] is List &&
                  (_queryParams['years'] == null ||
                      _queryParams['years']!.isEmpty)) {
                final sel = (c['selected_years'] as List)
                    .map((y) => int.tryParse(y.toString()) ?? 0)
                    .where((y) => y > 0)
                    .toList();
                if (sel.isNotEmpty) {
                  _queryParams['years'] = sel.join(',');
                }
              }
            }
          }

          setState(() {
            _components = comps;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Modul-API returnerede ikke et gyldigt format.';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Kunne ikke indhente data (Status: ${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Forbindelsesfejl: $e';
      });
    }
  }

  void _visOpskriftDetaljerFraItem(Map<dynamic, dynamic> item) {
    final details = item['details'];
    if (details is! Map) return;

    final title =
        details['title']?.toString() ?? item['label']?.toString() ?? 'Opskrift';
    final category = details['category']?.toString() ?? '';
    final time = details['time']?.toString() ?? '';
    final servings = details['servings']?.toString() ?? '';
    final imageUrl = details['image_url']?.toString() ?? '';
    final ingredients = details['ingredients']?.toString() ?? '';
    final instructions = details['instructions']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(
                        imageUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          height: 100,
                          color: Colors.grey.shade200,
                          child: const Center(
                              child: Text('Kunne ikke indlæse billede')),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.access_time,
                                size: 16, color: Colors.black54),
                            const SizedBox(width: 4),
                            Text(time,
                                style: const TextStyle(color: Colors.black54)),
                            const SizedBox(width: 16),
                            const Icon(Icons.people,
                                size: 16, color: Colors.black54),
                            const SizedBox(width: 4),
                            Text(servings,
                                style: const TextStyle(color: Colors.black54)),
                          ],
                        ),
                        const Divider(height: 28),
                        const Text('Ingredienser',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                        const SizedBox(height: 8),
                        Text(ingredients,
                            style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.5)),
                        const SizedBox(height: 20),
                        const Text('Fremgangsmåde',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                        const SizedBox(height: 8),
                        Text(instructions,
                            style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Luk'),
            ),
          ],
        );
      },
    );
  }

  Color _parseHexColor(String? hex, {Color fallback = Colors.black87}) {
    if (hex == null || hex.trim().isEmpty) return fallback;
    final clean = hex.trim().replaceAll('#', '');
    if (clean.length == 6) {
      final parsed = int.tryParse('FF$clean', radix: 16);
      if (parsed != null) return Color(parsed);
    } else if (clean.length == 8) {
      final parsed = int.tryParse(clean, radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.modulInfo['menu_title']?.toString() ??
        widget.modulInfo['module_key']?.toString() ??
        'Modul';
    final version = widget.modulInfo['version']?.toString() ?? '0.00';
    final moduleKey = widget.modulInfo['module_key']?.toString() ?? '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0, left: 4.0, right: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.widgets,
                        size: 22, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    const SizedBox(width: 12),
                    Text('($moduleKey · v$version)',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12)),
                  ],
                ),
                SizedBox(
                  height: 32,
                  width: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: () => _hentModulLayout(),
                    tooltip: 'Genindlæs data',
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_errorMessage.isNotEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(_errorMessage,
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            )
          else if (_components.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                    child:
                        Text('Ingen komponenter defineret af modulet endnu.')),
              ),
            )
          else
            ..._components
                .whereType()
                .map((comp) => _bygDynamiskKomponent(comp)),
        ],
      ),
    );
  }

  Widget _bygDynamiskKomponent(Map<dynamic, dynamic> comp) {
    final type = comp['type']?.toString() ?? '';

    switch (type) {
      case 'mode_switcher':
        final options = comp['options'] is List ? comp['options'] as List : [];
        final currentMode =
            _queryParams['mode'] ?? comp['selected_mode']?.toString() ?? 'days';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.whereType().map<Widget>((opt) {
              final label = opt['label']?.toString() ?? '';
              final val = opt['value']?.toString() ?? 'days';
              return ChoiceChip(
                label: Text(label),
                selected: currentMode == val,
                onSelected: (_) => _hentModulLayout(updates: {'mode': val}),
              );
            }).toList(),
          ),
        );

      case 'stats_cards':
        final cards = comp['cards'] is List ? comp['cards'] as List : [];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: cards.whereType().map<Widget>((card) {
              final t = card['title']?.toString() ?? '';
              final v = card['value']?.toString() ?? '';
              final h = card['highlight'] == true;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: h ? Colors.blueAccent : Colors.grey.shade300,
                          width: h ? 2 : 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text(v,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );

      case 'filter_buttons':
        final options = comp['options'] is List ? comp['options'] as List : [];
        if (options.isEmpty) return const SizedBox.shrink();
        final currentDays = int.tryParse(_queryParams['days'] ?? '') ??
            int.tryParse(comp['selected_days']?.toString() ?? '') ??
            7;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ToggleButtons(
                borderRadius: BorderRadius.circular(8),
                selectedColor: Colors.white,
                fillColor: Colors.blueAccent,
                color: Colors.black87,
                constraints: const BoxConstraints(minHeight: 36, minWidth: 60),
                isSelected: options.whereType().map<bool>((opt) {
                  final optVal = int.tryParse(opt['value'].toString());
                  return optVal == currentDays;
                }).toList(),
                onPressed: (index) {
                  final optList = options.whereType().toList();
                  if (index < optList.length) {
                    final val =
                        int.tryParse(optList[index]['value'].toString());
                    if (val != null) {
                      _hentModulLayout(
                          updates: {'days': val.toString(), 'mode': 'days'});
                    }
                  }
                },
                children: options.whereType().map<Widget>((opt) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text(opt['label']?.toString() ?? ''),
                  );
                }).toList(),
              ),
            ],
          ),
        );

      case 'comparison_filter':
        final availableRaw = comp['available_years'] is List
            ? comp['available_years'] as List
            : [];
        final List<int> availableYears = availableRaw
            .map((y) => int.tryParse(y.toString()) ?? 0)
            .where((y) => y > 0)
            .toList();

        List<int> activeYears = [];
        if (_queryParams['years'] != null &&
            _queryParams['years']!.trim().isNotEmpty) {
          activeYears = _queryParams['years']!
              .split(',')
              .map((y) => int.tryParse(y.trim()) ?? 0)
              .where((y) => y > 0)
              .toList();
        }
        if (activeYears.isEmpty && comp['selected_years'] is List) {
          activeYears = (comp['selected_years'] as List)
              .map((y) => int.tryParse(y.toString()) ?? 0)
              .where((y) => y > 0)
              .toList();
        }
        if (activeYears.isEmpty) {
          activeYears = List<int>.from(availableYears);
        }

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Vælg år:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ...availableYears.map((y) {
                  final checked = activeYears.contains(y);
                  return FilterChip(
                    label: Text('$y'),
                    selected: checked,
                    onSelected: (sel) {
                      final next = List<int>.from(activeYears);
                      if (sel) {
                        if (!next.contains(y)) next.add(y);
                      } else if (next.length > 1) {
                        next.remove(y);
                      }
                      next.sort((a, b) => b.compareTo(a));
                      _hentModulLayout(updates: {
                        'mode': 'comparison',
                        'years': next.join(','),
                      });
                    },
                  );
                }),
              ],
            ),
          ),
        );

      case 'input_form':
        return DynamicInputFormCard(
          comp: comp,
          baseUrl: widget.baseUrl,
          moduleKey: widget.modulInfo['module_key']?.toString() ?? '',
          onSaved: () => _hentModulLayout(),
        );

      case 'chart_comparison':
        final heading = comp['title']?.toString() ?? 'Årssammenligning';
        final labels = comp['labels'] is List
            ? comp['labels'] as List
            : [
                'Jan',
                'Feb',
                'Mar',
                'Apr',
                'Maj',
                'Jun',
                'Jul',
                'Aug',
                'Sep',
                'Okt',
                'Nov',
                'Dec'
              ];
        final series = comp['series'] is List ? comp['series'] as List : [];
        final List<Color> palette = [
          Colors.blueAccent,
          Colors.green,
          Colors.orange,
          Colors.redAccent,
          Colors.purple,
          Colors.teal,
        ];

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heading,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: List.generate(series.length, (i) {
                    final s = series[i];
                    final sLabel =
                        s is Map ? (s['label']?.toString() ?? 'År') : 'År';
                    final color = palette[i % palette.length];
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 16, height: 4, color: color),
                        const SizedBox(width: 6),
                        Text(sLabel,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    );
                  }),
                ),
                const Divider(height: 20),
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _ComparisonLineChartPainter(
                      labels: labels.map((e) => e.toString()).toList(),
                      series: series,
                      palette: palette,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

      case 'chart_comparison_bar':
        final heading = comp['title']?.toString() ?? 'Årssammenligning';
        final labels = comp['labels'] is List
            ? comp['labels'] as List
            : [
                'Jan',
                'Feb',
                'Mar',
                'Apr',
                'Maj',
                'Jun',
                'Jul',
                'Aug',
                'Sep',
                'Okt',
                'Nov',
                'Dec'
              ];
        final series = comp['series'] is List ? comp['series'] as List : [];
        final List<Color> palette = [
          Colors.blueAccent,
          Colors.green,
          Colors.orange,
          Colors.redAccent,
          Colors.purple,
          Colors.teal,
        ];

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heading,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: List.generate(series.length, (i) {
                    final s = series[i];
                    final sLabel =
                        s is Map ? (s['label']?.toString() ?? 'År') : 'År';
                    final color = palette[i % palette.length];
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 14, height: 14, color: color),
                        const SizedBox(width: 6),
                        Text(sLabel,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    );
                  }),
                ),
                const Divider(height: 20),
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _ComparisonBarChartPainter(
                      labels: labels.map((e) => e.toString()).toList(),
                      series: series,
                      palette: palette,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

      case 'text_block':
        final text = comp['text']?.toString() ?? '';
        final isTitle = comp['is_title'] == true;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            text,
            style: TextStyle(
              fontSize: isTitle ? 18 : 14,
              fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
        );

      case 'chart_bar':
        final heading = comp['title']?.toString() ?? '';
        final points = comp['points'] is List ? comp['points'] as List : [];

        double maxVal = 1.0;
        for (var p in points) {
          if (p is Map) {
            double val = double.tryParse(p['value']?.toString() ?? '') ?? 0.0;
            if (val > maxVal) maxVal = val;
          }
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (heading.isNotEmpty) ...[
                  Text(heading,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const Divider(height: 20),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  height: 235,
                  child: points.isEmpty
                      ? const Center(
                          child: Text('Ingen datapunkter til grafen.'))
                      : Scrollbar(
                          controller: _barScrollController,
                          thumbVisibility: true,
                          child: ListView.builder(
                            controller: _barScrollController,
                            scrollDirection: Axis.horizontal,
                            itemCount: points.length,
                            itemBuilder: (context, index) {
                              final pt = points[index];
                              final label = pt is Map
                                  ? (pt['label']?.toString() ?? '')
                                  : '';
                              double val = pt is Map
                                  ? (double.tryParse(
                                          pt['value']?.toString() ?? '') ??
                                      0.0)
                                  : 0.0;

                              double barHeight = (val / maxVal) * 150;
                              if (barHeight < 10) barHeight = 10;

                              return Container(
                                width: points.length > 14 ? 42 : 60,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      val.toStringAsFixed(2),
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black54),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      width: points.length > 14 ? 26 : 36,
                                      height: barHeight,
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      label,
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        );

      case 'chart_line':
        final heading = comp['title']?.toString() ?? '';
        final points = comp['points'] is List ? comp['points'] as List : [];

        double maxVal = 1.0;
        for (var p in points) {
          if (p is Map) {
            final v = double.tryParse(p['value']?.toString() ?? '') ?? 0.0;
            if (v > maxVal) maxVal = v;
          }
        }
        maxVal = ((maxVal * 1.05) / 10000).ceilToDouble() * 10000;
        if (maxVal < 10000) maxVal = 10000;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (heading.isNotEmpty) ...[
                  Text(heading,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const Divider(height: 20),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  height: 270,
                  width: double.infinity,
                  child: points.isEmpty
                      ? const Center(child: Text('Ingen kurvedata fundet.'))
                      : CustomPaint(
                          painter: _SimpleLinePointsPainter(
                            points: points,
                            minVal: 0.0,
                            maxVal: maxVal,
                          ),
                        ),
                ),
              ],
            ),
          ),
        );

      case 'data_table':
        final heading = comp['title']?.toString() ?? '';
        final headers = comp['headers'] is List
            ? (comp['headers'] as List).map((h) => h.toString()).toList()
            : <String>[];
        final rows = comp['rows'] is List ? comp['rows'] as List : [];

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (heading.isNotEmpty) ...[
                  Text(heading,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const Divider(height: 20),
                ],
                if (headers.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: headers.map((h) {
                        return Expanded(
                          child: Text(
                            h,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 4),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Ingen tabeldata fundet.',
                        style: TextStyle(color: Colors.black54)),
                  )
                else
                  ...rows.whereType<List>().map<Widget>((rowCells) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade100),
                        ),
                      ),
                      child: Row(
                        children: List.generate(headers.length, (colIdx) {
                          final cell = colIdx < rowCells.length
                              ? rowCells[colIdx]
                              : null;
                          String text = '';
                          bool bold = false;
                          Color color = Colors.black87;

                          if (cell is Map) {
                            text = cell['text']?.toString() ?? '';
                            bold = cell['bold'] == true;
                            color = _parseHexColor(cell['color']?.toString());
                          } else if (cell != null) {
                            text = cell.toString();
                          }

                          return Expanded(
                            child: Text(
                              text,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    bold ? FontWeight.bold : FontWeight.w500,
                                color: color,
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );

      case 'progress_bar':
        final label = comp['label']?.toString() ?? '';
        double progress =
            double.tryParse(comp['progress']?.toString() ?? '') ?? 0.0;
        if (progress > 1.0) progress = progress / 100.0;
        progress = progress.clamp(0.0, 1.0);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    Text('${(progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  ),
                ),
              ],
            ),
          ),
        );

      case 'data_list':
        final heading = comp['title']?.toString() ?? '';
        final items = comp['items'] is List ? comp['items'] as List : [];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (heading.isNotEmpty) ...[
                  Text(heading,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const Divider(height: 20),
                ],
                if (items.isEmpty)
                  const Text('Ingen data i listen.',
                      style: TextStyle(color: Colors.black54))
                else
                  ...items.whereType().map<Widget>((item) {
                    final label = item['label']?.toString() ?? '';
                    final value = item['value']?.toString() ?? '';
                    final hasDetails = item['details'] is Map;
                    return InkWell(
                      onTap: hasDetails
                          ? () => _visOpskriftDetaljerFraItem(item)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(label,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87)),
                                if (hasDetails) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right,
                                      size: 16, color: Colors.blueAccent),
                                ],
                              ],
                            ),
                            Text(value,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54)),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );

      case 'image_banner':
        final imageUrl = comp['url']?.toString() ?? '';
        if (imageUrl.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
                image: NetworkImage(imageUrl), fit: BoxFit.cover),
          ),
        );

      default:
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Ukendt komponent-type: $type',
              style: const TextStyle(color: Colors.red)),
        );
    }
  }
}

class DynamicInputFormCard extends StatefulWidget {
  final Map<dynamic, dynamic> comp;
  final String baseUrl;
  final String moduleKey;
  final VoidCallback onSaved;

  const DynamicInputFormCard({
    super.key,
    required this.comp,
    required this.baseUrl,
    required this.moduleKey,
    required this.onSaved,
  });

  @override
  State<DynamicInputFormCard> createState() => _DynamicInputFormCardState();
}

class _DynamicInputFormCardState extends State<DynamicInputFormCard> {
  final Map<String, TextEditingController> _formControllers = {};
  final Map<String, String> _formSelectValues = {};
  bool _isFormSubmitting = false;
  String _formFeedback = '';
  bool _formIsError = false;

  List<dynamic> _collectActiveFields() {
    final rawFields = widget.comp['fields'];
    if (rawFields is! List) return <dynamic>[];

    final List<dynamic> activeEntries = [];
    for (final item in rawFields) {
      if (item is! Map) continue;
      final fieldName = item['name']?.toString() ?? '';
      if (fieldName.isEmpty) continue;
      if (item['enabled'] == false) continue;
      activeEntries.add(item);
      if (activeEntries.length >= 10) break;
    }
    return activeEntries;
  }

  List<dynamic> _extractOptions(Map<dynamic, dynamic> fieldDef) {
    final rawOpts = fieldDef['options'];
    if (rawOpts is List) return rawOpts;
    return const <dynamic>[];
  }

  @override
  void initState() {
    super.initState();
    final fields = _collectActiveFields();
    for (final f in fields) {
      final name = f['name']?.toString() ?? '';
      if (name.isEmpty) continue;
      final inputType = f['input_type']?.toString() ?? 'text';
      final defVal = f['default']?.toString() ?? '';

      if (inputType == 'select') {
        final opts = _extractOptions(f);
        if (defVal.isNotEmpty) {
          _formSelectValues[name] = defVal;
        } else if (opts.isNotEmpty && opts.first is Map) {
          _formSelectValues[name] =
              (opts.first as Map)['value']?.toString() ?? '';
        }
      } else {
        _formControllers[name] = TextEditingController(text: defVal);
      }
    }
  }

  @override
  void dispose() {
    for (final ctrl in _formControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _handleFormSubmit() async {
    final endpoint = widget.comp['endpoint']?.toString() ?? '';
    if (endpoint.isEmpty) return;

    setState(() {
      _isFormSubmitting = true;
      _formFeedback = '';
      _formIsError = false;
    });

    final activeFields = _collectActiveFields();
    final Map<String, dynamic> submittedValues = {};
    final List<String> submittedFieldNames = [];
    final List<dynamic> metaEntries = [];

    for (int idx = 0; idx < activeFields.length; idx++) {
      final f = activeFields[idx];
      final name = f['name']?.toString() ?? '';
      if (name.isEmpty) continue;

      final label = f['label']?.toString() ?? name;
      final inputType = f['input_type']?.toString() ?? 'text';
      final slot = int.tryParse(f['slot']?.toString() ?? '') ?? (idx + 1);

      final String val = inputType == 'select'
          ? (_formSelectValues[name] ?? '')
          : (_formControllers[name]?.text.trim() ?? '');

      submittedValues[name] = val;
      submittedFieldNames.add(name);
      metaEntries.add({
        'slot': slot,
        'name': name,
        'label': label,
        'input_type': inputType,
        'value': val,
      });
    }

    final Map<String, dynamic> requestPayload = {
      'module_key': widget.moduleKey,
      'active_field_count': activeFields.length,
      'active_fields': submittedFieldNames,
      'fields_meta': metaEntries,
      'values': submittedValues,
    };

    final hidden = widget.comp['hidden_fields'];
    if (hidden is Map) {
      hidden.forEach((k, v) {
        requestPayload[k.toString()] = v;
      });
    }

    String cleanBase = widget.baseUrl;
    if (cleanBase.endsWith('/api')) {
      cleanBase = cleanBase.substring(0, cleanBase.length - 4);
    }
    final cleanPath =
        endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;

    try {
      final response = await http
          .post(
            Uri.parse('$cleanBase/$cleanPath'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestPayload),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['status'] == 'success') {
          for (final f in activeFields) {
            final name = f['name']?.toString() ?? '';
            final inputType = f['input_type']?.toString() ?? 'text';
            if (inputType == 'number' || inputType == 'integer') {
              _formControllers[name]?.clear();
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    decoded['message']?.toString() ?? 'Data gemt i database.'),
              ),
            );
          }
          widget.onSaved();
        } else {
          setState(() {
            _isFormSubmitting = false;
            _formIsError = true;
            _formFeedback = decoded is Map && decoded['message'] != null
                ? decoded['message'].toString()
                : 'Kunne ikke gemme data.';
          });
        }
      } else {
        setState(() {
          _isFormSubmitting = false;
          _formIsError = true;
          _formFeedback = 'Serverfejl (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _isFormSubmitting = false;
        _formIsError = true;
        _formFeedback = 'Fejl ved gemning: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.comp['title']?.toString() ?? 'Indtast data';
    final submitLabel = widget.comp['submit_label']?.toString() ?? 'Gem';
    final fields = _collectActiveFields();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                Text(
                  '${fields.length} aktive felter',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: fields.map<Widget>((f) {
                final name = f['name']?.toString() ?? '';
                final label = f['label']?.toString() ?? name;
                final inputType = f['input_type']?.toString() ?? 'text';
                final placeholder = f['placeholder']?.toString() ?? '';

                if (inputType == 'select') {
                  final opts = _extractOptions(f);
                  final currentVal = _formSelectValues[name];
                  return SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: currentVal,
                      decoration: InputDecoration(
                        labelText: label,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      items: opts.whereType().map((opt) {
                        final oVal = opt['value']?.toString() ?? '';
                        final oLab = opt['label']?.toString() ?? oVal;
                        return DropdownMenuItem<String>(
                          value: oVal,
                          child: Text(oLab),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _formSelectValues[name] = val;
                          });
                        }
                      },
                    ),
                  );
                }

                final controller = _formControllers[name];
                TextInputType keyboardType = TextInputType.text;
                if (inputType == 'number') {
                  keyboardType =
                      const TextInputType.numberWithOptions(decimal: true);
                } else if (inputType == 'integer') {
                  keyboardType = TextInputType.number;
                }

                return SizedBox(
                  width: 220,
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    decoration: InputDecoration(
                      labelText: label,
                      hintText: placeholder.isNotEmpty ? placeholder : null,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_formFeedback.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _formFeedback,
                style: TextStyle(
                  color:
                      _formIsError ? Colors.redAccent : Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 42,
              child: ElevatedButton.icon(
                onPressed: _isFormSubmitting ? null : _handleFormSubmit,
                icon: _isFormSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(submitLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonLineChartPainter extends CustomPainter {
  final List<String> labels;
  final List<dynamic> series;
  final List<Color> palette;

  _ComparisonLineChartPainter({
    required this.labels,
    required this.series,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPad = 42;
    const double rightPad = 16;
    const double topPad = 14;
    const double bottomPad = 28;

    final double plotW = size.width - leftPad - rightPad;
    final double plotH = size.height - topPad - bottomPad;
    if (plotW <= 10 || plotH <= 10 || labels.isEmpty) return;

    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (final s in series) {
      final vals = s is Map && s['values'] is List ? s['values'] as List : [];
      for (final v in vals) {
        if (v == null) continue;
        final numVal = double.tryParse(v.toString());
        if (numVal != null) {
          if (numVal < minVal) minVal = numVal;
          if (numVal > maxVal) maxVal = numVal;
        }
      }
    }

    if (minVal == double.infinity || maxVal == double.negativeInfinity) {
      minVal = 0;
      maxVal = 3;
    } else {
      minVal = (minVal * 0.85).floorToDouble();
      if (minVal < 0) minVal = 0;
      maxVal = (maxVal * 1.15).ceilToDouble();
      if (maxVal <= minVal) maxVal = minVal + 1;
    }

    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    const int steps = 4;
    for (int i = 0; i <= steps; i++) {
      final frac = i / steps;
      final y = topPad + plotH * (1 - frac);
      canvas.drawLine(
          Offset(leftPad, y), Offset(leftPad + plotW, y), gridPaint);

      final val = minVal + (maxVal - minVal) * frac;
      textPainter.text = TextSpan(
        text: val.toStringAsFixed(1).replaceAll('.', ','),
        style: const TextStyle(fontSize: 10, color: Colors.black54),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftPad - textPainter.width - 6, y - textPainter.height / 2),
      );
    }

    final int count = labels.length;
    final double stepX = count > 1 ? plotW / (count - 1) : plotW;

    for (int i = 0; i < count; i++) {
      final x = leftPad + i * stepX;
      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(fontSize: 10, color: Colors.black87),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, topPad + plotH + 6),
      );
    }

    for (int sIdx = 0; sIdx < series.length; sIdx++) {
      final s = series[sIdx];
      final vals = s is Map && s['values'] is List ? s['values'] as List : [];
      final color = palette[sIdx % palette.length];

      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      Path? path;
      final List<Offset> points = [];

      for (int i = 0; i < count; i++) {
        if (i >= vals.length || vals[i] == null) {
          if (path != null) {
            canvas.drawPath(path, linePaint);
            path = null;
          }
          continue;
        }
        final numVal = double.tryParse(vals[i].toString());
        if (numVal == null) continue;

        final normY = (numVal - minVal) / (maxVal - minVal);
        final x = leftPad + i * stepX;
        final y = topPad + plotH * (1 - normY.clamp(0.0, 1.0));
        final pt = Offset(x, y);
        points.add(pt);

        if (path == null) {
          path = Path()..moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }

      if (path != null) {
        canvas.drawPath(path, linePaint);
      }
      for (final pt in points) {
        canvas.drawCircle(pt, 3.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ComparisonLineChartPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.labels != labels;
  }
}

class _ComparisonBarChartPainter extends CustomPainter {
  final List<String> labels;
  final List<dynamic> series;
  final List<Color> palette;

  _ComparisonBarChartPainter({
    required this.labels,
    required this.series,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPad = 48;
    const double rightPad = 16;
    const double topPad = 14;
    const double bottomPad = 28;

    final double plotW = size.width - leftPad - rightPad;
    final double plotH = size.height - topPad - bottomPad;
    if (plotW <= 10 || plotH <= 10 || labels.isEmpty) return;

    double maxVal = 1.0;
    for (final s in series) {
      final vals = s is Map && s['values'] is List ? s['values'] as List : [];
      for (final v in vals) {
        if (v == null) continue;
        final numVal = double.tryParse(v.toString());
        if (numVal != null && numVal > maxVal) {
          maxVal = numVal;
        }
      }
    }
    maxVal = (maxVal * 1.1).ceilToDouble();

    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    const int steps = 4;
    for (int i = 0; i <= steps; i++) {
      final frac = i / steps;
      final y = topPad + plotH * (1 - frac);
      canvas.drawLine(
          Offset(leftPad, y), Offset(leftPad + plotW, y), gridPaint);

      final val = maxVal * frac;
      textPainter.text = TextSpan(
        text: val.toStringAsFixed(0),
        style: const TextStyle(fontSize: 10, color: Colors.black54),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftPad - textPainter.width - 6, y - textPainter.height / 2),
      );
    }

    final int monthCount = labels.length;
    final int seriesCount = series.isEmpty ? 1 : series.length;
    final double groupSlotW = plotW / monthCount;
    final double groupW = groupSlotW * 0.72;
    final double barW = (groupW / seriesCount).clamp(3.0, 22.0);
    final double totalBarsW = barW * seriesCount;

    for (int m = 0; m < monthCount; m++) {
      final groupCenterX = leftPad + (m + 0.5) * groupSlotW;
      final startX = groupCenterX - (totalBarsW / 2);

      for (int sIdx = 0; sIdx < series.length; sIdx++) {
        final s = series[sIdx];
        final vals = s is Map && s['values'] is List ? s['values'] as List : [];
        if (m >= vals.length || vals[m] == null) continue;
        final numVal = double.tryParse(vals[m].toString());
        if (numVal == null || numVal <= 0) continue;

        final barH = ((numVal / maxVal) * plotH).clamp(2.0, plotH);
        final x = startX + sIdx * barW;
        final y = topPad + plotH - barH;

        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(x, y, barW - 1.5, barH),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        );
        canvas.drawRRect(
          rect,
          Paint()..color = palette[sIdx % palette.length],
        );
      }

      textPainter.text = TextSpan(
        text: labels[m],
        style: const TextStyle(fontSize: 10, color: Colors.black87),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(groupCenterX - textPainter.width / 2, topPad + plotH + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ComparisonBarChartPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.labels != labels;
  }
}

class _SimpleLinePointsPainter extends CustomPainter {
  final List<dynamic> points;
  final double minVal;
  final double maxVal;

  _SimpleLinePointsPainter({
    required this.points,
    required this.minVal,
    required this.maxVal,
  });

  String _formatThousands(double val) {
    final intVal = val.round();
    final str = intVal.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buf.write('.');
      }
      buf.write(str[i]);
    }
    return intVal < 0 ? '-${buf.toString()}' : buf.toString();
  }

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPad = 56;
    const double rightPad = 16;
    const double topPad = 14;
    const double bottomPad = 34;

    final double plotW = size.width - leftPad - rightPad;
    final double plotH = size.height - topPad - bottomPad;
    if (plotW <= 10 || plotH <= 10 || points.isEmpty) return;

    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    const int ySteps = 5;
    final span = (maxVal - minVal) <= 0 ? 1.0 : (maxVal - minVal);

    for (int i = 0; i <= ySteps; i++) {
      final frac = i / ySteps;
      final y = topPad + plotH * (1 - frac);
      canvas.drawLine(
          Offset(leftPad, y), Offset(leftPad + plotW, y), gridPaint);

      final yVal = minVal + span * frac;
      textPainter.text = TextSpan(
        text: _formatThousands(yVal),
        style: const TextStyle(fontSize: 10, color: Colors.black54),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftPad - textPainter.width - 8, y - textPainter.height / 2),
      );
    }

    final int count = points.length;
    final double stepX = count > 1 ? plotW / (count - 1) : plotW / 2;

    final linePaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.fill;

    final Path linePath = Path();
    final Path fillPath = Path();
    final List<Offset> coords = [];

    for (int i = 0; i < count; i++) {
      final pt = points[i];
      final label = pt is Map ? (pt['label']?.toString() ?? '') : '';
      final val = pt is Map
          ? (double.tryParse(pt['value']?.toString() ?? '') ?? 0.0)
          : 0.0;

      final norm = ((val - minVal) / span).clamp(0.0, 1.0);
      final x = count > 1 ? leftPad + i * stepX : leftPad + plotW / 2;
      final y = topPad + plotH * (1 - norm);
      final offset = Offset(x, y);
      coords.add(offset);

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, topPad + plotH);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      if (i == count - 1) {
        fillPath.lineTo(x, topPad + plotH);
        fillPath.close();
      }

      final showLabel = i == count - 1 ||
          (i < count - 2 && (count <= 14 || i == 0 || i % 3 == 0));
      if (showLabel) {
        textPainter.text = TextSpan(
          text: label,
          style: const TextStyle(fontSize: 9.5, color: Colors.black87),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, topPad + plotH + 8),
        );
      }
    }

    if (coords.length > 1) {
      canvas.drawPath(fillPath, fillPaint);
    }
    canvas.drawPath(linePath, linePaint);
    for (final c in coords) {
      canvas.drawCircle(c, 3.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleLinePointsPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.minVal != minVal ||
        oldDelegate.maxVal != maxVal;
  }
}
