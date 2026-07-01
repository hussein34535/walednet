import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:WaledNet/data/servers.dart';
import 'package:WaledNet/services/api_service.dart';
import 'package:WaledNet/services/vpn_service.dart';
import 'package:WaledNet/services/ad_service.dart';
import 'package:WaledNet/services/speed_test_service.dart';
import 'package:WaledNet/services/ssh_tunnel_service.dart';
import 'package:WaledNet/services/windows_vpn_manager.dart';
import 'package:WaledNet/services/url_parser_service.dart';

class VpnProvider with ChangeNotifier {
  late final VpnService _vpnService;
  late final AdService _adService;
  final SpeedTestService _speedTestService = SpeedTestService();

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
  Timer? _logTimer;
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

  // Getters
  V2RayStatus? get status => _status;
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

  VpnProvider() {
    _vpnService = VpnService(onStatusChanged: _onStatusChanged);
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

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  void _onStatusChanged(V2RayStatus newStatus) {
    final previousState = _vpnStatus;
    _status = newStatus;
    _vpnStatus = newStatus.state;
    _updateButtonState();

    final newState = newStatus.state;
    print('[_onStatusChanged] state: $previousState -> $newState');

    if (newState == 'CONNECTED') {
      _isConnectionVerified = true;
      _isVerifyingConnection = false;
      _isConnectingUserTrigger = false;
      _logTimer?.cancel();
      _logTimer = null;

      if (previousState != 'CONNECTED') {
        startTimer();
      }

      if (!_hasPrintedIp) {
        _hasPrintedIp = true;
        Future.delayed(const Duration(seconds: 2), () async {
          try {
            final ip = await UrlParserService.fetchIpThroughProxy();
            if (ip != null) {
              print('[_onStatusChanged] VPN Public IP Address: {"ip":"$ip"}');
            } else {
              final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
              final request = await client.getUrl(Uri.parse('https://api.ipify.org?format=json'));
              final response = await request.close();
              if (response.statusCode == 200) {
                final responseBody = await response.transform(utf8.decoder).join();
                print('[_onStatusChanged] VPN Public IP Address (Direct Fallback): $responseBody');
              }
            }
          } catch (e) {
            print('[_onStatusChanged] Failed to fetch VPN Public IP: $e');
            _hasPrintedIp = false;
          }
        });
      }
    } else if (newState == 'DISCONNECTED') {
      _isConnectionVerified = false;
      _isVerifyingConnection = false;
      _isConnectingUserTrigger = false;
      _isAdLoading = false;
      _hasPrintedIp = false;
      _logTimer?.cancel();
      _logTimer = null;
      stopTimer();
    } else {
      _hasPrintedIp = false;
    }

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

    notifyListeners();
  }

  void _handleAdFailed(String message) {
    print('Unity Ads failure: $message');
    _isAdLoading = false;
    _isVerifyingConnection = false;
    _updateButtonState();
    notifyListeners();
  }

  void _updateButtonState() {
    final state = _status?.state ?? _vpnStatus;
    switch (state) {
      case 'CONNECTED':
        _buttonText = 'قطع الاتصال';
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

  Future<void> initProvider() async {
    await _loadData();
    if (Platform.isAndroid || Platform.isIOS) {
      await _initializeV2Ray();
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
      final profiles = await ApiService.fetchSniProfiles();

      if (servers.isNotEmpty && profiles.isNotEmpty) {
        _vpnServers = [
          VpnServer(
            name: 'سيرفر تجربة SSH (SSL/TLS)',
            url: 'ssh://esdgsdgre4y643:sgdgsdg434@76.13.39.204:443?ssl=true',
            icon: 'assets/images/server.svg',
          ),
          ...servers,
        ];
        _sniProfiles = profiles;
        await _saveDataToCache();
        await prefs.setInt('last_fetch_time', currentTime);
        print("[_loadData] Data fetched from API and saved to cache.");
        fetchedFromApi = true;
      }
    } catch (e) {
      print("[_loadData] API fetch failed: $e");
    }

    if (!fetchedFromApi) {
      print("[_loadData] Fetching from cache fallback...");
      await _loadDataFromCache();
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

  Future<void> _initializeV2Ray() async {
    final originalUrl = _getFinalUrl();
    final url = await UrlParserService.resolveUrlHost(originalUrl);
    print("V2Ray/SSH - Final URL to initialize: $url");

    if (_selectedServer == null || url.isEmpty) {
      print("V2Ray initialization skipped: selected server is null or URL is invalid.");
      return;
    }

    try {
      await _vpnService.initializeV2Ray();
      if (url.startsWith('ssh://')) {
        final sshParams = UrlParserService.parseSshUrl(url);
        final String sshHost = sshParams?['host'] ?? '';
        _remark = 'SSH Connection';
        _config = UrlParserService.generateSocksV2rayConfig(sshHost);
      } else {
        final v2rayURL = await V2ray.parseFromURL(url);
        _remark = v2rayURL.remark;
        final configString = v2rayURL.getFullConfiguration();
        if (configString != null) {
          _config = jsonDecode(configString) as Map<String, dynamic>;
        }
      }
    } catch (e) {
      print("Error initializing V2Ray: $e");
    }
    notifyListeners();
  }

  String _getFinalUrl() {
    if (_selectedServer == null) return '';
    return UrlParserService.getFinalUrlForServer(_selectedServer!, _selectedProfile);
  }

  Future<List<String>?> _getBypassSubnets(String url) async {
    if (!url.startsWith('ssh://')) return null;
    final sshParams = UrlParserService.parseSshUrl(url);
    final String sshHost = sshParams?['host'] ?? '';
    if (sshHost.isEmpty) return null;

    try {
      final isIp = InternetAddress.tryParse(sshHost) != null;
      if (isIp) {
        print('[_getBypassSubnets] Bypassing SSH host IP: $sshHost');
        return ["$sshHost/32"];
      } else {
        final resolvedIp = await UrlParserService.resolveDomain(sshHost);
        print('[_getBypassSubnets] Resolved SSH host $sshHost to $resolvedIp for bypass');
        return ["$resolvedIp/32"];
      }
    } catch (e) {
      print('[_getBypassSubnets] Error resolving SSH host for bypass: $e');
    }
    return null;
  }

  Future<void> _connectToVpn() async {
    _isConnectingUserTrigger = true;
    notifyListeners();

    final originalUrl = _getFinalUrl();
    final url = await UrlParserService.resolveUrlHost(originalUrl);

    bool hasPermission = true;
    if (Platform.isAndroid || Platform.isIOS) {
      hasPermission = await _vpnService.requestPermission();
    }

    if (hasPermission) {
      _isExtendedConnection = true;
      _connectionTime = 24 * 60 * 60;

      if (Platform.isWindows) {
        final ip = Uri.parse(url).host;
        if (url.startsWith('ssh://')) {
          final sshParams = UrlParserService.parseSshUrl(url);
          if (sshParams == null) {
            _isConnectingUserTrigger = false;
            notifyListeners();
            return;
          }

          try {
            _isVerifyingConnection = true;
            _buttonText = 'جاري الاتصال...';
            notifyListeners();

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
            _isConnectingUserTrigger = false;
            _isVerifyingConnection = false;
            _updateButtonState();
            notifyListeners();
            return;
          }
        }

        final List<String>? bypassSubnets = await _getBypassSubnets(url);

        await _vpnService.initializeV2Ray();
        try {
          await _vpnService.startV2Ray(
            remark: url.startsWith('ssh://')
                ? 'WaledNet SSH: متصل وآمن 🛡️'
                : 'WaledNet VPN: متصل وآمن 🛡️',
            config: jsonEncode(_config),
            bypassSubnets: bypassSubnets,
          );
        } catch (e) {
          print('[_connectToVpn] startV2Ray threw exception: $e');
        }
      } else {
        // Android / iOS
        print('[_connectToVpn] Starting connection process for Android/iOS');
        print('[_connectToVpn] Resolving config details...');
        await _initializeV2Ray();
        print('[_connectToVpn] Done initializing config details. Config keys: ${_config.keys.toList()}');

        if (url.startsWith('ssh://')) {
          print('[_connectToVpn] SSH connection URL detected.');
          final sshParams = UrlParserService.parseSshUrl(url);
          if (sshParams == null) {
            print('[_connectToVpn] Error: Failed to parse SSH URL.');
            _isConnectingUserTrigger = false;
            notifyListeners();
            return;
          }

          try {
            _isVerifyingConnection = true;
            _buttonText = 'جاري الاتصال...';
            notifyListeners();

            print('[_connectToVpn] Attempting to start SSH Tunnel...');
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
            print('[_connectToVpn] SSH Tunnel started successfully.');
          } catch (e) {
            print('[_connectToVpn] SSH Tunnel failed to start: $e');
            _isConnectingUserTrigger = false;
            _isVerifyingConnection = false;
            _updateButtonState();
            notifyListeners();
            return;
          }
        }

        final List<String>? bypassSubnets = await _getBypassSubnets(url);

        print('[_connectToVpn] Initializing native V2Ray service via VpnService...');
        await _vpnService.initializeV2Ray();
        
        try {
          print('[_connectToVpn] Starting V2Ray Core/VPN Tunnel. ProxyOnly = false');
          await _vpnService.startV2Ray(
            remark: url.startsWith('ssh://')
                ? 'WaledNet_SSH'
                : 'WaledNet_VPN',
            config: jsonEncode(_config),
            bypassSubnets: bypassSubnets,
          );
          print('[_connectToVpn] V2Ray start call sent successfully.');

          _logTimer?.cancel();
          _logTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
            try {
              final logs = await _vpnService.getLogs();
              if (logs.isNotEmpty) {
                print('--- [V2Ray Native Logs] ---');
                for (var log in logs) {
                  print('[XrayCore] $log');
                }
                print('---------------------------');
              }
            } catch (e) {
              print('[_connectToVpn] Error fetching logs: $e');
            }
          });
        } catch (e) {
          print('[_connectToVpn] V2Ray start call threw exception: $e');
        }
      }
    } else {
      _isConnectingUserTrigger = false;
    }
    notifyListeners();
  }

  Future<void> toggleVpn() async {
    if (_status?.state == 'CONNECTED' || _vpnStatus == 'CONNECTED') {
      if (Platform.isWindows) {
        final originalUrl = _getFinalUrl();
        final url = await UrlParserService.resolveUrlHost(originalUrl);
        final ip = Uri.parse(url).host;
        await WindowsVpnManager.stopVpn(ip);
        await SshTunnelService().stopTunnel();
        stopTimer();
        _isConnectionVerified = false;
        _isConnectingUserTrigger = false;
        _vpnStatus = 'DISCONNECTED';
        _status = null;
        _updateButtonState();
      } else {
        await _vpnService.stopV2Ray();
        await SshTunnelService().stopTunnel();
        _logTimer?.cancel();
        _logTimer = null;
      }
    } else {
      await _connectToVpn();
    }
    notifyListeners();
  }

  void startTimer() {
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

    try {
      await _vpnService.initializeV2Ray();

      for (final server in _vpnServers) {
        if (server.url.isEmpty ||
            server.name == 'No Servers Available' ||
            server.name == 'Loading...') continue;

        try {
          final finalUrl = UrlParserService.getFinalUrlForServer(server, _selectedProfile);
          if (finalUrl.startsWith('ssh://')) {
            final sshParams = UrlParserService.parseSshUrl(finalUrl);
            if (sshParams != null) {
              final stopwatch = Stopwatch()..start();
              final socket = await Socket.connect(
                sshParams['host'],
                sshParams['port'],
                timeout: const Duration(seconds: 4),
              );
              stopwatch.stop();
              socket.destroy();
              _serverDelays[server.url] = stopwatch.elapsedMilliseconds;
            }
          } else {
            final v2rayURL = await V2ray.parseFromURL(finalUrl);
            final configString = v2rayURL.getFullConfiguration();
            if (configString != null) {
              final delay = await _vpnService.getServerDelay(config: configString);
              _serverDelays[server.url] = delay;
            }
          }
        } catch (e) {
          _serverDelays[server.url] = -1;
        }
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      print('Error in _pingAllServers: $e');
    } finally {
      _isPingingServers = false;
      notifyListeners();
    }
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
    _initializeV2Ray().then((_) {
      _isLoading = false;
      notifyListeners();
      if (value is SniProfile) {
        pingAllServers();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _adLoadTimer?.cancel();
    _logTimer?.cancel();
    super.dispose();
  }
}
