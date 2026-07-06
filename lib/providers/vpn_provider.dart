import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:WaledNet/data/servers.dart';
import 'package:WaledNet/services/api_service.dart';
import 'package:WaledNet/services/vpn_service.dart';
import 'package:WaledNet/services/ad_service.dart';
import 'package:WaledNet/services/speed_test_service.dart';
import 'package:WaledNet/services/singbox_config_builder.dart';
import 'package:WaledNet/services/ssh_tunnel_service.dart';

class VpnProvider with ChangeNotifier {
  final VpnService _vpnService = VpnService();
  final SshTunnelService _sshTunnel = SshTunnelService();
  static const int _sshLocalPort = 10809;
  late final AdService _adService;
  final SpeedTestService _speedTestService = SpeedTestService();

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

  VpnState get vpnState => _vpnState;
  int get uplink => _uplink;
  int get downlink => _downlink;
  String get buttonText => _buttonText;
  bool get isLoading => _isLoading;
  List<VpnServer> get vpnServers => _vpnServers;
  List<SniProfile> get sniProfiles => _sniProfiles;
  VpnServer? get selectedServer => _selectedServer;
  SniProfile? get selectedProfile => _selectedProfile;
  int get connectionTime => _connectionTime;
  bool get isExtendedConnection => _isExtendedConnection;
  bool get isAdLoading => _isAdLoading;
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

  Timer? _logNotifyTimer;
  bool _logNotifyPending = false;

  final List<String> _vpnLogs = [];
  List<String> get vpnLogs => _vpnLogs;

