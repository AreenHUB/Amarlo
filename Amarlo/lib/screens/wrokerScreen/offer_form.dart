import 'package:flutter/material.dart';

class OfferForm extends StatefulWidget {
  final String postId;
  final Function(String content, double price) onSubmit;

  const OfferForm({
    Key? key,
    required this.postId,
    required this.onSubmit,
  }) : super(key: key);

  @override
  _OfferFormState createState() => _OfferFormState();
}

class _OfferFormState extends State<OfferForm> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _contentController,
              decoration: InputDecoration(labelText: 'Content'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter content';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _priceController,
              decoration: InputDecoration(labelText: 'Price'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a price';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  widget.onSubmit(
                    _contentController.text,
                    double.parse(_priceController.text),
                  );
                  Navigator.of(context).pop();
                }
              },
              child: Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
