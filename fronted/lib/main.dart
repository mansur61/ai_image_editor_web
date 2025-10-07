import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const MyApp());
}

const prod = "https://ai-image-editor-web.onrender.com";
const backendUrl = "$prod/api";

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter AI Image Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
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
  Uint8List? originalImageBytes;
  String? fileName;
  String? resultUrl;
  bool loading = false;

  List<Map<String, dynamic>> jobHistory = [];
  double sliderValue = 0.5;

  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        imageBytes = result.files.first.bytes;
        originalImageBytes = result.files.first.bytes;
        fileName = result.files.first.name;
        resultUrl = null;
        sliderValue = 0.5;
      });
      print("🖼 Image selected: $fileName, size=${imageBytes!.lengthInBytes} bytes");
    } else {
      print("⚠️ No image selected.");
    }
  }

  Future<void> uploadAndEdit() async {
    if (imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an image")),
      );
      print("❌ Upload canceled: No image selected.");
      return;
    }

    if (promptController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a prompt")),
      );
      print("❌ Upload canceled: Empty prompt.");
      return;
    }

    setState(() => loading = true);

    print("🚀 Starting upload...");
    print("Prompt: ${promptController.text}");
    print("Backend URL: $backendUrl/jobs");

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
      print("📩 Raw backend response: $resStr");

      final resJson = jsonDecode(resStr);
      print("📦 Parsed response: $resJson");

      final jobId = resJson['job_id'];
      if (jobId == null) throw Exception("Job ID not returned");

      print("✅ Job created successfully. ID: $jobId");
      await pollJobResult(jobId, promptController.text);
    } catch (e, stack) {
      print("🔥 Upload Error: $e");
      print("STACK TRACE:\n$stack");
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload Error: $e")),
      );
    }
  }

  Future<void> pollJobResult(String jobId, String prompt) async {
    const pollInterval = Duration(seconds: 2);
    print("🔁 Start polling job: $jobId");

    while (true) {
      final res = await http.get(Uri.parse('$backendUrl/jobs/$jobId'));
      print("⏳ Polling response: ${res.statusCode}, body: ${res.body}");

      if (res.statusCode != 200) {
        setState(() => loading = false);
        throw Exception("Failed to fetch job: ${res.body}");
      }

      final data = jsonDecode(res.body);
      final status = data['status'];

      print("📡 Job status: $status");

      if (status == 'done') {
        setState(() {
          resultUrl = data['result_url'] ?? '';
          loading = false;
          jobHistory.insert(0, {
            "id": jobId,
            "prompt": prompt,
            "status": status,
            "image_url": data['result_url'] ?? '',
          });
          originalImageBytes ??= imageBytes;
          sliderValue = 0.5;
        });
        print("✅ Job completed! Result URL: $resultUrl");
        break;
      } else if (status == 'failed') {
        setState(() => loading = false);
        print("❌ Job failed. Error: ${data['error']}");
        throw Exception("Job failed: ${data['error'] ?? 'Unknown error'}");
      }

      await Future.delayed(pollInterval);
    }
  }

  Widget buildBeforeAfterSlider() {
    if (resultUrl == null || originalImageBytes == null) return const SizedBox.shrink();

    return Column(
      children: [
        Stack(
          children: [
            Image.memory(originalImageBytes!, fit: BoxFit.cover, width: double.infinity, height: 300),
            ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: sliderValue.clamp(0.0, 1.0),
                child: Image.network(resultUrl!, fit: BoxFit.cover, width: double.infinity, height: 300),
              ),
            ),
          ],
        ),
        Slider(
          value: sliderValue,
          onChanged: (value) => setState(() => sliderValue = value),
        ),
      ],
    );
  }

  Future<void> downloadImage() async {
    if (resultUrl == null) return;
    print("💾 Download image triggered for URL: $resultUrl");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Open the image in a new tab to download")),
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
                      child: (imageBytes != null && imageBytes!.isNotEmpty)
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
                if ((resultUrl ?? '').isNotEmpty) ...[
                  const SizedBox(height: 20),
                  buildBeforeAfterSlider(),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: downloadImage,
                    icon: const Icon(Icons.download),
                    label: const Text("Download"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (jobHistory.isNotEmpty) ...[
                  const Text(
                    "Previous Edits",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: jobHistory.map((job) {
                      final imageUrl = job['image_url'] ?? '';
                      return ListTile(
                        leading: (imageUrl.isNotEmpty)
                            ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                            : const SizedBox(width: 50, height: 50),
                        title: Text(job['prompt'] ?? "No prompt"),
                        subtitle: Text(job['status'] ?? ""),
                        onTap: () {
                          setState(() {
                            resultUrl = imageUrl;
                            originalImageBytes ??= imageBytes;
                            sliderValue = 0.5;
                          });
                        },
                      );
                    }).toList(),
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
