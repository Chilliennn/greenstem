import 'dart:io';
import 'dart:async';

class NetworkService {
  static Timer? _timer;
  static final StreamController<bool> _controller =
      StreamController<bool>.broadcast();
  static bool _lastKnownState = false;
  static bool _isDisposed = false;

  static Future<bool> hasConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      _lastKnownState = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      return _lastKnownState;
    } on SocketException catch (_) {
      _lastKnownState = false;
      return false;
    }
  }

  static Stream<bool> get connectionStream {
    if (_isDisposed) {
      // Return a stream that immediately closes if service is disposed
      return Stream.empty();
    }

    // Start monitoring if not already started
    _startMonitoring();
    return _controller.stream;
  }

  static void _startMonitoring() {
    if (_timer?.isActive == true || _isDisposed) return;

    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
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
    // Note: Don't recreate the controller here as it might cause issues
    // The app should be restarted if NetworkService needs to be reset
  }
}
