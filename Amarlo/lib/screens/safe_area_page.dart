import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fourthapp/models/review.dart';
import 'package:provider/provider.dart';
import 'package:fourthapp/screens/safe_area_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fourthapp/models/request_data.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fourthapp/screens/request_provider.dart';
import 'package:fourthapp/services/api_service.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter/services.dart';

class SafeAreaPage extends StatefulWidget {
  final RequestData request;
  final bool isUserBuyer;

  const SafeAreaPage(
      {Key? key, required this.request, required this.isUserBuyer})
      : super(key: key);

  @override
  _SafeAreaPageState createState() => _SafeAreaPageState();
}

class _SafeAreaPageState extends State<SafeAreaPage> {
  late SafeAreaProvider safeAreaProvider;
  String? _selectedFilePath;
  String? _existingFileBase64;
  Uint8List? _previewImageBytes;
  TextEditingController _amountController = TextEditingController();
  String? _paymentStatus;
  TextEditingController _reviewController = TextEditingController();
  double _rating = 0.0;
  bool _isReviewSubmitted = false;

  @override
  void initState() {
    super.initState();
    safeAreaProvider = Provider.of<SafeAreaProvider>(context, listen: false);
    _fetchExistingFile();
    _checkPaymentStatus();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [
      SystemUiOverlay.bottom,
      SystemUiOverlay.top,
    ]);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));
  }

  @override
  void dispose() {
    // Reset to the default mode when the screen is disposed
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _selectFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _selectedFilePath = result.files.first.path;
      });
    }
  }

  Future<void> _previewFile() async {
    if (_existingFileBase64 != null) {
      final bytes = base64Decode(_existingFileBase64!);
      setState(() {
        _previewImageBytes = bytes;
      });
    }
  }

  Future<void> _markRequestReady(String requestId) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) return;

    try {
      final response = await http.put(
        Uri.parse('http://10.0.2.2:8000/requests/$requestId/ready'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        Provider.of<RequestProvider>(context, listen: false)
            .updateRequestStatus(requestId, 'ready_for_delivery');
        _showSnackBar('Request marked as Ready for Delivery');
      } else {
        _showSnackBar('Failed to mark request as ready');
        print("Error marking request as ready: ${response.body}");
      }
    } catch (e) {
      _showSnackBar('Error marking request as ready: $e');
      print("Error marking request as ready: $e");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _fetchExistingFile() async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) return;

    final response = await http.get(
      Uri.parse(
          'http://10.0.2.2:8000/safe-area/${widget.request.id}/fetch-file'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _existingFileBase64 = data['work_file'];
        if (_existingFileBase64 != null) {
          _previewImageBytes =
              base64Decode(_existingFileBase64!); // تحديث  _previewImageBytes
        }
      });
    } else {
      print('Error fetching existing file: ${response.statusCode}');
    }
  }

  Future<void> _saveImageToGallery(Uint8List imageBytes) async {
    try {
      var status = await Permission.storage.request();

      if (!status.isGranted) {
        print("Permission not granted");
        return;
      }

      final result = await ImageGallerySaverPlus.saveImage(
        imageBytes,
        quality: 100,
        name: "download_${DateTime.now().millisecondsSinceEpoch}",
      );

      print("Image saved: $result");
    } catch (e) {
      print("Save Error: $e");
    }
  }

  // Function to check payment status and update isPaymentConfirmed
  Future<void> _checkPaymentStatus() async {
    bool isPaymentReceived =
        await safeAreaProvider.getPaymentStatus(widget.request.id);
    setState(() {
      safeAreaProvider.isPaymentConfirmed = isPaymentReceived;
    });
  }

  Future<void> _submitReview() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('user_id');
    final currentUserEmail = prefs.getString('email');

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please log in to add a review.')));
      return;
    }

    //  لا حاجة للتحقق  من مراجعة  النفس

    if (_rating == 0.0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Please select a rating.')));
      return;
    }

    try {
      Review newReview = Review(
        rating: _rating.toInt(),
        comment: _reviewController.text,
        reviewerUsername: prefs.getString("username") ?? '',
        reviewerEmail: currentUserEmail ?? '',
      );

      await ApiService.addReview(widget.request.workerEmail, newReview);

      _reviewController.clear();
      setState(() {
        _rating = 0.0;
        _isReviewSubmitted = true;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Review added successfully!')));
    } catch (e) {
      print("Failed to add review: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to add review.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Safe Area - ${widget.request.serviceName}'),
      ),
      body: Center(
        child: Consumer<SafeAreaProvider>(
          builder: (context, safeAreaProvider, child) {
            if (widget.isUserBuyer) {
              // User (Buyer) View
              // Wrap User View with Consumer for automatic rebuilds
              return Consumer<SafeAreaProvider>(
                builder: (context, safeAreaProvider, child) {
                  if (safeAreaProvider.isWorkUploaded &&
                      !safeAreaProvider.isPaymentConfirmed) {
                    // Work is uploaded, but payment not confirmed
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_existingFileBase64 != null)
                          Image.memory(base64Decode(_existingFileBase64!))
                        else
                          const CircularProgressIndicator(),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration:
                                InputDecoration(labelText: 'Enter Amount'),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            int amount = int.parse(_amountController.text);
                            await safeAreaProvider.sendPayment(
                                widget.request.id, amount);
                            _checkPaymentStatus();
                          },
                          child: const Text('Send Payment'),
                        ),
                        if (_paymentStatus != null) Text(_paymentStatus!),
                      ],
                    );
                  } else if (safeAreaProvider.isPaymentConfirmed &&
                      _existingFileBase64 != null &&
                      !_isReviewSubmitted) {
                    // Payment is confirmed, but review not submitted yet
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_existingFileBase64 != null)
                          Image.memory(base64Decode(_existingFileBase64!))
                        else
                          const CircularProgressIndicator(),

                        //  قسم التقييم
                        _buildReviewSection(), //  استدعاء الدالة الجديدة
                      ],
                    );
                  } else if (safeAreaProvider.isPaymentConfirmed &&
                      _existingFileBase64 != null &&
                      _isReviewSubmitted) {
                    // Payment is confirmed, and review is submitted
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_existingFileBase64 != null)
                          Image.memory(base64Decode(_existingFileBase64!))
                        else
                          const CircularProgressIndicator(),
                        ElevatedButton(
                          onPressed: () async {
                            if (_previewImageBytes != null) {
                              await safeAreaProvider.downloadWork(context,
                                  widget.request.id, _existingFileBase64!);
                              _saveImageToGallery(_previewImageBytes!);
                            } else {
                              print("Error: _previewImageBytes is null");
                            }
                          },
                          child: const Text('Download'),
                        ),
                      ],
                    );
                  } else {
                    return const CircularProgressIndicator();
                  }
                },
              );
            } else {
              // Worker View
              if (widget.request.status == 'accepted') {
                if (_selectedFilePath != null) {
                  // File is selected, ready to upload
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Selected File: $_selectedFilePath'),
                      ElevatedButton(
                        onPressed: () {
                          safeAreaProvider.uploadWork(
                              widget.request.id, _selectedFilePath!);
                          setState(() {
                            _selectedFilePath = null;
                            _existingFileBase64 =
                                safeAreaProvider.existingFileBase64;
                          });
                        },
                        child: const Text('Upload Work'),
                      ),
                    ],
                  );
                } else if (safeAreaProvider.isFileUploaded(widget.request.id)) {
                  // File is uploaded - Show image and "Ready" button
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_existingFileBase64 != null)
                        Image.memory(base64Decode(_existingFileBase64!))
                      else
                        const CircularProgressIndicator(),
                      ElevatedButton(
                        onPressed: _selectFile,
                        child: const Text('Select New File'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          _markRequestReady(widget.request.id);
                        },
                        child: const Text('Ready'),
                      ),
                    ],
                  );
                } else {
                  // No file uploaded yet - Show "Select Work File" button
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _selectFile,
                        child: const Text('Select Work File'),
                      ),
                    ],
                  );
                }
              } else if (widget.request.status == 'ready_for_delivery') {
                // Show a message indicating that the work is ready
                // and payment received if available.
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Work is ready for delivery.'),
                    if (safeAreaProvider.receivedPayments
                        .containsKey(widget.request.id))
                      Text(
                        'Payment Received: ${safeAreaProvider.receivedPayments[widget.request.id]}',
                        style: TextStyle(color: Colors.green, fontSize: 16),
                      ),
                  ],
                );
              } else {
                return Text('Waiting for payment...');
              }
            }
          },
        ),
      ),
    );
  }

  //  دالة  لبناء قسم التقييم
  Widget _buildReviewSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rate and Review',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          RatingBar.builder(
            initialRating: _rating,
            minRating: 1,
            direction: Axis.horizontal,
            allowHalfRating: false,
            itemCount: 5,
            itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
            itemBuilder: (context, _) => Icon(
              Icons.star,
              color: Colors.amber,
            ),
            onRatingUpdate: (rating) {
              setState(() {
                _rating = rating;
              });
            },
          ),
          SizedBox(height: 10),
          TextField(
            controller: _reviewController,
            decoration: InputDecoration(
              hintText: 'Write your review (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              _submitReview();
              setState(() {
                _isReviewSubmitted = true;
              });
            },
            child: Text('Submit Review'),
          ),
        ],
      ),
    );
  }
}
