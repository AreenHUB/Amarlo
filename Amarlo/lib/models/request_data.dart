
class RequestData {
  final String id;
  final String serviceName;
  String status; // Now non-final
  final String createdAt;
  String? deadline; // Now non-final
  final String userName;
  String workerEmail;

  RequestData({
    required this.id,
    required this.serviceName,
    required this.status,
    required this.createdAt,
    this.deadline,
    required this.userName,
    required this.workerEmail,
  });

  factory RequestData.fromJson(Map<String, dynamic> json) {
    return RequestData(
      id: json['_id'],
      serviceName: json['service_name'],
      status: json['status'],
      createdAt: json['created_at'],
      deadline: json['deadline'],
      userName: json['user_name'],
      workerEmail: json['worker_email'],
    );
  }
}
