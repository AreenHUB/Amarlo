class Service {
  final String id;
  final String name;
  final String location;
  final double price;
  final String workerEmail;
  final String? imageBase64;

  Service({
    required this.id,
    required this.name,
    required this.location,
    required this.price,
    required this.workerEmail,
    this.imageBase64,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json["_id"],
      name: json["name"],
      location: json["location"],
      price: json["price"].toDouble(),
      workerEmail: json["worker_email"],
      imageBase64: json["imageBase64"],
    );
  }
}
