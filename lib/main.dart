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
                      value: midlertidigStartModul,
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
  int _valgteDage = 1;

  @override
  void initState() {
    super.initState();
    _hentModulLayout(_valgteDage);
  }

  Future<void> _hentModulLayout(int dage) async {
    setState(() {
      _isLoading = true;
      _valgteDage = dage;
    });

    final moduleKey = widget.modulInfo['module_key']?.toString() ?? '';

    String cleanBaseUrl = widget.baseUrl;
    if (cleanBaseUrl.endsWith('/api')) {
      cleanBaseUrl = cleanBaseUrl.substring(0, cleanBaseUrl.length - 4);
    }

    try {
      final url =
          '$cleanBaseUrl/system/modules/$moduleKey/api/api.php?days=$dage';
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          setState(() {
            _components = decoded['components'] ?? [];
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

  void _visOpskriftDetaljerFraItem(Map<String, dynamic> item) {
    final details = item['details'];
    if (details == null) return;

    final title = details['title']?.toString() ?? item['label'] ?? 'Opskrift';
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
                    onPressed: () => _hentModulLayout(_valgteDage),
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
            ..._components.map((comp) => _bygDynamiskKomponent(comp)),
        ],
      ),
    );
  }

  Widget _bygDynamiskKomponent(Map<String, dynamic> comp) {
    final type = comp['type']?.toString() ?? '';

    switch (type) {
      case 'stats_cards':
        final List cards = comp['cards'] ?? [];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: cards.map<Widget>((card) {
              final t = card['title'] ?? '';
              final v = card['value'] ?? '';
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
        final List options = comp['options'] ?? [];
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
                isSelected: options
                    .map<bool>((opt) => opt['value'] == _valgteDage)
                    .toList(),
                onPressed: (index) {
                  final val = options[index]['value'];
                  if (val != null) {
                    _hentModulLayout(val);
                  }
                },
                children: options.map<Widget>((opt) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text(opt['label']?.toString() ?? ''),
                  );
                }).toList(),
              ),
            ],
          ),
        );

      case 'text_block':
        final text = comp['text'] ?? '';
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
        final heading = comp['title'] ?? '';
        final List points = comp['points'] ?? [];

        double maxVal = 4.0;
        for (var p in points) {
          double val = double.tryParse(p['value'].toString()) ?? 0.0;
          if (val > maxVal) maxVal = val;
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
                  height: 220,
                  child: points.isEmpty
                      ? const Center(
                          child: Text('Ingen datapunkter til grafen.'))
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: points.length,
                          itemBuilder: (context, index) {
                            final pt = points[index];
                            final label = pt['label']?.toString() ?? '';
                            double val =
                                double.tryParse(pt['value'].toString()) ?? 0.0;

                            double barHeight = (val / maxVal) * 150;
                            if (barHeight < 10) barHeight = 10;

                            return Container(
                              width: points.length > 14 ? 40 : 60,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '${val.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black54),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: points.length > 14 ? 24 : 36,
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
              ],
            ),
          ),
        );

      case 'chart_line':
        final heading = comp['title'] ?? '';
        final List points = comp['points'] ?? [];

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
                  height: 200,
                  child: points.isEmpty
                      ? const Center(child: Text('Ingen kurvedata fundet.'))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: points.map<Widget>((pt) {
                            final label = pt['label']?.toString() ?? '';
                            final val = pt['value']?.toString() ?? '0';
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(val,
                                    style: const TextStyle(
                                        fontSize: 9, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.teal)),
                                const SizedBox(height: 8),
                                Text(label,
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.black87)),
                              ],
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        );

      case 'progress_bar':
        final label = comp['label'] ?? '';
        double progress = double.tryParse(comp['progress'].toString()) ?? 0.0;
        if (progress > 1.0) progress = progress / 100.0;

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
        final heading = comp['title'] ?? '';
        final List items = comp['items'] ?? [];
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
                  ...items.map<Widget>((item) {
                    final label = item['label']?.toString() ?? '';
                    final value = item['value']?.toString() ?? '';
                    return InkWell(
                      onTap: item['details'] != null
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
                                if (item['details'] != null) ...[
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
