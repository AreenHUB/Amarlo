// lib/core/constants.dart
class AppConstants {
  // ─── Server connection ────────────────────────────────
  static const String _host = String.fromEnvironment(
    'API_HOST',
    defaultValue: '127.0.0.1',
  );
  static const int _port = int.fromEnvironment('API_PORT', defaultValue: 8000);

  static String get baseUrl   => 'http://$_host:$_port/api/v1';
  static String get wsBaseUrl => 'ws://$_host:$_port/api/v1';

  // ─── Image URL normalizer ────────────────────────────
  // يصحّح الـ host في أي URL محفوظ في DB
  static String fixImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    try {
      final uri = Uri.parse(url);
      // URLs خارجية (picsum, unsplash, etc.) — لا تُعدَّل
      final host = uri.host.toLowerCase();
      if (host.isNotEmpty &&
          host != '127.0.0.1' &&
          host != '10.0.2.2' &&
          host != 'localhost' &&
          !host.startsWith('192.168.')) {
        return url;
      }
      // إصلاح الـ host للـ URLs الداخلية فقط
      var fixed = uri.replace(host: _host, port: _port).toString();
      // دعم البيانات القديمة: /static/ → /uploads/
      fixed = fixed.replaceFirst('/static/', '/uploads/');
      return fixed;
    } catch (_) {
      return url;
    }
  }

  // ─── Auth ────────────────────────────────────────────
  static String get loginUrl    => '$baseUrl/auth/login';
  static String get registerUrl => '$baseUrl/auth/register';
  static String get meUrl       => '$baseUrl/auth/me';
  static String get logoutUrl   => '$baseUrl/auth/logout';
  static String get refreshUrl  => '$baseUrl/auth/refresh';

  // ─── Services ────────────────────────────────────────
  static String get servicesUrl           => '$baseUrl/services';
  static String get categoriesUrl         => '$baseUrl/categories';
  static String get workerServicesUrl     => '$baseUrl/worker-services';
  static String serviceUrl(String id)     => '$baseUrl/services/$id';
  // الإصلاح: endpoint الصحيح لإرسال طلب على خدمة
  static String serviceRequestUrl(String id) => '$baseUrl/services/$id/request';

  // ─── Posts ───────────────────────────────────────────
  static String get postsUrl           => '$baseUrl/posts';
  static String get publicPostsUrl     => '$baseUrl/posts/public';
  static String get myOffersUrl        => '$baseUrl/posts/me/offers';
  static String get postCategoriesUrl  => '$baseUrl/post-categories';
  static String postUrl(String id)  => '$baseUrl/posts/$id';
  static String postOffersUrl(String pid)              => '$baseUrl/posts/$pid/offers';
  static String postOfferUrl(String pid, String oid)   => '$baseUrl/posts/$pid/offers/$oid';
  static String postOfferActionUrl(String pid, String oid, String action) =>
      '$baseUrl/posts/$pid/offers/$oid/$action';
  static String editOfferUrl(String pid, String oid) =>
      '$baseUrl/posts/$pid/offers/$oid';

  // ─── Reports ─────────────────────────────────────────
  static String get reportsUrl   => '$baseUrl/reports';
  static String get myReportsUrl => '$baseUrl/reports/my';

  // ─── Users ───────────────────────────────────────────
  static String userUrl(String id)           => '$baseUrl/users/$id';
  static String userByEmailUrl(String email) => '$baseUrl/users?email=$email';
  static String reviewsUrl(String email)      => '$baseUrl/users/$email/reviews';
  static String reviewUrl(String id)          => '$baseUrl/users/reviews/$id';
  static String canReviewUrl(String email)    => '$baseUrl/users/$email/can-review';
  static String conductSummaryUrl(String email) => '$baseUrl/users/$email/conduct-summary';
  static String get conductReportUrl          => '$baseUrl/users/conduct-report';

  // ─── Requests ────────────────────────────────────────
  static String requestsUserUrl(String userId)    => '$baseUrl/requests/user/$userId';
  static String requestsWorkerUrl(String email)   => '$baseUrl/requests/worker/$email';
  static String requestUserCompletedUrl(String e) => '$baseUrl/requests/user/$e/completed';
  static String requestWorkerCompletedUrl(String e)=> '$baseUrl/requests/worker/$e/completed';
  static String requestUrl(String id)             => '$baseUrl/requests/$id';
  static String requestAcceptUrl(String id)          => '$baseUrl/requests/$id/accept';
  static String requestReadyUrl(String id)           => '$baseUrl/requests/$id/ready';
  static String requestProposeDeadlineUrl(String id) => '$baseUrl/requests/$id/propose-deadline';
  static String requestConfirmDeadlineUrl(String id) => '$baseUrl/requests/$id/confirm-deadline';

  // ─── Chat ────────────────────────────────────────────
  static String messagesUrl(String s, String r)  => '$baseUrl/messages/$s/$r';
  static String conversationsUrl(String email)   => '$baseUrl/conversations/$email';
  static String markReadUrl(String msgId)        => '$baseUrl/messages/$msgId/read';
  static String toggleBlockUrl(String email)     => '$baseUrl/toggle-block/$email';
  static String blockStatusUrl(String email)     => '$baseUrl/block-status/$email';
  static String presenceUrl(String email)       => '$baseUrl/presence/$email';

  // ─── Safe Area Sessions (Contract) ──────────────────
  static String get safeAreaSessionsUrl       => '$baseUrl/safe-area-sessions';
  static String get mySafeAreaSessionsUrl     => '$baseUrl/safe-area-sessions/my';
  static String safeAreaSessionUrl(String id) => '$baseUrl/safe-area-sessions/$id';
  static String safeAreaSessionAcceptUrl(String id) =>
      '$baseUrl/safe-area-sessions/$id/accept';
  static String safeAreaSessionRejectUrl(String id) =>
      '$baseUrl/safe-area-sessions/$id/reject';

  // ─── Safe Area ───────────────────────────────────────
  static String safeAreaUploadUrl(String id)            => '$baseUrl/safe-area/$id/upload';
  static String safeAreaPreviewUrl(String id)           => '$baseUrl/safe-area/$id/preview';
  static String safeAreaWorkerPreviewUrl(String id)     => '$baseUrl/safe-area/$id/worker-preview';
  static String safeAreaProposePriceUrl(String id)      => '$baseUrl/safe-area/$id/propose-price';
  static String safeAreaConfirmPriceUrl(String id)      => '$baseUrl/safe-area/$id/confirm-price';
  static String safeAreaPaymentUrl(String id)           => '$baseUrl/safe-area/$id/send-payment';
  static String safeAreaPaymentStatusUrl(String id)     => '$baseUrl/safe-area/$id/payment-status';
  static String safeAreaConfirmUrl(String id)           => '$baseUrl/safe-area/$id/confirm';
  static String safeAreaConfirmInPersonUrl(String id)   => '$baseUrl/safe-area/$id/confirm-inperson';
  static String safeAreaDownloadUrl(String id)          => '$baseUrl/safe-area/$id/download';
  static String workerBalanceUrl(String email)          => '$baseUrl/safe-area/balance/$email';

  // ─── WebSocket ───────────────────────────────────────
  static String chatWsUrl(String email, String token) =>
      '$wsBaseUrl/ws/chat/$email?token=$token';
  static String notificationsWsUrl(String email, String token) =>
      '$wsBaseUrl/ws/notifications/$email?token=$token';

  // ─── SharedPreferences keys ──────────────────────────
  static const String kAccessToken  = 'access_token';
  static const String kRefreshToken = 'refresh_token';
  static const String kUserType     = 'user_type';
  static const String kEmail        = 'email';
  static const String kUserId       = 'user_id';
  static const String kUsername     = 'username';
}