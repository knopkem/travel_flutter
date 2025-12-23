/// Exception thrown when network operations fail
class NetworkException implements Exception {
  final String message;
  final bool isOffline;

  const NetworkException(this.message, {this.isOffline = false});

  @override
  String toString() => message;

  /// Create exception for offline scenario
  factory NetworkException.offline() {
    return const NetworkException(
      'No internet connection. Please check your network settings.',
      isOffline: true,
    );
  }

  /// Create exception for rate limiting
  factory NetworkException.rateLimited() {
    return const NetworkException(
      'Too many requests. Please wait a moment and try again.',
    );
  }

  /// Create exception for timeout
  factory NetworkException.timeout() {
    return const NetworkException(
      'Request timed out. Please check your connection and try again.',
    );
  }

  /// Create exception for server error
  factory NetworkException.serverError(int statusCode) {
    return NetworkException(
      'Server error ($statusCode). Please try again later.',
    );
  }
}
