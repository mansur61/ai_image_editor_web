import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(MyApp());
}

const backendUrl = "https://<render-backend-url>/api";

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter AI Image Editor',
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController promptController = TextEditingController();
  Uint8List? imageBytes;
  String? fileName;
  String? resultUrl;
  bool loading = false;

  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true, // Web için gerekli
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        imageBytes = result.files.first.bytes;
        fileName = result.files.first.name;
      });
    }
  }

  Future<void> uploadAndEdit() async {
    if (imageBytes == null || promptController.text.isEmpty) return;

    setState(() => loading = true);

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$backendUrl/jobs'),
    )
      ..fields['prompt'] = promptController.text
      ..files.add(
        http.MultipartFile.fromBytes('image', imageBytes!, filename: fileName),
      );

    try {
      final response = await request.send();
      final resData = await response.stream.bytesToString();

      // Backend'den gelen gerçek URL'i buraya yerleştirin
      setState(() {
        loading = false;
        resultUrl = "<backend-res-dönüşündeki-url>";
      });
    } catch (e) {
      setState(() => loading = false);
      print("Upload error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Flutter AI Image Editor')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(onPressed: pickImage, child: Text("Select Image")),
            SizedBox(height: 10),
            TextField(
              controller: promptController,
              decoration: InputDecoration(labelText: "Prompt"),
            ),
            SizedBox(height: 10),
            ElevatedButton(onPressed: uploadAndEdit, child: Text("Generate/Edit")),
            SizedBox(height: 20),
            if (loading) CircularProgressIndicator(),
            if (resultUrl != null) ...[
              SizedBox(height: 20),
              Image.network(resultUrl!)
            ]
          ],
        ),
      ),
    );
  }
}
