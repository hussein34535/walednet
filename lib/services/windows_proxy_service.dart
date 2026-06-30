import 'dart:io';

class WindowsProxyService {
  /// تفعيل البروكسي في الويندوز وتوجيهه إلى السيرفر المحدد (مثل socks=127.0.0.1:10809)
  static Future<void> enableProxy(String serverAddress) async {
    if (!Platform.isWindows) return;

    try {
      // 1. تفعيل خيار البروكسي في الريجستري
      await Process.run('reg', [
        'add',
        'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
        '/v',
        'ProxyEnable',
        '/t',
        'REG_DWORD',
        '/d',
        '1',
        '/f',
      ]);

      // 2. ضبط عنوان ومنفذ البروكسي (SOCKS5)
      await Process.run('reg', [
        'add',
        'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
        '/v',
        'ProxyServer',
        '/t',
        'REG_SZ',
        '/d',
        serverAddress,
        '/f',
      ]);

      // 3. إعلام الويندوز والمتصفحات فوراً بتحديث الإعدادات بدون إعادة تشغيل
      await _refreshSystemSettings();
      print('[WindowsProxy] Proxy enabled successfully for: $serverAddress');
    } catch (e) {
      print('[WindowsProxy] Failed to enable proxy: $e');
    }
  }

  /// إيقاف البروكسي في الويندوز والعودة للإنترنت الطبيعي
  static Future<void> disableProxy() async {
    if (!Platform.isWindows) return;

    try {
      // 1. إلغاء تفعيل البروكسي في الريجستري
      await Process.run('reg', [
        'add',
        'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
        '/v',
        'ProxyEnable',
        '/t',
        'REG_DWORD',
        '/d',
        '0',
        '/f',
      ]);

      // 2. إعلام النظام والمتصفحات فوراً لإلغاء البروكسي
      await _refreshSystemSettings();
      print('[WindowsProxy] Proxy disabled successfully');
    } catch (e) {
      print('[WindowsProxy] Failed to disable proxy: $e');
    }
  }

  /// كود PowerShell لإجبار الويندوز على تحديث إعدادات البروكسي في المتصفحات والنظام فوراً
  static Future<void> _refreshSystemSettings() async {
    const psCommand = 
        '\$signature = \'[DllImport("wininet.dll", SetLastError = true)] public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);\'; '
        '\$type = Add-Type -MemberDefinition \$signature -Name "WinINet" -Namespace "Win32" -PassThru; '
        '\$type::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0); ' // INTERNET_OPTION_SETTINGS_CHANGED
        '\$type::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0);';  // INTERNET_OPTION_REFRESH

    try {
      await Process.run('powershell', ['-Command', psCommand]);
    } catch (e) {
      print('[WindowsProxy] Failed to refresh system settings: $e');
    }
  }
}
