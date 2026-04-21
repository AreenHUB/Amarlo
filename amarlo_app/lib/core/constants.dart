// lib/core/constants.dart
class AppConstants {
  // ─── Server host (from --dart-define) ──────────────────
  static const String _host = String.fromEnvironment(
    'API_HOST',
    defaultValue: '127.0.0.1',
  );
  static const int _port = int.fromEnvironment('API_PORT', defaultValue: 8000);

  static String get baseUrl    => 'http://$_host:$_port';
  static String get wsBaseUrl  => 'ws://$_host:$_port';

  // ─── Image URL normalizer ───────────────────────────────
  // السيرفر يحفظ URLs كـ http://localhost:8000/... أو http://127.0.0.1:8000/...
  // Flutter يحتاج استبدال الـ host بـ API_HOST الصحيح للجهاز الحالي
  static String fixImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    try {
      final uri = Uri.parse(url);
      // استبدل الـ host والـ port بالقيم الصحيحة
      return uri.replace(host: _host, port: _port).toString();
    } catch (_) {
      return url;
    }
  }

  // ─── Auth ───────────────────────────────────────────────
  static String get loginUrl    => '$baseUrl/auth/login';
  static String get registerUrl => '$baseUrl/auth/register';
  static String get meUrl       => '$baseUrl/auth/me';
  static String get logoutUrl   => '$baseUrl/auth/logout';

  // ─── Services ───────────────────────────────────────────
  static String get servicesUrl         => '$baseUrl/services';
  static String get categoriesUrl       => '$baseUrl/categories';
  static String get workerServicesUrl   => '$baseUrl/worker-services';

  // ─── Posts ──────────────────────────────────────────────
  static String get postsUrl       => '$baseUrl/posts';
  static String get publicPostsUrl => '$baseUrl/posts/public';
  static String get myOffersUrl    => '$baseUrl/posts/me/offers';

  // ─── Reports ────────────────────────────────────────────
  static String reportsUrl()   => '$baseUrl/reports';
  static String myReportsUrl() => '$baseUrl/reports/my';

  // ─── Users ──────────────────────────────────────────────
  static String userUrl(String id)           => '$baseUrl/users/$id';
  static String userByEmailUrl(String email) => '$baseUrl/users?email=$email';
  static String reviewsUrl(String email)     => '$baseUrl/users/$email/reviews';
  static String reviewUrl(String id)         => '$baseUrl/users/reviews/$id';

  // ─── Services CRUD ──────────────────────────────────────
  static String serviceUrl(String id) => '$baseUrl/services/$id';

  // ─── Posts CRUD ─────────────────────────────────────────
  static String postUrl(String id)     => '$baseUrl/posts/$id';
  static String postOffersUrl(String postId) =>
      '$baseUrl/posts/$postId/offers';
  static String postOfferUrl(String postId, String offerId) =>
      '$baseUrl/posts/$postId/offers/$offerId';
  static String postOfferActionUrl(String postId, String offerId, String action) =>
      '$baseUrl/posts/$postId/offers/$offerId/$action';

  // ─── Requests ───────────────────────────────────────────
  static String requestsUserUrl(String userId) =>
      '$baseUrl/requests/user/$userId';
  static String requestsWorkerUrl(String email) =>
      '$baseUrl/requests/worker/$email';
  static String requestUserCompletedUrl(String email) =>
      '$baseUrl/requests/user/$email/completed';
  static String requestWorkerCompletedUrl(String email) =>
      '$baseUrl/requests/worker/$email/completed';
  static String requestUrl(String id)       => '$baseUrl/requests/$id';
  static String requestAcceptUrl(String id) => '$baseUrl/requests/$id/accept';
  static String requestReadyUrl(String id)  => '$baseUrl/requests/$id/ready';

  // ─── Chat ───────────────────────────────────────────────
  static String messagesUrl(String s, String r) => '$baseUrl/messages/$s/$r';
  static String conversationsUrl(String email)  => '$baseUrl/conversations/$email';
  static String markReadUrl(String msgId)       => '$baseUrl/messages/$msgId/read';
  static String toggleBlockUrl(String email)    => '$baseUrl/toggle-block/$email';
  static String blockStatusUrl(String email)    => '$baseUrl/block-status/$email';

  // ─── Safe Area ──────────────────────────────────────────
  static String safeAreaUploadUrl(String id)        => '$baseUrl/safe-area/$id/upload';
  static String safeAreaPreviewUrl(String id)       => '$baseUrl/safe-area/$id/preview';
  static String safeAreaPaymentUrl(String id)       => '$baseUrl/safe-area/$id/send-payment';
  static String safeAreaPaymentStatusUrl(String id) => '$baseUrl/safe-area/$id/payment-status';
  static String safeAreaConfirmUrl(String id)       => '$baseUrl/safe-area/$id/confirm';
  static String safeAreaDownloadUrl(String id)      => '$baseUrl/safe-area/$id/download';
  static String workerBalanceUrl(String email)      => '$baseUrl/safe-area/balance/$email';

  // ─── WebSocket ──────────────────────────────────────────
  static String chatWsUrl(String email, String token) =>
      '$wsBaseUrl/ws/chat/$email?token=$token';
  static String notificationsWsUrl(String email, String token) =>
      '$wsBaseUrl/ws/notifications/$email?token=$token';

  // ─── SharedPreferences keys ─────────────────────────────
  static const String kAccessToken = 'access_token';
  static const String kUserType    = 'user_type';
  static const String kEmail       = 'email';
  static const String kUserId      = 'user_id';
  static const String kUsername    = 'username';
}