  void _addLog(String msg) {
    if (_disposed) return;
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    final line = "[$timeStr] $msg";
    _vpnLogs.add(line);
    if (_vpnLogs.length > 800) {
      _vpnLogs.removeAt(0);
    }
    
    // Throttle notifyListeners to prevent UI freezing due to high-frequency log updates
    if (!_logNotifyPending) {
      _logNotifyPending = true;
      _logNotifyTimer = Timer(const Duration(milliseconds: 200), () {
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

  VpnProvider() {
    _vpnService.initialize();
    _vpnService.statusStream.listen(_onStatusChanged);

    // Listen to sing-box core logs
    _vpnService.logStream.listen((logLine) {
      _addLog('[Core] $logLine');
    });

    // ── SSH Tunnel Callbacks ──
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
  }

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
          if (!_isExtendedConnection) {
            _connectionTime = 0;
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
    await _loadData();
    // Start pinging all servers in the background immediately after loading data
    pingAllServers();
    
    if (Platform.isAndroid || Platform.isIOS) {
      _vpnService.initialize();
      _adService.initialize();

      FirebaseMessaging.instance.getToken().then((token) {
        print("Firebase Messaging Token: $token");
      }).catchError((e) {
        print("Error getting Firebase Messaging Token: $e");
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');
      });
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    print("[_loadData] Starting data load process.");

    bool fetchedFromApi = false;
    try {
      print("[_loadData] Attempting to fetch new data from server...");
      final servers = await ApiService.fetchVlessServers();
      final sshServers = await ApiService.fetchSshServers();
      final profiles = await ApiService.fetchSniProfiles();

      if (servers.isNotEmpty && profiles.isNotEmpty) {
        _vpnServers = [
          ...servers,
          ...sshServers,
        ];
        _sniProfiles = profiles;
        await _saveDataToCache();
        await prefs.setInt('last_fetch_time', currentTime);
        print("[_loadData] Data fetched from API and saved to cache.");
        fetchedFromApi = true;
      } else if (sshServers.isNotEmpty && profiles.isNotEmpty) {
        _vpnServers = [...sshServers];
        _sniProfiles = profiles;
        await _saveDataToCache();
        await prefs.setInt('last_fetch_time', currentTime);
        print("[_loadData] SSH data only, saved to cache.");
        fetchedFromApi = true;
      }
    } catch (e) {
      print("[_loadData] API fetch failed: $e");
    }

    if (!fetchedFromApi) {
      print("[_loadData] Fetching from cache fallback...");
      await _loadDataFromCache();
    }

    // Always ensure the local SSH User server is added to the list, even when loading from cache fallback
    final hasSshUser = _vpnServers.any((s) => s.name == 'SSH User');
    if (!hasSshUser) {
      _vpnServers.add(VpnServer(
        name: 'SSH User',
        url: 'ssh://ajggdsg4:gsg43t436@168.231.110.144:443?ssl=true',
        icon: 'assets/images/server.svg',
      ));
    }

    if (_vpnServers.isEmpty) {
      _vpnServers = [
        VpnServer(
          name: 'No Servers Available',
          url: '',
          icon: 'assets/images/server.svg',
        )
      ];
    }
    if (_sniProfiles.isEmpty) {
      _sniProfiles = [
        SniProfile(
          name: 'No SNI Available',
          sni: '',
          icon: 'assets/images/server.svg',
        )
      ];
    }

    print("[_loadData] After ensuring non-empty lists: Servers count = ${_vpnServers.length}, SNI profiles count = ${_sniProfiles.length}");

    await _loadSelections();

    _isLoading = false;
    _initialized = true;
    notifyListeners();
  }

  Future<void> _saveDataToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final serversJson = _vpnServers.map((s) => s.toJson()).toList();
    final profilesJson = _sniProfiles.map((p) => p.toJson()).toList();

    await prefs.setString('cached_servers', jsonEncode(serversJson));
    await prefs.setString('cached_profiles', jsonEncode(profilesJson));
    print("[_saveDataToCache] Cache saved successfully.");
  }

  Future<void> _loadDataFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final serversStr = prefs.getString('cached_servers');
    final profilesStr = prefs.getString('cached_profiles');

    if (serversStr != null && profilesStr != null) {
      final List<dynamic> serversList = jsonDecode(serversStr);
      final List<dynamic> profilesList = jsonDecode(profilesStr);

      _vpnServers = serversList.map((s) => VpnServer.fromJson(s)).toList();
      _sniProfiles = profilesList.map((p) => SniProfile.fromJson(p)).toList();
      print("[_loadDataFromCache] Loaded data from cache successfully.");
    }
  }

  Future<void> _loadSelections() async {
    final prefs = await SharedPreferences.getInstance();
    final savedServerUrl = prefs.getString('selected_server_url');
    final savedProfileSni = prefs.getString('selected_profile_sni');
    print("[_loadSelections] Attempting to load saved selections.");
    print("[_loadSelections] Saved Server URL: $savedServerUrl");
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
      await prefs.setString('selected_server_url', _selectedServer!.url);
    }
    if (_selectedProfile != null) {
      await prefs.setString('selected_profile_sni', _selectedProfile!.sni);
    }
  }

  Future<void> _connectToVpn() async {
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
        await _vpnService.stop();
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
      if (_vpnStatus == 'CONNECTED' && _connectionTime > 0) {
        startTimer();
      }
    }
  }

  void startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isExtendedConnection) {
        if (_connectionTime > 0) {
          _connectionTime--;
          notifyListeners();
        } else {
          _timer?.cancel();
          toggleVpn();
        }
      } else {
        _connectionTime++;
        notifyListeners();
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

    for (final server in _vpnServers) {
      if (server.url.isEmpty ||
          server.name == 'No Servers Available' ||
          server.name == 'Loading...') continue;

      try {
        final stopwatch = Stopwatch()..start();
        final uri = Uri.tryParse(server.url);
        if (uri != null && uri.host.isNotEmpty) {
          final socket = await Socket.connect(
            uri.host,
            uri.port != 0 ? uri.port : 443,
            timeout: const Duration(seconds: 4),
          );
          stopwatch.stop();
          socket.destroy();
          _serverDelays[server.url] = stopwatch.elapsedMilliseconds;
        }
      } catch (e) {
        _serverDelays[server.url] = -1;
      }
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _isPingingServers = false;
    notifyListeners();
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
}
