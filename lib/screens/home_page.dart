import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:WaledNet/data/servers.dart';
import 'package:WaledNet/services/api_service.dart';
import 'package:WaledNet/theme_provider.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/vpn_service.dart';
import '../services/ad_service.dart';
import '../services/speed_test_service.dart';
import '../services/ssh_tunnel_service.dart';
import '../services/windows_proxy_service.dart';
import '../services/windows_vpn_manager.dart';
import '../services/xray_config_generator.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  late final VpnService _vpnService;
  late final AdService _adService;
  final SpeedTestService _speedTestService = SpeedTestService();

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  V2RayStatus? _status;
  String _buttonText = 'اتصال';
  bool _isLoading = true;
  String _remark = '';
  Map<String, dynamic> _config = {};
  List<VpnServer> _vpnServers = [];
  List<SniProfile> _sniProfiles = [];
  VpnServer? _selectedServer;
  SniProfile? _selectedProfile;
  Timer? _timer;
  int _connectionTime = 0;
  bool _isExtendedConnection = false;
  bool _isAdLoading = false;
  int _peakDownloadSpeedBps = 0;
  int _peakUploadSpeedBps = 0;
  bool _isRewardedAdReady = false;
  bool _isInterstitialAdReady = false;
  Timer? _adLoadTimer;
  String _vpnStatus = 'DISCONNECTED';
  bool _isTestingSpeed = false;
  double? _speedTestResultMbps;
  double? _uploadSpeedTestResultMbps;
  Map<String, int> _serverDelays = {};
  bool _isPingingServers = false;
  bool _isVerifyingConnection = false;
  bool _isConnectionVerified = false;
  bool _isConnectingUserTrigger = false;

  final Uri _telegramUrl = Uri.parse('https://t.me/D_S_D_C1');
  final Uri _subscriptionUrl = Uri.parse('https://t.me/D_S_D_Cbot');
  final Uri _developerUrl = Uri.parse('https://t.me/he_s_en');

  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _lifecycleListener = AppLifecycleListener(
        onExitRequested: () async {
          await WindowsVpnManager.stopVpn();
          return AppExitResponse.exit;
        },
      );
    }
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _vpnService = VpnService(onStatusChanged: _onStatusChanged);
    _adService = AdService(
      onRewardedReadyChanged: (ready) {
        if (mounted) {
          setState(() {
            _isRewardedAdReady = ready;
          });
        }
      },
      onInterstitialReadyChanged: (ready) {
        if (mounted) {
          setState(() {
            _isInterstitialAdReady = ready;
          });
        }
      },
      onAdFailed: _handleAdFailure,
      onRewardedCompleted: () {
        if (mounted) {
          setState(() {
            _isExtendedConnection = true;
            _connectionTime = 24 * 60 * 60;
            _isAdLoading = false;
          });
        }
        _connectToVpn();
      },
    );

    _loadData().then((_) {
      if (Platform.isAndroid || Platform.isIOS) {
        _initializeV2Ray();
        _adService.initialize();

        FirebaseMessaging.instance.getToken().then((token) {
          print("Firebase Messaging Token: $token");
        }).catchError((e) {
          print("Error getting Firebase Messaging Token: $e");
        });

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print('Got a message whilst in the foreground!');
          print('Message data: ${message.data}');

          if (message.notification != null) {
            print(
                'Message also contained a notification: ${message.notification}');
          }
        });
      }
    });
  }

  Future<void> _launchUrl(Uri url) async {
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch ${url.path}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching URL: $e')),
        );
      }
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    print("[_loadData] Starting data load process.");

    bool fetchedFromApi = false;
    try {
      print(
        "[_loadData] Attempting to fetch new data from server...",
      );
      final servers = await ApiService.fetchVlessServers();
      final profiles = await ApiService.fetchSniProfiles();

      if (servers.isNotEmpty && profiles.isNotEmpty) {
        setState(() {
          _vpnServers = [
            VpnServer(
              name: 'سيرفر تجربة SSH (SSL/TLS)',
              url: 'ssh://jdgjdsg43534:jdjjd64646@76.13.39.204:443?ssl=true',
              icon: 'assets/images/server.svg',
            ),
            ...servers,
          ];
          _sniProfiles = profiles;
        });
        await _saveDataToCache();
        await prefs.setInt('last_fetch_time', currentTime);
        print("[_loadData] Data fetched from API and saved to cache.");
        fetchedFromApi = true;
      } else {
        print("[_loadData] API returned empty lists, trying cache.");
      }
    } catch (e) {
      print(
          "[_loadData] Error fetching new data from API: $e. Falling back to cache.");
    }

    if (!fetchedFromApi) {
      await _loadDataFromCache();
      print(
        "[_loadData] After loading from cache: Servers count = ${_vpnServers.length}, SNI profiles count = ${_sniProfiles.length}",
      );
    }

    if (_vpnServers.isEmpty) {
      setState(() {
        _vpnServers = [
          VpnServer(
            name: 'سيرفر تجربة SSH (SSL/TLS)',
            url: 'ssh://jdgjdsg43534:jdjjd64646@76.13.39.204:443?ssl=true',
            icon: 'assets/images/server.svg',
          ),
        ];
        print("[_loadData] _vpnServers was empty, added SSH test server.");
      });
    }
    if (_sniProfiles.isEmpty) {
      setState(() {
        _sniProfiles = [
          SniProfile(name: 'No SNI Profiles Available', sni: '', icon: ''),
        ];
        print("[_loadData] _sniProfiles was empty, added placeholder.");
      });
    }
    print(
      "[_loadData] After ensuring non-empty lists: Servers count = ${_vpnServers.length}, SNI profiles count = ${_sniProfiles.length}",
    );

    await _loadSelections();
    print(
      "[_loadData] After _loadSelections: _selectedServer = ${_selectedServer?.name}, _selectedProfile = ${_selectedProfile?.name}",
    );

    setState(() {
      if (_selectedServer == null && _vpnServers.isNotEmpty) {
        _selectedServer = _vpnServers.first;
        print(
          "[_loadData] Assigned first server as default: ${_selectedServer?.name}",
        );
      }
      if (_selectedProfile == null && _sniProfiles.isNotEmpty) {
        _selectedProfile = _sniProfiles.first;
        print(
          "[_loadData] Assigned first SNI as default: ${_selectedProfile?.name}",
        );
      }
      if (_selectedServer == null) {
        _selectedServer = _vpnServers.first;
        print(
          "[_loadData] _selectedServer still null, fell back to placeholder: ${_selectedServer?.name}",
        );
      }
      if (_selectedProfile == null) {
        _selectedProfile = _sniProfiles.first;
        print(
          "[_loadData] _selectedProfile still null, fell back to placeholder: ${_selectedProfile?.name}",
        );
      }
      _isLoading = false;
    });
    print(
      "[_loadData] Final selected server: ${_selectedServer?.name}, URL: ${_selectedServer?.url}",
    );
    print(
      "[_loadData] Final selected profile: ${_selectedProfile?.name}, SNI: ${_selectedProfile?.sni}",
    );

    if (_selectedServer != null && _getFinalUrl().isNotEmpty) {
      _initializeV2Ray().then((_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _pingAllServers();
          }
        });
      });
      print("[_loadData] Calling _initializeV2Ray after data load.");
    } else {
      print(
        "[_loadData] Not calling _initializeV2Ray because selected server is null or URL is empty.",
      );
    }
  }

  Future<void> _loadDataFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final serversJson = prefs.getString('vpn_servers');
    final profilesJson = prefs.getString('sni_profiles');

    if (serversJson != null) {
      final List<dynamic> serverList = jsonDecode(serversJson);
      setState(() {
        _vpnServers = [
          VpnServer(
            name: 'سيرفر تجربة SSH (SSL/TLS)',
            url: 'ssh://jdgjdsg43534:jdjjd64646@76.13.39.204:443?ssl=true',
            icon: 'assets/images/server.svg',
          ),
          ...serverList.map((json) => VpnServer.fromJson(json)).toList(),
        ];
      });
    }

    if (profilesJson != null) {
      final List<dynamic> profileList = jsonDecode(profilesJson);
      setState(() {
        _sniProfiles =
            profileList.map((json) => SniProfile.fromJson(json)).toList();
      });
    }
  }

  Future<void> _saveDataToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final serversJson = jsonEncode(_vpnServers.map((s) => s.toJson()).toList());
    final profilesJson = jsonEncode(
      _sniProfiles.map((p) => p.toJson()).toList(),
    );

    await prefs.setString('vpn_servers', serversJson);
    await prefs.setString('sni_profiles', profilesJson);
  }

  Future<void> _loadSelections() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('selected_server_url');
    final profileSni = prefs.getString('selected_profile_sni');

    print("[_loadSelections] Attempting to load saved selections.");
    print("[_loadSelections] Saved Server URL: $serverUrl");
    print("[_loadSelections] Saved Profile SNI: $profileSni");

    VpnServer? foundServer;
    if (serverUrl != null && _vpnServers.isNotEmpty) {
      try {
        foundServer = _vpnServers.firstWhere((s) => s.url == serverUrl);
        print("[_loadSelections] Found saved server: ${foundServer.name}");
      } catch (e) {
        print(
          "[_loadSelections] Saved server URL not found in current list: $serverUrl. Error: $e",
        );
      }
    }
    _selectedServer = foundServer;
    print("[_loadSelections] _selectedServer set to: ${_selectedServer?.name}");

    SniProfile? foundProfile;
    if (profileSni != null && _sniProfiles.isNotEmpty) {
      try {
        foundProfile = _sniProfiles.firstWhere((p) => p.sni == profileSni);
        print("[_loadSelections] Found saved profile: ${foundProfile.name}");
      } catch (e) {
        print(
          "[_loadSelections] Saved SNI profile not found in current list: $profileSni. Error: $e",
        );
      }
    }
    _selectedProfile = foundProfile;
    print(
      "[_loadSelections] _selectedProfile set to: ${_selectedProfile?.name}",
    );
  }

  Future<void> _saveSelections() async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedServer != null) {
      await prefs.setString('selected_server_url', _selectedServer!.url);
    }
    if (_selectedProfile != null) {
      await prefs.setString('selected_profile_sni', _selectedProfile!.sni);
    }
  }

  Future<void> _initializeV2Ray() async {
    final originalUrl = _getFinalUrl();
    final url = await _resolveUrlHost(originalUrl);
    print("V2Ray/SSH - Final URL to initialize: $url");

    if (_selectedServer == null || url.isEmpty) {
      print(
        "V2Ray initialization skipped: selected server is null or URL is invalid.",
      );
      return;
    }

    try {
      await _vpnService.initializeV2Ray();
      if (url.startsWith('ssh://')) {
        final sshParams = _parseSshUrl(url);
        final String sshHost = sshParams?['host'] ?? '';
        setState(() {
          _remark = 'SSH Connection';
          _config = _generateSocksV2rayConfig(sshHost);
        });
      } else {
        final v2rayURL = await FlutterV2ray.parseFromURL(url);
        setState(() {
          _remark = v2rayURL.remark;
          final configString = v2rayURL.getFullConfiguration();
          if (configString != null) {
            _config = jsonDecode(configString) as Map<String, dynamic>;
          }
        });
      }
    } catch (e) {
      print("Error initializing V2Ray: $e");
    }
  }

  void _onStatusChanged(V2RayStatus newStatus) async {
    final previousState = _status?.state;
    final newState = newStatus.state;

    if (newState == 'CONNECTED') {
      if (previousState != 'CONNECTED') {
        _peakDownloadSpeedBps = 0;
        _peakUploadSpeedBps = 0;
      }

      if ((newStatus.downloadSpeed ?? 0) > _peakDownloadSpeedBps) {
        _peakDownloadSpeedBps = newStatus.downloadSpeed ?? 0;
      }
      if ((newStatus.uploadSpeed ?? 0) > _peakUploadSpeedBps) {
        _peakUploadSpeedBps = newStatus.uploadSpeed ?? 0;
      }
    }

    if (mounted) {
      setState(() {
        _status = newStatus;
        _vpnStatus = newStatus.state;
        _updateButtonState();
      });
    }

    if (newState == 'CONNECTED' && previousState != 'CONNECTED') {
      _startTimer();
      
      // البدء في التحقق من الاتصال الحقيقي
      setState(() {
        _isConnectionVerified = false;
        _isVerifyingConnection = true;
        _updateButtonState();
      });

      Future.delayed(const Duration(seconds: 5), () async {
        if (!mounted || _status?.state != 'CONNECTED') {
          if (mounted) {
            setState(() {
              _isVerifyingConnection = false;
              _updateButtonState();
            });
          }
          return;
        }

        // نثق بأن V2Ray متصل بالفعل - الفحص الخارجي لا يمر عبر التنل
        if (mounted) {
          setState(() {
            _isVerifyingConnection = false;
            _isConnectionVerified = true;
            _updateButtonState();
          });
          // اهتزاز الهاتف عند نجاح الاتصال الفعلي
          HapticFeedback.vibrate();
          // تشغيل الإعلان البيني فقط (قياس السرعة يدوي بالزر)
          _showInterstitialAd();
        }
      });
    } else if (newState == 'DISCONNECTED' && previousState != 'DISCONNECTED') {
      _stopTimer();
      _isExtendedConnection = false;
      await SshTunnelService().stopTunnel();
      if (mounted) {
        setState(() {
          _isConnectingUserTrigger = false;
          _isConnectionVerified = false;
          _isVerifyingConnection = false;
          _peakDownloadSpeedBps = 0;
          _peakUploadSpeedBps = 0;
        });
      }
    }
  }

  Future<bool> _verifyRealConnection() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(Uri.parse('http://cp.cloudflare.com/generate_204'));
      final response = await request.close();
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      print("[ConnectionVerification] Verification failed: $e");
      return false;
    }
  }

  void _updateButtonState() {
    if (_isVerifyingConnection) {
      _buttonText = 'جاري الاتصال...';
      return;
    }
    
    if (Platform.isWindows) {
      if (_vpnStatus == 'CONNECTED') {
        _buttonText = 'متصل';
      } else if (_vpnStatus == 'CONNECTING') {
        _buttonText = 'جاري الاتصال...';
      } else {
        _buttonText = 'اتصال';
      }
      return;
    }

    switch (_status?.state) {
      case 'CONNECTED':
        _buttonText = _isConnectionVerified ? 'متصل' : 'جاري الاتصال...';
        break;
      case 'CONNECTING':
        _buttonText = 'جاري الاتصال...';
        break;
      case 'DISCONNECTED':
        _buttonText = 'اتصال';
        break;
      default:
        _buttonText = 'اتصال';
        break;
    }
  }

  Future<void> _toggleVpn() async {
    if (_status?.state == 'CONNECTED' || _vpnStatus == 'CONNECTED') {
      if (Platform.isWindows) {
        final originalUrl = _getFinalUrl();
        final url = await _resolveUrlHost(originalUrl);
        final ip = Uri.parse(url).host;
        await WindowsVpnManager.stopVpn(ip);
        await SshTunnelService().stopTunnel();
        _stopTimer();
        if (mounted) {
          setState(() {
            _isConnectionVerified = false;
            _isConnectingUserTrigger = false;
            _vpnStatus = 'DISCONNECTED';
            _status = null;
            _updateButtonState();
          });
        }
      } else {
        await _vpnService.stopV2Ray();
        await SshTunnelService().stopTunnel();
      }
    } else {
      _connectToVpn();
    }
  }

  String _injectVmessSni(String vmessUrl, String sni) {
    try {
      final base64Part = vmessUrl.substring(8).trim();
      String normalizedBase64 = base64Part;
      int mod = base64Part.length % 4;
      if (mod > 0) {
        normalizedBase64 += '=' * (4 - mod);
      }
      final decodedBytes = base64.decode(normalizedBase64);
      final decodedStr = utf8.decode(decodedBytes);
      final Map<String, dynamic> json = jsonDecode(decodedStr);
      
      json['sni'] = sni;
      json['host'] = sni;
      
      final reencodedStr = jsonEncode(json);
      final reencodedBytes = utf8.encode(reencodedStr);
      final reencodedBase64 = base64.encode(reencodedBytes);
      return 'vmess://$reencodedBase64';
    } catch (e) {
      print("[VMess SNI Inject] Error: $e");
      return vmessUrl;
    }
  }

  Map<String, dynamic>? _parseSshUrl(String url) {
    try {
      if (!url.startsWith('ssh://')) return null;
      final uri = Uri.parse(url);
      
      final String host = uri.host;
      final int port = uri.port != 0 ? uri.port : 22;
      
      String username = '';
      String password = '';
      if (uri.userInfo.isNotEmpty) {
        final parts = uri.userInfo.split(':');
        username = parts[0];
        if (parts.length > 1) {
          password = Uri.decodeComponent(parts[1]);
        }
      }
      
      final bool useWs = uri.queryParameters['ws'] == 'true';
      final bool useSsl = uri.queryParameters['ssl'] == 'true';
      final String wsPath = uri.queryParameters['ws_path'] ?? '/';
      
      return {
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'useWs': useWs,
        'useSsl': useSsl,
        'wsPath': wsPath,
      };
    } catch (e) {
      print("Error parsing SSH URL: $e");
      return null;
    }
  }

  Map<String, dynamic> _generateSocksV2rayConfig(String sshHost) {
    return {
      "log": {"loglevel": "warning"},
      "dns": {
        "servers": [
          "https://1.1.1.1/dns-query",
          "https://8.8.8.8/dns-query"
        ]
      },
      "inbounds": [
        {
          "port": 10808,
          "protocol": "socks",
          "settings": {
            "auth": "noauth",
            "udp": true
          },
          "sniffing": {
            "enabled": true,
            "destOverride": ["http", "tls"]
          }
        }
      ],
      "outbounds": [
        {
          "protocol": "socks",
          "tag": "proxy",
          "settings": {
            "servers": [
              {
                "address": "127.0.0.1",
                "port": 10809
              }
            ]
          }
        },
        {
          "protocol": "freedom",
          "tag": "direct",
          "settings": {}
        },
        {
          "protocol": "dns",
          "tag": "dns-out"
        }
      ],
      "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
          {
            "type": "field",
            "port": 53,
            "outboundTag": "dns-out"
          },
          {
            "type": "field",
            "ip": [sshHost],
            "outboundTag": "direct"
          },
          {
            "type": "field",
            "domain": [sshHost],
            "outboundTag": "direct"
          }
        ]
      }
    };
  }

  String _getFinalUrl() {
    if (_selectedServer == null) return '';
    String finalUrl = _selectedServer!.url;
    if (_selectedProfile != null) {
      if (finalUrl.startsWith('vmess://') && !finalUrl.contains('?')) {
        return _injectVmessSni(finalUrl, _selectedProfile!.sni);
      } else {
        try {
          Uri originalUri = Uri.parse(finalUrl);
          var queryParams = Map<String, String>.from(originalUri.queryParameters);
          queryParams['host'] = _selectedProfile!.sni;
          queryParams['sni'] = _selectedProfile!.sni;
          finalUrl = originalUri.replace(queryParameters: queryParams).toString();
        } catch (e) {
          print(
            "Error parsing or replacing URL parts in _getFinalUrl: $e",
          );
          return _selectedServer!.url;
        }
      }
    }
    print("V2Ray/SSH - Constructed final URL: $finalUrl");
    return finalUrl;
  }

  Future<String> _resolveDomain(String domain) async {
    // 1. Try standard lookup
    try {
      final list = await InternetAddress.lookup(domain).timeout(const Duration(seconds: 2));
      if (list.isNotEmpty) {
        return list.first.address;
      }
    } catch (_) {}

    // 2. Try DNS over HTTPS (DoH) via Cloudflare
    try {
      final response = await http.get(
        Uri.parse('https://cloudflare-dns.com/dns-query?name=$domain&type=A'),
        headers: {'accept': 'application/dns-json'},
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final answers = data['Answer'] as List?;
        if (answers != null && answers.isNotEmpty) {
          for (var answer in answers) {
            if (answer['type'] == 1) { // A record
              return answer['data'].toString().trim();
            }
          }
        }
      }
    } catch (_) {}

    // 3. Hardcoded fallback for waled.online
    if (domain == 'waled.online') {
      return '72.62.236.79';
    }

    return domain;
  }

  Future<String> _resolveUrlHost(String url) async {
    try {
      if (url.isEmpty) return url;
      final uri = Uri.parse(url);
      final host = uri.host;
      if (host.isEmpty) return url;
      
      // If host is already an IP, don't resolve
      if (RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host)) {
        return url;
      }
      
      final ip = await _resolveDomain(host);
      if (ip == host) return url;
      
      final updatedUri = uri.replace(host: ip);
      return updatedUri.toString();
    } catch (e) {
      print("Error resolving URL host: $e");
      return url;
    }
  }

  String _getFinalUrlForServer(VpnServer server) {
    if (server.url.isEmpty) return '';
    String finalUrl = server.url;
    if (_selectedProfile != null) {
      if (finalUrl.startsWith('vmess://') && !finalUrl.contains('?')) {
        return _injectVmessSni(finalUrl, _selectedProfile!.sni);
      } else {
        try {
          Uri originalUri = Uri.parse(finalUrl);
          var queryParams = Map<String, String>.from(originalUri.queryParameters);
          queryParams['host'] = _selectedProfile!.sni;
          queryParams['sni'] = _selectedProfile!.sni;
          finalUrl = originalUri.replace(queryParameters: queryParams).toString();
        } catch (e) {
          print("Error in _getFinalUrlForServer: $e");
        }
      }
    }
    return finalUrl;
  }

  Future<void> _pingAllServers() async {
    if (_vpnServers.isEmpty || _isPingingServers) return;

    setState(() {
      _isPingingServers = true;
    });

    try {
      await _vpnService.initializeV2Ray();
      
      for (final server in _vpnServers) {
        if (!mounted) break;
        if (server.url.isEmpty || server.name == 'No Servers Available' || server.name == 'Loading...') continue;
        
        try {
          final finalUrl = _getFinalUrlForServer(server);
          if (finalUrl.startsWith('ssh://')) {
            final sshParams = _parseSshUrl(finalUrl);
            if (sshParams != null) {
              final stopwatch = Stopwatch()..start();
              final socket = await Socket.connect(
                sshParams['host'],
                sshParams['port'],
                timeout: const Duration(seconds: 4),
              );
              stopwatch.stop();
              socket.destroy();
              if (mounted) {
                setState(() {
                  _serverDelays[server.url] = stopwatch.elapsedMilliseconds;
                });
              }
            }
          } else {
            final v2rayURL = await FlutterV2ray.parseFromURL(finalUrl);
            final configString = v2rayURL.getFullConfiguration();
            if (configString != null) {
              final delay = await _vpnService.getServerDelay(config: configString);
              if (mounted) {
                setState(() {
                  _serverDelays[server.url] = delay;
                });
              }
            }
          }
        } catch (e) {
          print('Error pinging server ${server.name}: $e');
          if (mounted) {
            setState(() {
              _serverDelays[server.url] = -1;
            });
          }
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      print('Error in _pingAllServers: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPingingServers = false;
        });
      }
    }
  }

  void _handleSelectionChange<T>(T? value) {
    setState(() {
      if (value is VpnServer) {
        _selectedServer = value;
      } else if (value is SniProfile) {
        _selectedProfile = value;
        _serverDelays.clear();
      }
      _isLoading = true;
    });
    _saveSelections();
    _initializeV2Ray().then((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (value is SniProfile) {
          _pingAllServers();
        }
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_connectionTime > 0) {
        setState(() {
          _connectionTime--;
        });
      } else {
        timer.cancel();
        if (_status?.state == 'CONNECTED' || _vpnStatus == 'CONNECTED') {
          _toggleVpn();
        }
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _connectionTime = 0;
    });
  }

  String _formatSpeed(int? bps) {
    if (bps == null || bps < 0) return '0.00 KB/s';
    if (_vpnStatus != 'CONNECTED') return '---';
    if (bps == 0 && _connectionTime < 3) return '...';

    double speedInMBs = bps / (1024 * 1024);

    if (speedInMBs < 0.1) {
      double speedInKBs = bps / 1024;
      return '${speedInKBs.toStringAsFixed(2)} KB/s';
    } else {
      return '${speedInMBs.toStringAsFixed(2)} MB/s';
    }
  }

  void _showInterstitialAd() {
    _adService.showInterstitialAd();
  }

  void _handleAdFailure(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
      setState(() {
        _isAdLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.themeData;
    final isConnected = _status?.state == 'CONNECTED' || 
                        _status?.state == 'CONNECTING' || 
                        _isVerifyingConnection ||
                        _isConnectingUserTrigger ||
                        _vpnStatus == 'CONNECTED' ||
                        _vpnStatus == 'CONNECTING';

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: _buildAppBar(themeProvider),
      body: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          gradient: themeProvider.isDarkMode
              ? const RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.2,
                  colors: [
                    Color(0xFF0C1030), // Extremely subtle dark blue tint at the center
                    Color(0xFF000000), // True black background
                  ],
                )
              : null,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxHeight;

                // We use the exact original spacings when disconnected,
                // and compact spacings when connected to slide them up.
                final double topSpace = isConnected ? 4 : 24;
                final double middleSpace = isConnected ? 16 : 36;
                final double bottomSpace = isConnected ? 12 : 24;

                Widget content = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: topSpace),
                    _buildConnectButton(),
                    SizedBox(height: middleSpace),
                    _buildConnectionDetails(),
                    SizedBox(height: bottomSpace),
                  ],
                );

                // Allow scrolling only when connected (to accommodate the speed test button) 
                // and on small screens to prevent layout overflow.
                final bool allowScroll = isConnected || height < 640;

                return SingleChildScrollView(
                  physics: allowScroll 
                      ? const BouncingScrollPhysics() 
                      : const NeverScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: height,
                    ),
                    child: Container(
                      alignment: isConnected ? Alignment.topCenter : Alignment.center,
                      child: content,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(ThemeProvider themeProvider) {
    final theme = themeProvider.themeData;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'contact_us') {
            _launchUrl(_telegramUrl);
          } else if (value == 'subscribe') {
            _launchUrl(_subscriptionUrl);
          } else if (value == 'developer') {
            _launchUrl(_developerUrl);
          }
        },
        icon: Icon(Icons.menu_rounded, color: theme.iconTheme.color, size: 28),
        color: theme.cardTheme.color,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: themeProvider.isDarkMode
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
            width: 1.5,
          ),
        ),
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'contact_us',
            child: Row(
              children: [
                const Icon(
                  Icons.contact_support_outlined,
                  color: Color(0xFF007AFF), // iOS Blue
                ),
                const SizedBox(width: 12),
                Text(
                  'تواصل معنا',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'subscribe',
            child: Row(
              children: [
                const Icon(
                  Icons.workspace_premium_outlined,
                  color: Color(0xFFFF9500), // iOS Orange
                ),
                const SizedBox(width: 12),
                Text(
                  'اشتراك (بدون إعلانات)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'developer',
            child: Row(
              children: [
                const Icon(
                  Icons.code_rounded,
                  color: Color(0xFF5856D6), // iOS Purple
                ),
                const SizedBox(width: 12),
                Text(
                  r'المطور :7𝖊$𝖊𝒏',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      title: Text(
        'WaledNet',
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.telegram, color: Color(0xFF007AFF)),
          iconSize: 28,
          onPressed: () => _launchUrl(_telegramUrl),
        ),
        IconButton(
          icon: Icon(
            themeProvider.isDarkMode
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
          ),
          iconSize: 26,
          color: theme.iconTheme.color,
          onPressed: () => themeProvider.toggleTheme(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildConnectButton() {
    final isConnected = _status?.state == 'CONNECTED' || _vpnStatus == 'CONNECTED';
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    final Color activeColor = theme.colorScheme.primary; // Apple Blue
    final Color inactiveColor = themeProvider.isDarkMode ? Colors.white : Colors.black87;

    final bool isButtonLoading = _isLoading ||
        (_isAdLoading && !isConnected) ||
        (_status?.state == 'CONNECTING') ||
        _isVerifyingConnection;

    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            double scale = 1.0;
            if (isConnected || isButtonLoading) {
              scale = _pulseAnimation.value;
            }
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer glowing aura
                Container(
                  width: 190 * scale,
                  height: 190 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected
                        ? activeColor.withOpacity(0.12)
                        : isButtonLoading
                            ? activeColor.withOpacity(0.06)
                            : Colors.transparent,
                  ),
                ),
                // Inner button
                GestureDetector(
                  onTap: (isButtonLoading || _isLoading) ? null : _toggleVpn,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isConnected
                          ? LinearGradient(
                              colors: [activeColor, activeColor.withBlue(255)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: themeProvider.isDarkMode
                                  ? [const Color(0xFF2C2C2E), const Color(0xFF1C1C1E)]
                                  : [Colors.white, const Color(0xFFE5E5EA)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: isConnected
                              ? activeColor.withOpacity(0.4)
                              : Colors.black.withOpacity(themeProvider.isDarkMode ? 0.3 : 0.08),
                          blurRadius: isConnected ? 25 : 15,
                          spreadRadius: isConnected ? 2 : 0,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(
                        color: isConnected
                            ? Colors.white.withOpacity(0.2)
                            : themeProvider.isDarkMode
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.03),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isButtonLoading
                          ? CircularProgressIndicator(
                              color: isConnected ? Colors.white : activeColor,
                              strokeWidth: 4,
                            )
                          : Icon(
                              Icons.power_settings_new_rounded,
                              size: 55,
                              color: isConnected ? Colors.white : inactiveColor,
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        // Status Text
        Text(
          _isAdLoading && _status?.state != 'CONNECTED' ? 'جاري تحميل الإعلان...' : _buttonText,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            fontSize: 22,
            color: isConnected ? activeColor : inactiveColor,
          ),
        ),
        const SizedBox(height: 12),
        // Timer Widget in an elegant capsule
        if (isConnected && _isConnectionVerified)
          AnimatedOpacity(
            opacity: (isConnected && _isConnectionVerified) ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: activeColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: activeColor.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '${(_connectionTime ~/ 3600).toString().padLeft(2, '0')}:${((_connectionTime % 3600) ~/ 60).toString().padLeft(2, '0')}:${(_connectionTime % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontFamily: 'monospace', // clean monospaced font
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildConnectionDetails() {
    final isConnected = _status?.state == 'CONNECTED' || _status?.state == 'CONNECTING';
    return Column(
      children: [
        _buildSelectionMenus(),
        SizedBox(height: isConnected ? 12 : 20),
        _buildStatusDetails(),
      ],
    );
  }

  Widget _buildSelectionMenus() {
    return Column(
      children: [
        _buildSelectionTile(
          label: 'السيرفر المختار',
          title: _selectedServer?.name ?? 'Loading...',
          icon: Icons.dns_rounded,
          iconColor: const Color(0xFF007AFF), // iOS Blue
          iconBgColor: const Color(0xFF007AFF).withOpacity(0.12),
          onTap: _showServerBottomSheet,
          trailing: _buildSelectedServerPingWidget(),
        ),
        const SizedBox(height: 12),
        _buildSelectionTile(
          label: 'حزمة الشبكة (SNI)',
          title: _selectedProfile?.name ?? 'Loading...',
          icon: Icons.shield_outlined,
          iconColor: const Color(0xFF5856D6), // iOS Purple
          iconBgColor: const Color(0xFF5856D6).withOpacity(0.12),
          onTap: _showProfileBottomSheet,
        ),
      ],
    );
  }

  Widget _buildSelectionTile({
    required String label,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    final bool isDisabled = _isLoading;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: themeProvider.isDarkMode
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.03),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(themeProvider.isDarkMode ? 0.1 : 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ] else ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3),
                size: 24,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedServerPingWidget() {
    if (_selectedServer == null) return const Text('...');
    final delay = _serverDelays[_selectedServer!.url];
    Color delayColor;
    String delayText;
    if (delay == null) {
      delayText = '...';
      delayColor = Colors.grey;
    } else if (delay == -1 || delay == 0) {
      delayText = 'Offline';
      delayColor = const Color(0xFFFF3B30); // iOS Red
    } else {
      delayText = '${delay}ms';
      if (delay < 150) {
        delayColor = const Color(0xFF34C759); // iOS Green
      } else if (delay < 300) {
        delayColor = const Color(0xFFFF9500); // iOS Orange
      } else {
        delayColor = const Color(0xFFFF3B30); // iOS Red
      }
    }

    if (_isPingingServers) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2.0),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: delayColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        delayText,
        style: TextStyle(
          color: delayColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showServerBottomSheet() {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(32),
            ),
            border: Border.all(
              color: themeProvider.isDarkMode
                  ? Colors.white.withOpacity(0.08)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // iOS Style Drag Handle
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode
                      ? Colors.white.withOpacity(0.2)
                      : Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'اختر السيرفر المناسب',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              Divider(
                height: 1,
                color: themeProvider.isDarkMode
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.06),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _vpnServers.length,
                  itemBuilder: (context, index) {
                    final server = _vpnServers[index];
                    final isSelected = _selectedServer == server;
                    final delay = _serverDelays[server.url];
                    
                    Color delayColor;
                    String delayText;
                    if (delay == null) {
                      delayText = '...';
                      delayColor = Colors.grey;
                    } else if (delay == -1 || delay == 0) {
                      delayText = 'Offline';
                      delayColor = const Color(0xFFFF3B30); // iOS Red
                    } else {
                      delayText = '${delay}ms';
                      if (delay < 150) {
                        delayColor = const Color(0xFF34C759); // iOS Green
                      } else if (delay < 300) {
                        delayColor = const Color(0xFFFF9500); // iOS Orange
                      } else {
                        delayColor = const Color(0xFFFF3B30); // iOS Red
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? theme.colorScheme.primary.withOpacity(0.08) 
                            : theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected 
                              ? theme.colorScheme.primary.withOpacity(0.4) 
                              : themeProvider.isDarkMode
                                  ? Colors.white.withOpacity(0.03)
                                  : Colors.black.withOpacity(0.03),
                          width: 1.5,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          onTap: () {
                            Navigator.pop(context);
                            _handleSelectionChange<VpnServer>(server);
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.dns_rounded,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            server.name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 15,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: delayColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  delayText,
                                  style: TextStyle(
                                    color: delayColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 22,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showProfileBottomSheet() {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(32),
            ),
            border: Border.all(
              color: themeProvider.isDarkMode
                  ? Colors.white.withOpacity(0.08)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // iOS Style Drag Handle
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode
                      ? Colors.white.withOpacity(0.2)
                      : Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'اختر الحزمة (SNI Profile)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              Divider(
                height: 1,
                color: themeProvider.isDarkMode
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.06),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _sniProfiles.length,
                  itemBuilder: (context, index) {
                    final profile = _sniProfiles[index];
                    final isSelected = _selectedProfile == profile;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? theme.colorScheme.primary.withOpacity(0.08) 
                            : theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected 
                              ? theme.colorScheme.primary.withOpacity(0.4) 
                              : themeProvider.isDarkMode
                                  ? Colors.white.withOpacity(0.03)
                                  : Colors.black.withOpacity(0.03),
                          width: 1.5,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          onTap: () {
                            Navigator.pop(context);
                            _handleSelectionChange<SniProfile>(profile);
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.shield_outlined,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            profile.name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            profile.sni.isEmpty ? 'حزمة افتراضية' : profile.sni,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 22,
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusDetails() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final theme = themeProvider.themeData;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: themeProvider.isDarkMode
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.03),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(themeProvider.isDarkMode ? 0.1 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withOpacity(0.12), // iOS Blue
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_downward_rounded,
                        color: Color(0xFF007AFF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تحميل (Download)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _buildSpeedInfoWidget('Download', themeProvider.isDarkMode),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                height: 35,
                width: 1,
                color: themeProvider.isDarkMode
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.08),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'رفع (Upload)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _buildSpeedInfoWidget('Upload', themeProvider.isDarkMode),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759).withOpacity(0.12), // iOS Green
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Color(0xFF34C759),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_vpnStatus == 'CONNECTED') ...[
            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: themeProvider.isDarkMode
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.06),
            ),
            const SizedBox(height: 16),
            _buildSpeedTestButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildSpeedTestButton() {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isTestingSpeed ? null : _runSpeedTest,
        icon: _isTestingSpeed
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: themeProvider.isDarkMode ? Colors.white : theme.colorScheme.primary,
                ),
              )
            : const Icon(Icons.speed_rounded, size: 20),
        label: Text(
          _isTestingSpeed ? 'جاري القياس...' : 'فحص سرعة الاتصال',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: theme.colorScheme.primary.withOpacity(0.5),
          disabledForegroundColor: Colors.white.withOpacity(0.8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedInfoWidget(String label, bool isDarkMode) {
    final theme = Theme.of(context);

    if (_isTestingSpeed) {
      return const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(strokeWidth: 2.0),
      );
    }

    String textToShow = "-";
    double? result;

    if (label == 'Download') {
      result = _speedTestResultMbps;
    } else if (label == 'Upload') {
      result = _uploadSpeedTestResultMbps;
    }

    if (result != null) {
      if (result == -1) {
        textToShow = "Error";
      } else {
        textToShow = '${result.toStringAsFixed(2)} Mbps';
      }
    }

    return Text(
      textToShow,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }

  Future<void> _connectToVpn() async {
    if (!mounted) return;
    setState(() {
      _isConnectingUserTrigger = true;
    });

    final originalUrl = _getFinalUrl();
    final url = await _resolveUrlHost(originalUrl);

    // On Windows, bypass VPN permission requests
    bool hasPermission = true;
    if (Platform.isAndroid || Platform.isIOS) {
      hasPermission = await _vpnService.requestPermission();
    }

    if (hasPermission) {
      setState(() {
        _isExtendedConnection = true;
        _connectionTime = 24 * 60 * 60;
      });

      if (Platform.isWindows) {
        final ip = Uri.parse(url).host;
        if (url.startsWith('ssh://')) {
          final sshParams = _parseSshUrl(url);
          if (sshParams == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid SSH Server Configuration')),
            );
            setState(() {
              _isConnectingUserTrigger = false;
            });
            return;
          }

          try {
            setState(() {
              _isVerifyingConnection = true;
              _buttonText = 'جاري الاتصال وتجهيز الشبكة...';
            });
            
            await SshTunnelService().startTunnel(
              host: sshParams['host'],
              port: sshParams['port'],
              username: sshParams['username'],
              password: sshParams['password'],
              useSsl: sshParams['useSsl'],
              useWs: sshParams['useWs'],
              wsPath: sshParams['wsPath'],
              sni: _selectedProfile?.sni,
              localPort: 10809,
            );

            await WindowsVpnManager.startVpn(type: 'ssh', serverIp: ip);

            if (mounted) {
              setState(() {
                _isVerifyingConnection = false;
                _isConnectionVerified = true;
                _vpnStatus = 'CONNECTED';
                _buttonText = 'متصل';
              });
              _startTimer();
              HapticFeedback.vibrate();
            }
          } catch (e) {
            setState(() {
              _isConnectingUserTrigger = false;
              _isVerifyingConnection = false;
              _updateButtonState();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('SSH Tunnel Connection Failed: \$e')),
            );
            return;
          }
        } else if (url.startsWith('vless://')) {
          try {
            setState(() {
              _isVerifyingConnection = true;
              _buttonText = 'جاري الاتصال وتجهيز الشبكة...';
            });

            final configJson = XrayConfigGenerator.generateConfig(url);
            await WindowsVpnManager.startVpn(type: 'vless', serverIp: ip, xrayConfigJson: configJson);

            if (mounted) {
              setState(() {
                _isVerifyingConnection = false;
                _isConnectionVerified = true;
                _vpnStatus = 'CONNECTED';
                _buttonText = 'متصل';
              });
              _startTimer();
              HapticFeedback.vibrate();
            }
          } catch (e) {
            setState(() {
              _isConnectingUserTrigger = false;
              _isVerifyingConnection = false;
              _updateButtonState();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('VLESS Connection Failed: \$e')),
            );
            return;
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Only SSH and VLESS are supported on Windows currently.')),
          );
          setState(() {
            _isConnectingUserTrigger = false;
          });
          return;
        }
        return;
      }

      if (url.startsWith('ssh://')) {
        final sshParams = _parseSshUrl(url);
        if (sshParams == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid SSH Server Configuration')),
          );
          return;
        }

        try {
          setState(() {
            _isVerifyingConnection = true;
            _buttonText = 'جاري الاتصال...';
          });
          
          await SshTunnelService().startTunnel(
            host: sshParams['host'],
            port: sshParams['port'],
            username: sshParams['username'],
            password: sshParams['password'],
            useSsl: sshParams['useSsl'],
            useWs: sshParams['useWs'],
            wsPath: sshParams['wsPath'],
            sni: _selectedProfile?.sni,
            localPort: 10809,
          );
        } catch (e) {
          setState(() {
            _isConnectingUserTrigger = false;
            _isVerifyingConnection = false;
            _updateButtonState();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('SSH Tunnel Connection Failed: $e')),
          );
          return;
        }
      }

      List<String>? bypassSubnets;
      if (url.startsWith('ssh://')) {
        final String vpnIp = Uri.parse(url).host;
        if (RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(vpnIp)) {
          bypassSubnets = [vpnIp];
        }
      }

      await _vpnService.startV2Ray(
        remark: url.startsWith('ssh://') ? 'WaledNet SSH: متصل وآمن 🛡️' : 'WaledNet VPN: متصل وآمن 🛡️',
        config: jsonEncode(_config),
        bypassSubnets: bypassSubnets,
      );
    } else {
      if (mounted) {
        setState(() {
          _isConnectingUserTrigger = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('VPN permission not granted')),
        );
      }
    }
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _pulseController.dispose();
    _timer?.cancel();
    _adLoadTimer?.cancel();
    super.dispose();
  }

  Future<void> _runSpeedTest() async {
    if (_isTestingSpeed) return;

    setState(() {
      _isTestingSpeed = true;
      _speedTestResultMbps = null;
      _uploadSpeedTestResultMbps = null;
    });

    final downloadResult = await _speedTestService.runDownloadTest();
    if (mounted) {
      setState(() {
        _speedTestResultMbps = downloadResult;
      });
    }

    final uploadResult = await _speedTestService.runUploadTest();
    if (mounted) {
      setState(() {
        _uploadSpeedTestResultMbps = uploadResult;
        _isTestingSpeed = false;
      });
    }
  }
}
