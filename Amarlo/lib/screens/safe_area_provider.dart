import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:typed_data';

class SafeAreaProvider with ChangeNotifier {
  bool _isWorkUploaded = false;
  bool _isPaymentConfirmed = false;
  Map<String, bool> _isFileUploaded =
      {}; // To store file upload status per request
  String? _existingFileBase64;
  bool get isWorkUploaded => _isWorkUploaded;
  bool get isPaymentConfirmed => _isPaymentConfirmed;
  String? get existingFileBase64 => _existingFileBase64;
  Map<String, double> receivedPayments = {}; //  لتخزين المبالغ المستلمةئ

  // Function to get the file upload status for a specific request
  bool isFileUploaded(String requestId) {
    return _isFileUploaded[requestId] ??
        false; // Default to false if not foundئئ
  }

  set isPaymentConfirmed(bool value) {
    //  إضافة  setter
    _isPaymentConfirmed = value;
    notifyListeners();
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> confirmPayment(String requestId) async {
    _isPaymentConfirmed = true;
    notifyListeners();
  }

  Future<void> uploadWork(String requestId, String filePath) async {
    // ... (Logic to upload file to your backend, using filePath)

    final accessToken = await _getAccessToken();
    if (accessToken == null) return;

    var request = http.MultipartRequest(
        'POST', Uri.parse('http://10.0.2.2:8000/safe-area/$requestId/upload'));
    request.headers.addAll({'Authorization': 'Bearer $accessToken'});
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    var response = await request.send();

    if (response.statusCode == 200) {
      _isWorkUploaded = true;
      _isFileUploaded[requestId] = true;

      //  إضافة الأسطر التالية:
      final responseData =
          await response.stream.bytesToString(); // Get the response data
      final data = jsonDecode(responseData); // Decode the JSON response
      _existingFileBase64 = data['file_url']; // Update _existingFileBase64

      notifyListeners();
    } else {
      // Handle error
      print('Error uploading work: ${response.statusCode}');
    }
  }

  // ... (باقي كود  SafeAreaProvider)

  Future<void> downloadWork(
    BuildContext context,
    String requestId,
    String fileBase64,
  ) async {
    try {
      final Uint8List fileBytes = base64Decode(fileBase64);

      await FileSaver.instance.saveFile(
        name: "work_$requestId",
        bytes: fileBytes,
        ext: "bin", // generic file extension
        mimeType: MimeType.other,
      );

      _showSnackBar(
        context,
        "File downloaded successfully.",
      );
    } catch (e) {
      print("Download Error: $e");

      _showSnackBar(
        context,
        "Failed to download file.",
      );
    }
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<bool> getPaymentStatus(String requestId) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) return false;

    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/safe-area/$requestId/payment-status'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['payment_received'];
      } else {
        print('Error fetching payment status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error fetching payment status: $e');
      return false;
    }
  }

  Future<void> sendPayment(String requestId, int amount) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) return;

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/safe-area/$requestId/send-payment'),
        headers: {
          'Content-Type': 'application/json', // Ensure content type is JSON
          'Authorization': 'Bearer $accessToken'
        },
        body: jsonEncode(
            {'amount': amount}), // Make sure amount is sent as an integer
      );

      if (response.statusCode == 200) {
        final responseData = await response.body;
        final data = jsonDecode(responseData);

        // Update receivedPayments in the provider
        receivedPayments[requestId] = data['amount'];
        _isPaymentConfirmed = true;

        notifyListeners();
      } else {
        print('Error sending payment: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending payment: $e');
    }
  }
}
