import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:WaledNet/data/servers.dart';
import 'package:WaledNet/services/api_service.dart';
import 'package:WaledNet/services/vpn_service.dart';
import 'package:WaledNet/services/ad_service.dart';
import 'package:WaledNet/services/speed_test_service.dart';
import 'package:WaledNet/services/singbox_config_builder.dart';
import 'package:WaledNet/services/ssh_tunnel_service.dart';
import 'package:WaledNet/services/windows_vpn_manager.dart';
import 'package:WaledNet/services/subscription_service.dart';

class VpnProvider with ChangeNotifier {
  final VpnService _vpnService = VpnService();
  final SshTunnelService _sshTunnel = SshTunnelService();
  static const int _sshLocalPort = 10809;
  AdService? _adService;
  bool _adsInitialized = false;
  final SpeedTestService _speedTestService = SpeedTestService();

  String _prefKey(String key) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null ? '${uid}_$key' : 'guest_$key';
  }

  VpnState _vpnState = VpnState.disconnected;
  String _buttonText = 'اتصال';
  bool _isLoading = true;
  String _remark = '';
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
  DateTime? _lastToggleTime;
  bool _isTestingSpeed = false;
  double? _speedTestResultMbps;
  double? _uploadSpeedTestResultMbps;
  Map<String, int> _serverDelays = {};
  bool _isPingingServers = false;
  bool _isVerifyingConnection = false;
  bool _isConnectionVerified = false;
  bool _isConnectingUserTrigger = false;
  bool _hasPrintedIp = false;
  bool _disposed = false;
  bool _initialized = false;
  int _uplink = 0;
  int _downlink = 0;
  bool _isSshReconnecting = false;
  int _sshReconnectAttempt = 0;
  String? _deviceId;
  String? _lastAddedSni;

  VpnState get vpnState => _vpnState;
  int get uplink => _uplink;
  int get downlink => _downlink;
  String get buttonText => _buttonText;
  bool get isLoading => _isLoading;
  List<VpnServer> get vpnServers => _vpnServers;
  List<SniProfile> get sniProfiles => _sniProfiles;
  VpnServer? get selectedServer => _selectedServer;
  SniProfile? get selectedProfile => _selectedProfile;
  bool get isConnected => _vpnStatus == 'CONNECTED';
  bool get isConnecting => _vpnStatus == 'CONNECTING';
  String? get connectedIp => null;
  void toggleConnection() => toggleVpn();
  int? getServerDelay(String url) => _serverDelays[url];
  void selectServer(VpnServer server) => handleSelectionChange(server);
  int get connectionTime => _connectionTime;
  bool get isExtendedConnection => _isExtendedConnection;
  bool get isPremium => SubscriptionService().isPremium;
  bool get isAdLoading => _isAdLoading;
  bool get isRewardedAdReady => _isRewardedAdReady;
  bool get isInterstitialAdReady => _isInterstitialAdReady;
  String get vpnStatus => _vpnStatus;
  bool get isTestingSpeed => _isTestingSpeed;
  double? get speedTestResultMbps => _speedTestResultMbps;
  double? get uploadSpeedTestResultMbps => _uploadSpeedTestResultMbps;
  Map<String, int> get serverDelays => _serverDelays;
  bool get isPingingServers => _isPingingServers;
  bool get isVerifyingConnection => _isVerifyingConnection;
  bool get isConnectionVerified => _isConnectionVerified;
  bool get isConnectingUserTrigger => _isConnectingUserTrigger;
  int get socksProxyPort => 10808;
  bool get isSshReconnecting => _isSshReconnecting;
  int get sshReconnectAttempt => _sshReconnectAttempt;
  String? get deviceId => _deviceId;

  Timer? _logNotifyTimer;
  bool _logNotifyPending = false;

  final List<String> _vpnLogs = [];
  List<String> get vpnLogs => _vpnLogs;

  void _addLog(String msg) {
    if (_disposed) return;
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    final line = "[$timeStr] $msg";
    print(line);
    _vpnLogs.add(line);
    if (_vpnLogs.length > 800) {
      _vpnLogs.removeAt(0);
    }
    
    // Throttle notifyListeners to prevent UI freezing due to high-frequency log updates.
    // Avoid notifying log updates during active connection phase to keep the spinner extremely smooth.
    if (!_logNotifyPending && _vpnStatus != 'CONNECTING') {
      _logNotifyPending = true;
      _logNotifyTimer = Timer(const Duration(milliseconds: 250), () {
        _logNotifyPending = false;
        notifyListeners();
      });
    }
  }

  void clearLogs() {
    _vpnLogs.clear();
    _addLog("Logs cleared.");
    notifyListeners();
  }

  VpnProvider();

  Future<void> _onSshConnectionChanged(bool connected) async {
    if (_disposed) return;
    if (connected) {
      if (!_isSshReconnecting) {
        print('[VpnProvider] SSH tunnel connected initially, skipping auto-restart handler.');
        return;
      }
      // الـ tunnel اتوصل من جديد — شغّل sing-box تاني
      print('[VpnProvider] SSH tunnel reconnected — restarting sing-box');
      _isSshReconnecting = false;
      _sshReconnectAttempt = 0;
      notifyListeners();

      if (_selectedServer != null && _selectedServer!.url.startsWith('ssh://')) {
        final sni = _selectedProfile?.sni;
        try {
          final configJson = SingboxConfigBuilder.build(
            serverUrl: _selectedServer!.url,
            sni: sni,
            sshLocalPort: _sshLocalPort,
          );
          await _vpnService.stop();
          await Future.delayed(const Duration(milliseconds: 500));
          final ok = await _vpnService.start(configJson: configJson);
          if (ok) {
            _vpnStatus = 'CONNECTED';
            _buttonText = 'قطع الاتصال';
            notifyListeners();
          }
        } catch (e) {
          print('[VpnProvider] Failed to restart sing-box after reconnect: $e');
        }
      }
    } else {
      // الـ tunnel انقطع — وقف sing-box مؤقتاً
      print('[VpnProvider] SSH tunnel lost — pausing sing-box');
      _isSshReconnecting = true;
      _vpnStatus = 'CONNECTING';
      _buttonText = 'إعادة الاتصال...';
      notifyListeners();
      await _vpnService.stop();
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  void _onStatusChanged(VpnStatus status) {
    final oldState = _vpnState;
    _vpnState = status.state;
    _uplink = status.uplink;
    _downlink = status.downlink;

    switch (status.state) {
      case VpnState.connected:
        _vpnStatus = 'CONNECTED';
        _buttonText = 'قطع الاتصال';
        _isConnectionVerified = true;
        if (oldState != VpnState.connected) {
          if (SubscriptionService().isPremium) {
            _isExtendedConnection = true;
          } else if (!_isExtendedConnection) {
            _connectionTime = 3600;
          }
          startTimer();
        }
        break;
      case VpnState.connecting:
        _vpnStatus = 'CONNECTING';
        _buttonText = 'جاري الاتصال...';
        _isConnectionVerified = false;
        break;
      case VpnState.disconnected:
        _vpnStatus = 'DISCONNECTED';
        _buttonText = 'اتصال';
        _isConnectionVerified = false;
        stopTimer();
        break;
      case VpnState.error:
        _vpnStatus = 'DISCONNECTED';
        _buttonText = 'اتصال';
        _isConnectionVerified = false;
        stopTimer();
        break;
    }
    notifyListeners();
  }

  void _handleAdFailed(String message) {
    print('Ad failure: $message');
    _isAdLoading = false;
    _isVerifyingConnection = false;
    _updateButtonState();
    notifyListeners();
  }

  void _updateButtonState() {
    switch (_vpnStatus) {
      case 'CONNECTED':
        _buttonText = 'قطع الاتصال';
        break;
      case 'CONNECTING':
        _buttonText = 'جاري الاتصال...';
        break;
      default:
        _buttonText = 'اتصال';
        break;
    }
  }

  Future<void> initProvider() async {
    if (_initialized || _disposed) return;

    await _loadData();
    if (_disposed) return;

    if (Platform.isAndroid || Platform.isIOS) {
      _vpnService.initialize();
    }

    _scheduleDelayedTasks();
  }

  void _scheduleDelayedTasks() {
    Future.delayed(const Duration(seconds: 2), () {
      if (_disposed) return;

      _sshTunnel.onConnectionChanged = _onSshConnectionChanged;
      _sshTunnel.onStatusUpdate = (msg) {
        _addLog('[SSH] $msg');
        if (msg.startsWith('reconnecting:')) {
          _sshReconnectAttempt = int.tryParse(msg.split(':').last) ?? 0;
          _isSshReconnecting = true;
          notifyListeners();
        } else if (msg == 'reconnect_failed') {
          _isSshReconnecting = false;
          _vpnStatus = 'DISCONNECTED';
          _buttonText = 'اتصال';
          stopTimer();
          notifyListeners();
        }
      };

      if (!_adsInitialized && (Platform.isAndroid || Platform.isIOS)) {
        _adsInitialized = true;
        _adService = AdService(
          onRewardedReadyChanged: (ready) {
            _isRewardedAdReady = ready;
            notifyListeners();
          },
          onInterstitialReadyChanged: (ready) {
            _isInterstitialAdReady = ready;
            notifyListeners();
          },
          onAdFailed: _handleAdFailed,
          onRewardedCompleted: () {
            _isExtendedConnection = true;
            _connectionTime = 24 * 60 * 60;
            _isAdLoading = false;
            notifyListeners();
            _connectToVpn();
          },
        );

        if (!SubscriptionService().isPremium) {
          _adService!.initialize();
        }
      }
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (_disposed) return;
      _initFirebase();
    });

    Future.delayed(const Duration(seconds: 6), () {
      if (!_disposed) pingAllServers();
    });
  }

  void _initFirebase() {
    if (_disposed) return;
    try {
      PackageInfo.fromPlatform()
          .then((i) => _deviceId = i.packageName)
          .catchError((_) {});
    } catch (_) {}
    FirebaseMessaging.instance.getToken().then((token) {
      if (token != null && !_disposed) {
        ApiService.registerDeviceToken(token);
      }
    }).catchError((_) {});
    FirebaseMessaging.onMessage.listen((_) {});

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (_disposed) return;
      if (_vpnStatus == 'DISCONNECTED') {
        _selectedServer = null;
        _selectedProfile = null;
        _isConnectionVerified = false;
        _vpnServers = [];
        _sniProfiles = [];
        _isLoading = true;
        notifyListeners();
        _loadData().then((_) {
          _loadSelections();
          _isLoading = false;
          notifyListeners();
        });
      }
    });
  }

  Future<void> refreshData() async {
    await _loadData();
    notifyListeners();
  }

  void markLastAddedSni(String sni) {
    _lastAddedSni = sni;
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    print("[_loadData] Starting data load process.");

    bool serversOk = false;
    bool profilesOk = false;

    try {
      print("[_loadData] Attempting to fetch new data from server...");

      final results = await Future.wait([
        ApiService.fetchVlessServers(),
        ApiService.fetchVmessServers(),
        ApiService.fetchSshServers(),
        ApiService.fetchSlowDnsServers(),
        ApiService.fetchSniProfiles(),
      ]);

      final servers = results[0] as List<VpnServer>;
      final vmessServers = results[1] as List<VpnServer>;
      final sshServers = results[2] as List<VpnServer>;
      final slowDnsServers = results[3] as List<VpnServer>;
      final profiles = results[4] as List<SniProfile>;

      if (servers.isNotEmpty || vmessServers.isNotEmpty ||
          sshServers.isNotEmpty || slowDnsServers.isNotEmpty) {
        _vpnServers = [
          ...servers,
          ...vmessServers,
          ...sshServers,
          ...slowDnsServers,
        ];
        serversOk = true;
      }

      if (profiles.isNotEmpty) {
        _sniProfiles = [
          SniProfile(name: 'Direct / None (بدون SNI)', sni: ''),
          ...profiles,
        ];
        if (_lastAddedSni != null) {
          final idx = _sniProfiles.indexWhere((p) => p.sni == _lastAddedSni);
          if (idx > 1) {
            final profile = _sniProfiles.removeAt(idx);
            _sniProfiles.insert(1, profile);
          }
        }
        profilesOk = true;
      }
    } catch (e) {
      print("[_loadData] API fetch failed: $e");
    }

    if (!serversOk) {
      print("[_loadData] Servers API failed; falling back to cache.");
      await _loadServersFromCache();
    }
    if (!profilesOk) {
      print("[_loadData] Profiles API failed; falling back to cache.");
      await _loadProfilesFromCache();
    }

    if (serversOk || profilesOk) {
      await _saveDataToCache();
      await prefs.setInt(_prefKey('last_fetch_time'), currentTime);
      print("[_loadData] Data fetched from API and saved to cache.");
    }

    if (_vpnServers.isEmpty) {
      _vpnServers = [
        VpnServer(name: 'No Servers Available', url: '', icon: 'assets/images/server.svg'),
      ];
    }
    if (_sniProfiles.length <= 1) {
      _sniProfiles = [
        SniProfile(name: 'Direct / None (بدون SNI)', sni: ''),
        ...allSniProfiles,
      ];
    }

    print("[_loadData] Servers count = ${_vpnServers.length}, SNI profiles count = ${_sniProfiles.length}");
    await _loadSelections();
    _isLoading = false;
    _initialized = true;
    notifyListeners();
  }

  Future<void> _saveDataToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final serversJson = _vpnServers.map((s) => s.toJson()).toList();
    final profilesJson = _sniProfiles.map((p) => p.toJson()).toList();

    await prefs.setString(_prefKey('cached_servers'), jsonEncode(serversJson));
    await prefs.setString(_prefKey('cached_profiles'), jsonEncode(profilesJson));
    print("[_saveDataToCache] Cache saved successfully.");
  }

  Future<void> _loadServersFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final serversStr = prefs.getString(_prefKey('cached_servers'));
    if (serversStr != null) {
      final List<dynamic> serversList = jsonDecode(serversStr);
      _vpnServers = serversList.map((s) => VpnServer.fromJson(s)).toList();
      print("[_loadServersFromCache] Loaded servers from cache.");
    }
  }

  Future<void> _loadProfilesFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesStr = prefs.getString(_prefKey('cached_profiles'));
    if (profilesStr != null) {
      final List<dynamic> profilesList = jsonDecode(profilesStr);
      final profiles = profilesList.map((p) => SniProfile.fromJson(p)).toList();
      final hasDirect = profiles.any((p) => p.sni.isEmpty);
      _sniProfiles = hasDirect ? profiles : [
        SniProfile(name: 'Direct / None (بدون SNI)', sni: ''),
        ...profiles,
      ];
      print("[_loadProfilesFromCache] Loaded profiles from cache.");
    }
  }

  Future<void> _loadSelections() async {
    final prefs = await SharedPreferences.getInstance();
    final savedServerUrl = prefs.getString(_prefKey('selected_server_url'));
    final savedProfileSni = prefs.getString(_prefKey('selected_profile_sni'));
    print("[_loadSelections] Attempting to load saved selections.");
    print("[_loadSelections] Saved Server URL: ${savedServerUrl != null ? '[redacted]' : 'null'}");
    print("[_loadSelections] Saved Profile SNI: $savedProfileSni");

    if (savedServerUrl != null && _vpnServers.isNotEmpty) {
      final found = _vpnServers.firstWhere(
        (s) => s.url == savedServerUrl,
        orElse: () => _vpnServers.first,
      );
      if (found.url.isNotEmpty) {
        _selectedServer = found;
        print("[_loadSelections] Found saved server: ${found.name}");
      }
    }
    if (_selectedServer == null && _vpnServers.isNotEmpty) {
      _selectedServer = _vpnServers.first;
    }

    if (savedProfileSni != null && _sniProfiles.isNotEmpty) {
      final found = _sniProfiles.firstWhere(
        (p) => p.sni == savedProfileSni,
        orElse: () => _sniProfiles.first,
      );
      if (found.sni.isNotEmpty) {
        _selectedProfile = found;
        print("[_loadSelections] Found saved profile: ${found.name}");
      }
    }
    if (_selectedProfile == null && _sniProfiles.isNotEmpty) {
      _selectedProfile = _sniProfiles.first;
    }
  }

  Future<void> _saveSelections() async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedServer != null) {
      await prefs.setString(_prefKey('selected_server_url'), _selectedServer!.url);
    }
    if (_selectedProfile != null) {
      await prefs.setString(_prefKey('selected_profile_sni'), _selectedProfile!.sni);
    }
  }

  Future<void> _connectToVpn() async {
    if (_vpnStatus == 'CONNECTING' || _vpnStatus == 'CONNECTED') {
      print('[_connectToVpn] Already connecting/connected. Ignoring duplicate request.');
      return;
    }
    _addLog('[System] Starting VPN connection process...');
    print('[_connectToVpn] CALLED BY: ${StackTrace.current}');
    if (!_initialized) {
      _addLog('[System] Error: Provider not initialized yet.');
      return;
    }
    if (_selectedServer == null) {
      _addLog('[System] Error: No server selected.');
      return;
    }

    // Set status to CONNECTING immediately to give visual feedback to the user
    _vpnStatus = 'CONNECTING';
    _buttonText = 'جاري الاتصال...';
    _isConnectionVerified = false;
    notifyListeners();

    _addLog('[System] Requesting Android VPN permissions...');
    final hasPermission = await _vpnService.requestPermission();
    if (!hasPermission) {
      _addLog('[System] Error: Android VPN permission denied.');
      _vpnStatus = 'DISCONNECTED';
      _buttonText = 'اتصال';
      notifyListeners();
      return;
    }

    if (_vpnStatus != 'CONNECTING') {
      _addLog('[System] Connection cancelled by user before setup.');
      return;
    }

    final serverUrl = _selectedServer!.url;
    final sni = _selectedProfile?.sni;
    final isSsh = serverUrl.startsWith('ssh://');

    String? resolvedIp;
    final host = SingboxConfigBuilder.getServerHost(serverUrl);
    if (host != null && host.isNotEmpty) {
      final isIp = RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host) || host.contains(':');
      if (!isIp) {
        try {
          _addLog('[System] Resolving server hostname: $host...');
          final addresses = await InternetAddress.lookup(host).timeout(const Duration(seconds: 5));
          if (addresses.isNotEmpty) {
            resolvedIp = addresses.first.address;
            _addLog('[System] Host resolved to IP: $resolvedIp');
          }
        } catch (e) {
          _addLog('[System] Warning: Hostname resolution failed: $e. Falling back to domain name.');
        }
      } else {
        resolvedIp = host;
      }
    }



    if (Platform.isWindows) {
      _addLog('[System] Selected Server: ${_selectedServer!.name}');
      _addLog('[System] Selected SNI Profile: ${sni ?? "Direct / None"}');

      if (isSsh) {
        _addLog('[System] SSH Tunnel mode detected. Parsing credentials...');
        final sshParams = SingboxConfigBuilder.parseSshUrl(serverUrl);
        if (sshParams == null) {
          _addLog('[System] Error: Failed to parse SSH URL. Connection aborted.');
          _vpnStatus = 'DISCONNECTED';
          _buttonText = 'اتصال';
          notifyListeners();
          return;
        }

        try {
          _addLog('[System] Initiating SSH-over-TLS Tunnel...');
          await _sshTunnel.startTunnel(
            host: sshParams['host'],
            port: sshParams['port'],
            username: sshParams['username'],
            password: sshParams['password'],
            sni: sni ?? sshParams['sni'],
            useSsl: sshParams['useSsl'],
            localPort: _sshLocalPort,
          );
          
          if (_vpnStatus != 'CONNECTING') {
            _addLog('[System] Connection cancelled by user during SSH connection phase.');
            await _sshTunnel.stopTunnel();
            return;
          }
          _addLog('[System] SSH Tunnel ready and listening on SOCKS5 port $_sshLocalPort');
          
          _addLog('[System] Starting Windows VPN routing via tun2socks...');
          try {
            await WindowsVpnManager.startVpn(
              type: 'ssh',
              serverIp: resolvedIp ?? sshParams['host'],
            );
            _addLog('[System] Windows VPN routing started successfully.');
            _vpnStatus = 'CONNECTED';
            _buttonText = 'قطع الاتصال';
            _isConnectionVerified = true;
            notifyListeners();
            return;
          } catch (e) {
            _addLog('[System] Error starting Windows VPN routing: $e');
            await _sshTunnel.stopTunnel();
            _vpnStatus = 'DISCONNECTED';
            _buttonText = 'اتصال';
            notifyListeners();
            return;
          }
        } catch (e) {
          if (_vpnStatus != 'CONNECTING') {
            _addLog('[System] Connection was cancelled by user; ignoring SSH error.');
            return;
          }
          _addLog('[System] Error: SSH Tunnel connection failed: $e');
          _vpnStatus = 'DISCONNECTED';
          _buttonText = 'اتصال';
          notifyListeners();
          return;
        }
      } else if (serverUrl.startsWith('slowdns://')) {
        _addLog('[System] SlowDNS protocol is not supported on Windows. Showing error message.');
        _vpnStatus = 'DISCONNECTED';
        _buttonText = 'اتصال';
        notifyListeners();
        return;
      } else {
        // VLESS / VMESS / Trojan logic on Windows!
        _addLog('[System] VLESS mode detected on Windows. Building Xray config...');
        try {
          _addLog('[System] Fetching server TLS certificate SHA256 for pinning...');
          final vlessUri = Uri.parse(serverUrl);
          final vlessQuery = vlessUri.queryParameters;
          final tlsSni = sni ?? vlessQuery['sni'] ?? vlessQuery['host'] ?? vlessUri.host;
          final isTls = vlessQuery['security'] == 'tls';
          String? certSha256;
          if (isTls) {
            certSha256 = await SingboxConfigBuilder.fetchCertSha256(
              resolvedIp ?? vlessUri.host,
              vlessUri.port,
              tlsSni,
            );
            if (certSha256 != null) {
              _addLog('[System] Certificate SHA256: $certSha256');
            } else {
              _addLog('[System] Warning: Could not fetch certificate SHA256.');
            }
          }

          final xrayConfigJson = SingboxConfigBuilder.buildXrayConfig(
            serverUrl: serverUrl,
            sni: sni,
            pinnedPeerCertSha256: certSha256,
          );
          
          _addLog('[System] Starting Windows VPN routing via Xray & tun2socks...');
          await WindowsVpnManager.startVpn(
            type: 'vless',
            serverIp: resolvedIp ?? host ?? Uri.parse(serverUrl).host,
            xrayConfigJson: xrayConfigJson,
          );
          
          _addLog('[System] Windows VLESS VPN started successfully.');
          _vpnStatus = 'CONNECTED';
          _buttonText = 'قطع الاتصال';
          _isConnectionVerified = true;
          notifyListeners();
          return;
        } catch (e) {
          _addLog('[System] Error starting Windows VLESS VPN: $e');
          _vpnStatus = 'DISCONNECTED';
          _buttonText = 'اتصال';
          notifyListeners();
          return;
        }
      }
    }
    // Android / iOS SSH Connection Flow:
    _addLog('[System] Selected Server: ${_selectedServer!.name}');
    _addLog('[System] Selected SNI Profile: ${sni ?? "Direct / None"}');

    if (isSsh) {
      _addLog('[System] SSH Tunnel mode detected. Parsing credentials...');
      final sshParams = SingboxConfigBuilder.parseSshUrl(serverUrl);
      if (sshParams == null) {
        _addLog('[System] Error: Failed to parse SSH URL. Connection aborted.');
        _vpnStatus = 'DISCONNECTED';
        _buttonText = 'اتصال';
        notifyListeners();
        return;
      }

      try {
        _addLog('[System] Initiating SSH-over-TLS Tunnel...');
        await _sshTunnel.startTunnel(
          host: sshParams['host'],
          port: sshParams['port'],
          username: sshParams['username'],
          password: sshParams['password'],
          sni: sni ?? sshParams['sni'],
          useSsl: sshParams['useSsl'],
          localPort: _sshLocalPort,
        );
        
        if (_vpnStatus != 'CONNECTING') {
          _addLog('[System] Connection cancelled by user during SSH connection phase.');
          await _sshTunnel.stopTunnel();
          return;
        }
        _addLog('[System] SSH Tunnel ready and listening on SOCKS5 port $_sshLocalPort');
      } catch (e) {
        if (_vpnStatus != 'CONNECTING') {
          _addLog('[System] Connection was cancelled by user; ignoring SSH error.');
          return;
        }
        _addLog('[System] Error: SSH Tunnel connection failed: $e');
        _vpnStatus = 'DISCONNECTED';
        _buttonText = 'اتصال';
        notifyListeners();
        return;
      }
    }

    if (_vpnStatus != 'CONNECTING') {
      _addLog('[System] Connection cancelled by user before config building.');
      if (isSsh) await _sshTunnel.stopTunnel();
      return;
    }

    String configJson;
    try {
      _addLog('[System] Building sing-box config JSON...');
      configJson = SingboxConfigBuilder.build(
        serverUrl: serverUrl,
        sni: sni,
        sshLocalPort: _sshLocalPort,
        resolvedIp: resolvedIp,
      );
      _addLog('[System] Config JSON generated successfully.');
    } catch (e) {
      _addLog('[System] Error: Config generation failed: $e');
      _vpnStatus = 'DISCONNECTED';
      _buttonText = 'اتصال';
      if (isSsh) await _sshTunnel.stopTunnel();
      notifyListeners();
      return;
    }

    if (_vpnStatus != 'CONNECTING') {
      _addLog('[System] Connection cancelled by user before starting sing-box.');
      if (isSsh) await _sshTunnel.stopTunnel();
      return;
    }

    _addLog('[System] Starting sing-box service on Android...');
    final success = await _vpnService.start(configJson: configJson);
    
    if (_vpnStatus != 'CONNECTING') {
      _addLog('[System] Connection cancelled by user after sing-box start. Stopping...');
      await _vpnService.stop();
      if (isSsh) await _sshTunnel.stopTunnel();
      return;
    }

    if (success) {
      _addLog('[System] sing-box VPN started successfully.');
      _vpnStatus = 'CONNECTED';
      _buttonText = 'قطع الاتصال';
    } else {
      _addLog('[System] Error: sing-box failed to start.');
      if (isSsh) {
        _addLog('[System] Stopping SSH Tunnel...');
        await _sshTunnel.stopTunnel();
      }
      _vpnStatus = 'DISCONNECTED';
      _buttonText = 'اتصال';
    }
    notifyListeners();
  }

  Future<void> toggleVpn() async {
    final now = DateTime.now();
    if (_lastToggleTime != null && now.difference(_lastToggleTime!) < const Duration(seconds: 2)) {
      print('[VpnProvider] toggleVpn clicked too quickly, debouncing.');
      return;
    }
    _lastToggleTime = now;

    if (_vpnStatus == 'CONNECTED' || _vpnStatus == 'CONNECTING') {
      _addLog('[System] User triggered disconnection. Stopping service...');
      
      // Update state and UI immediately for instant feedback
      _vpnStatus = 'DISCONNECTED';
      _buttonText = 'اتصال';
      _isSshReconnecting = false;
      _isConnectionVerified = false;
      stopTimer();
      notifyListeners();

      // Perform actual service shutdown in the background
      try {
        if (Platform.isWindows) {
          final serverUrl = _selectedServer?.url ?? '';
          final isSsh = serverUrl.startsWith('ssh://');
          String serverIp = '';
          if (isSsh) {
            final sshParams = SingboxConfigBuilder.parseSshUrl(serverUrl);
            if (sshParams != null) serverIp = sshParams['host'];
          } else {
            serverIp = Uri.tryParse(serverUrl)?.host ?? '';
          }
          await WindowsVpnManager.stopVpn(serverIp);
        } else {
          await _vpnService.stop();
        }
      } catch (e) {
        _addLog('[System] Error stopping VPN: $e');
      }
      try {
        await _sshTunnel.stopTunnel();
      } catch (e) {
        _addLog('[System] Error stopping SSH Tunnel: $e');
      }
      
      _addLog('[System] Disconnected successfully.');
      notifyListeners();
    } else {
      await _connectToVpn();
      if (_vpnStatus == 'CONNECTED') {
        if (SubscriptionService().isPremium) {
          _isExtendedConnection = true;
        } else if (!_isExtendedConnection) {
          _connectionTime = 3600;
        }
        startTimer();
      }
    }
  }

  void startTimer() {
    if (SubscriptionService().isPremium) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_connectionTime > 0) {
        _connectionTime--;
        notifyListeners();
      } else {
        _timer?.cancel();
        toggleVpn();
      }
    });
  }

  void stopTimer() {
    _timer?.cancel();
  }

  Future<void> runSpeedTest() async {
    if (_isTestingSpeed) return;

    _isTestingSpeed = true;
    _speedTestResultMbps = null;
    _uploadSpeedTestResultMbps = null;
    notifyListeners();

    final downloadResult = await _speedTestService.runDownloadTest();
    _speedTestResultMbps = downloadResult;
    notifyListeners();

    final uploadResult = await _speedTestService.runUploadTest();
    _uploadSpeedTestResultMbps = uploadResult;
    _isTestingSpeed = false;
    notifyListeners();
  }

  Future<void> pingAllServers() async {
    if (_vpnServers.isEmpty || _isPingingServers) return;

    _isPingingServers = true;
    notifyListeners();

    final batchSize = 5;
    for (var i = 0; i < _vpnServers.length; i += batchSize) {
      if (_disposed) return;

      final batch = _vpnServers.skip(i).take(batchSize);
      await Future.wait(batch.map((server) async {
        if (server.url.isEmpty ||
            server.name == 'No Servers Available' ||
            server.name == 'Loading...') return;

        try {
          final stopwatch = Stopwatch()..start();
          String host = '';
          int port = 443;

          final url = server.url;
          if (url.startsWith('vmess://')) {
            final base64Str = url.substring('vmess://'.length);
            String normalized = base64Str;
            final mod = base64Str.length % 4;
            if (mod > 0) normalized += '=' * (4 - mod);
            final decoded = jsonDecode(utf8.decode(base64.decode(normalized)));
            host = decoded['add']?.toString() ?? '';
            port = int.tryParse(decoded['port']?.toString() ?? '443') ?? 443;
          } else if (url.startsWith('slowdns://')) {
            final uri = Uri.tryParse(url);
            if (uri != null) {
              host = uri.queryParameters['dns_ip'] ?? '';
              port = 53;
            }
          } else {
            final uri = Uri.tryParse(url);
            if (uri != null) {
              host = uri.host;
              port = uri.port != 0 ? uri.port : 443;
            }
          }

          if (host.isNotEmpty) {
            final socket = await Socket.connect(
              host, port,
              timeout: const Duration(seconds: 3),
            );
            stopwatch.stop();
            socket.destroy();
            _serverDelays[server.url] = stopwatch.elapsedMilliseconds;
          } else {
            _serverDelays[server.url] = -1;
          }
        } catch (e) {
          _serverDelays[server.url] = -1;
        }
      }));

      if (!_disposed) notifyListeners();
    }

    _isPingingServers = false;
    if (!_disposed) notifyListeners();
  }

  void handleSelectionChange<T>(T? value) {
    if (value is VpnServer) {
      _selectedServer = value;
    } else if (value is SniProfile) {
      _selectedProfile = value;
      _serverDelays.clear();
    }
    _isLoading = true;
    notifyListeners();

    _saveSelections();
    _isLoading = false;
    notifyListeners();
    if (value is SniProfile) {
      pingAllServers();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _adLoadTimer?.cancel();
    _sshTunnel.stopTunnel();
    _vpnService.dispose();
    super.dispose();
  }

  void loadFreshRewardedAd() {
    _adService?.loadRewardedAd();
  }

  void extendConnection() {
    if (SubscriptionService().isPremium) {
      return;
    }
    loadFreshRewardedAd();
    Future.delayed(const Duration(seconds: 2), () {
      if (_isRewardedAdReady && _adService != null) {
        _adService!.showRewardedAdWithCallbacks(
          onCompleted: () {
            _connectionTime = 86400;
            _isExtendedConnection = true;
            notifyListeners();
          },
          onCancelled: () {},
        );
      } else {
        _addLog('الإعلان لم يتم تحميله بعد، حاول مرة أخرى');
      }
    });
  }

  void showRewardedAd({
    required void Function() onCompleted,
    required void Function() onCancelled,
  }) {
    if (SubscriptionService().isPremium) {
      onCompleted();
      return;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      _adService?.showRewardedAdWithCallbacks(
        onCompleted: onCompleted,
        onCancelled: onCancelled,
      );
    } else {
      onCompleted();
    }
  }

  bool _isCloudflareIp(String ip) {
    try {
      final parts = ip.split('.').map(int.parse).toList();
      if (parts.length != 4) return false;
      final first = parts[0];
      final second = parts[1];
      
      // Cloudflare IPv4 ranges
      if (first == 103) {
        if (second >= 21 && second <= 23) return true;
        if (second == 22) return true;
        if (second == 31) return true;
      }
      if (first == 104) {
        if (second >= 16 && second <= 27) return true;
      }
      if (first == 108 && second == 162) return true;
      if (first == 131 && second == 27) return true;
      if (first == 141 && second == 101) return true;
      if (first == 162 && (second == 158 || second == 159)) return true;
      if (first == 172 && second >= 64 && second <= 79) return true;
      if (first == 173 && second == 245) return true;
      if (first == 188 && second == 114) return true;
      if (first == 190 && second == 93) return true;
      if (first == 197 && second == 234) return true;
      if (first == 198 && second == 41) return true;
    } catch (_) {}
    return false;
  }
}
