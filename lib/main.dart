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
      TextEditingController(text: 'http://100.67.19.24/Domusius-Github/api');
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

// 3. Hoveddashboard med tandhjul og indstillings-popup
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

  String _siteTitle = 'Solarius - Ærøvej -1';
  String? _aktivtModulNavn;
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
          _aktivtModulNavn = gemtStartModul;
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
            final titleVal = decoded['site_title'] ?? decoded['site_name'];
            if (titleVal != null && titleVal.toString().trim().isNotEmpty) {
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

  void _vaelgModul(String? modulNavn) {
    setState(() {
      _aktivtModulNavn = modulNavn;
    });
  }

  Widget _bygModulIndhold() {
    if (_aktivtModulNavn == null) {
      return _bygRigtigtDashboardTab();
    }

    final navnLower = _aktivtModulNavn!.toLowerCase();

    if (navnLower.contains('bruger')) {
      return BrugerGodkendelseScreen(baseUrl: widget.baseUrl);
    } else if (navnLower.contains('pris')) {
      return ElPriserScreen(baseUrl: widget.baseUrl);
    } else if (navnLower.contains('elbil') || navnLower.contains('bil')) {
      return ElBilQuickScreen(baseUrl: widget.baseUrl);
    } else {
      return StandardModulScreen(modulNavn: _aktivtModulNavn!);
    }
  }

  // ÅBNER INDSTILLINGSLOG (Tandhjuls-menuen)
  void _visIndstillingerDialog() {
    final validModuler =
        _moduler.map((m) => m['name']?.toString() ?? '').toList();
    String midlertidigStartModul =
        (validModuler.contains(_standardModulVedStart) ||
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
                        ..._moduler.map((m) {
                          final mName = m['name']?.toString() ?? '';
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
    return Scaffold(
      body: Column(
        children: [
          // 1. ØVERSTE HVIDE BAR (Titel til venstre, Tandhjul, Bruger & Log ud til højre)
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
                    // TANDHJUL-IKON TIL INDSTILLINGER
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

          // 2. DEN MØRKE MENULINJE NEDEUNDER
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
                        backgroundColor: _aktivtModulNavn == null
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
                    ..._moduler.map((modul) {
                      final navn = modul['name']?.toString() ?? 'Modul';
                      final erValgt = _aktivtModulNavn == navn;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ElevatedButton(
                          onPressed: () => _vaelgModul(navn),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: erValgt
                                ? Colors.blueAccent
                                : const Color(0xFF2C2C3E),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(navn),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),

          // 3. INDHOLD
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

  // RENT DASHBOARD (Uden indstillingsboks, da den nu ligger i tandhjulet)
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
          const Text(
              'Vælg et installeret modul i topmenuen ovenfor for at komme i gang.',
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
                      'Du har ${_moduler.length} aktive moduler installeret i systemet.',
                      style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 16),
                  const Text(
                      'Tip: Klik på tandhjulet øverst til højre for at ændre, hvilket modul der skal åbne automatisk ved start.',
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

// Modul-side: El-priser
class ElPriserScreen extends StatefulWidget {
  final String baseUrl;
  const ElPriserScreen({super.key, required this.baseUrl});

  @override
  State<ElPriserScreen> createState() => _ElPriserScreenState();
}

class _ElPriserScreenState extends State<ElPriserScreen> {
  bool _isLoadingData = true;
  bool _hasData = false;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _hentElPrisData();
  }

  Future<void> _hentElPrisData() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      final response = await http
          .get(Uri.parse('${widget.baseUrl}/hent_elpriser.php'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.isNotEmpty) {
          setState(() {
            _data = Map<String, dynamic>.from(decoded);
            _hasData = true;
            _isLoadingData = false;
          });
        } else {
          setState(() {
            _hasData = false;
            _isLoadingData = false;
          });
        }
      } else {
        setState(() {
          _hasData = false;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasData = false;
        _isLoadingData = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasData) {
      return Center(
        child: Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.engineering,
                    size: 64, color: Colors.orangeAccent),
                const SizedBox(height: 16),
                const Text('Elpriser Modul opdateres',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 8),
                const Text(
                    'Modulet er ved at blive opdateret på serveren,\nså der er ikke noget data at vise endnu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _hentElPrisData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tjek igen'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: _bygStatKort('SENESTE PRIS',
                      _data['seneste_pris']?.toString() ?? '-', false)),
              const SizedBox(width: 16),
              Expanded(
                  child: _bygStatKort('GNS. FOR 2026',
                      _data['gns_aar']?.toString() ?? '-', false)),
              const SizedBox(width: 16),
              Expanded(
                  child: _bygStatKort('GNS. PERIODE',
                      _data['gns_periode']?.toString() ?? '-', true)),
              const SizedBox(width: 16),
              Expanded(
                  child: _bygStatKort('SIDSTE 30 DAGE',
                      _data['sidste_30_dage']?.toString() ?? '-', false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bygStatKort(String titel, String vaerdi, bool isHighlighted) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? Colors.blueAccent : Colors.grey.shade300,
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(titel,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          Text(vaerdi,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
        ],
      ),
    );
  }
}

class ElBilQuickScreen extends StatelessWidget {
  final String baseUrl;
  const ElBilQuickScreen({super.key, required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.electric_car,
                  size: 64, color: Colors.blueAccent),
              const SizedBox(height: 16),
              const Text('Elbil Modul',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 8),
              const Text(
                  'Her kan du registrere kørte kilometer og kW forbrug nemt og hurtigt.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.admin_panel_settings,
                size: 64, color: Colors.blueAccent),
            const SizedBox(height: 16),
            const Text('Brugerstyring & Godkendelse',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            const Text(
                'Her kan administratorer godkende brugere og tildele rettigheder.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class StandardModulScreen extends StatelessWidget {
  final String modulNavn;
  const StandardModulScreen({super.key, required this.modulNavn});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.widgets, size: 64, color: Colors.blueAccent),
            const SizedBox(height: 16),
            Text(modulNavn,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            const Text('Dette modul er installeret og klar til brug.',
                style: TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
