class OfferData {
  final String id;
  final String postTitle;
  final String workerEmail;
  final String userName;
  final String createdAt;
  final String status;
  final String? deadline;
  final bool safeAreaActive;

  OfferData({
    required this.id,
    required this.postTitle,
    required this.workerEmail,
    required this.userName,
    required this.createdAt,
    required this.status,
    this.deadline,
    required this.safeAreaActive,
  });
}
