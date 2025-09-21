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

  static Future<bool> hasConnection() async {
    // Return cached result if it's still valid
    if (_cachedResult != null &&
        _lastCheckTime != null &&
        DateTime.now().difference(_lastCheckTime!) < _cacheValidity) {
      return _cachedResult!;
    }

    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 15));

      final hasConnection =
          result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _lastKnownState = hasConnection;
      _cachedResult = hasConnection;
      _lastCheckTime = DateTime.now();
      print('🌐 Network check result: $hasConnection');
      return hasConnection;
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

      final currentState = await hasConnection();
      if (currentState != _lastKnownState && !_isDisposed) {
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
