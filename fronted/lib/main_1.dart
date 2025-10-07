import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const MyApp());
}

const backendUrl = "http://127.0.0.1:8000/api"; // Mock backend için lokal
// const backendUrl = "https://ai-image-editor-web.onrender.com/api"; // Prod için

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter AI Image Editor',
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

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
        resultUrl = null;
      });
    }
  }

 Future<void> uploadAndEdit() async {
  if (imageBytes == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please select an image first")),
    );
    return;
  }

  if (promptController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please enter a prompt")),
    );
    return;
  }

  setState(() => loading = true);

  final request = http.MultipartRequest(
    'POST',
    Uri.parse('$backendUrl/jobs'),
  )
    ..fields['prompt'] = promptController.text
    ..files.add(
      http.MultipartFile.fromBytes(
        'image',
        imageBytes!,
        filename: fileName ?? 'image.png', // null ise default ver
      ),
    );

  try {
    final response = await request.send();
    final resStr = await response.stream.bytesToString();
    final resJson = jsonDecode(resStr);

    final jobId = resJson['job_id'];
    if (jobId == null) throw Exception("Job ID not returned");

    await pollJobResult(jobId);
  } catch (e) {
    setState(() => loading = false);
    print("Upload error: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $e")),
    );
  }
}

  Future<void> pollJobResult(String jobId) async {
    const pollInterval = Duration(seconds: 1); // Mock hızlı çalışır
    while (true) {
      final res = await http.get(Uri.parse('$backendUrl/jobs/$jobId'));
      if (res.statusCode != 200) {
        setState(() => loading = false);
        throw Exception("Failed to fetch job: ${res.body}");
      }

      final data = jsonDecode(res.body);
      final status = data['status'];
      if (status == 'done') {
        setState(() {
          resultUrl = data['image_url'] ?? data['result_url'];
          loading = false;
        });
        break;
      } else if (status == 'failed') {
        setState(() => loading = false);
        throw Exception("Job failed: ${data['error']}");
      }
      await Future.delayed(pollInterval);
    }
  }

  Future<void> downloadImage() async {
    if (resultUrl == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Open the image in a new tab to download")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter AI Image Editor')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(onPressed: pickImage, child: const Text("Select Image")),
            const SizedBox(height: 10),
            TextField(
              controller: promptController,
              decoration: const InputDecoration(labelText: "Prompt"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: loading ? null : uploadAndEdit,
              child: const Text("Generate/Edit"),
            ),
            const SizedBox(height: 10),
            if (loading) const CircularProgressIndicator(),
            if (resultUrl != null) ...[
              const SizedBox(height: 20),
              Image.network(resultUrl!),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: downloadImage, child: const Text("Download")),
            ]
          ],
        ),
      ),
    );
  }
}
