import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(MyApp());
}
const local = "http://127.0.0.1:8000";
 const prod = "https://ai-image-editor-web.onrender.com"; 
 const backendUrl = "$prod/api";

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter AI Image Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
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
      withData: true,
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
        const SnackBar(content: Text("Please select an image")),
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
          filename: fileName ?? 'image.png',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload Error: $e")),
      );
    }
  }

  Future<void> pollJobResult(String jobId) async {
    const pollInterval = Duration(seconds: 2);
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
          resultUrl = data['result_url'];
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
      SnackBar(content: Text("Open the image in a new tab to download")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter AI Image Editor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: pickImage,
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Center(
                      child: imageBytes != null
                          ? Image.memory(imageBytes!, fit: BoxFit.contain)
                          : const Text(
                              "Click to select an image",
                              style: TextStyle(color: Colors.blueGrey),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: promptController,
                  decoration: const InputDecoration(
                    labelText: "Enter your prompt",
                    border: OutlineInputBorder(),
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: loading ? null : uploadAndEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text("Generate / Edit"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                if (loading) const Center(child: CircularProgressIndicator()),
                if (resultUrl != null) ...[
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(resultUrl!),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: downloadImage,
                    icon: const Icon(Icons.download),
                    label: const Text("Download"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
