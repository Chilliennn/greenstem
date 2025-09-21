import 'dart:io';
import 'dart:async';

class NetworkService {
  static Timer? _timer;
  static final StreamController<bool> _controller =
      StreamController<bool>.broadcast();
  static bool _lastKnownState = false;
  static bool _isDisposed = false;

  // Add caching to avoid repeated network checks
  static bool? _cachedResult;
  static DateTime? _lastCheckTime;
  static const Duration _cacheValidity = Duration(seconds: 10);

  static Future<bool> hasConnection({bool useCache = true}) async {
    // Return cached result if it's still valid and cache is enabled
    if (useCache &&
        _cachedResult != null &&
        _lastCheckTime != null &&
        DateTime.now().difference(_lastCheckTime!) < _cacheValidity) {
      return _cachedResult!;
    }

    try {
      // First try to check if we can reach the internet
      final googleResult = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));

      if (googleResult.isEmpty || googleResult[0].rawAddress.isEmpty) {
        _lastKnownState = false;
        _cachedResult = false;
        _lastCheckTime = DateTime.now();
        print('🌐 Network check result: false (no internet)');
        return false;
      }

      // If we have internet, also check if we can reach Supabase
      // This is more relevant for our app since we need Supabase access
      try {
        final supabaseResult =
            await InternetAddress.lookup('xeroeyuqxnzzexzkvbsd.supabase.co')
                .timeout(const Duration(seconds: 5));

        final hasSupabaseAccess = supabaseResult.isNotEmpty &&
            supabaseResult[0].rawAddress.isNotEmpty;
        _lastKnownState = hasSupabaseAccess;
        _cachedResult = hasSupabaseAccess;
        _lastCheckTime = DateTime.now();
        print(
            '🌐 Network check result: $hasSupabaseAccess (internet: true, supabase: $hasSupabaseAccess)');
        return hasSupabaseAccess;
      } catch (e) {
        // If Supabase is not reachable, we're effectively offline for our app
        _lastKnownState = false;
        _cachedResult = false;
        _lastCheckTime = DateTime.now();
        print(
            '🌐 Network check result: false (internet: true, supabase: false)');
        return false;
      }
    } on SocketException catch (e) {
      print('📱 Network check failed: $e');
      _lastKnownState = false;
      _cachedResult = false;
      _lastCheckTime = DateTime.now();
      return false;
    } on TimeoutException catch (e) {
      print('⏰ Network check timeout: $e');
      _lastKnownState = false;
      _cachedResult = false;
      _lastCheckTime = DateTime.now();
      return false;
    } catch (e) {
      print('📱 Network check error: $e');
      _lastKnownState = false;
      _cachedResult = false;
      _lastCheckTime = DateTime.now();
      return false;
    }
  }

  static Stream<bool> get connectionStream {
    if (_isDisposed) {
      return Stream.empty();
    }

    _startMonitoring();
    return _controller.stream;
  }

  static void _startMonitoring() {
    if (_timer?.isActive == true || _isDisposed) return;

    _timer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (_isDisposed) {
        _timer?.cancel();
        return;
      }

      // Force a fresh network check for monitoring (bypass cache)
      final currentState = await hasConnection(useCache: false);
      if (currentState != _lastKnownState && !_isDisposed) {
        print('🔄 Network state changed: ${_lastKnownState} -> $currentState');
        _controller.add(currentState);
        _lastKnownState = currentState;
      }
    });

    // Immediately check and emit current state
    hasConnection().then((state) {
      if (!_isDisposed) {
        _controller.add(state);
      }
    });
  }

  static void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _controller.close();
  }

  static void reset() {
    _isDisposed = false;
    _cachedResult = null;
    _lastCheckTime = null;
  }
}
