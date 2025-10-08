import 'dart:typed_data';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

void main() {
  runApp(const MyApp());
}

const backendUrl = "https://ai-image-editor-web.onrender.com/api";

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

class Job {
  final String prompt;
  final String imageUrl;
  final DateTime createdAt;

  Job({required this.prompt, required this.imageUrl, required this.createdAt});
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController promptController = TextEditingController();
  final TextEditingController imageUrlController = TextEditingController();

  List<Uint8List> imagesBytes = [];
  List<String> fileNames = [];
  String? resultUrl;
  bool loading = false;

  List<Job> jobHistory = [];

  // Çoklu dosya seçimi
  Future<void> pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        imagesBytes = result.files.map((f) => f.bytes!).toList();
        fileNames = result.files.map((f) => f.name).toList();
        imageUrlController.clear();
        resultUrl = null;
      });
      print("🖼 ${imagesBytes.length} images selected: $fileNames");
    }
  }

  // Backend’e gönderim
  Future<void> uploadAndEdit() async {
    if (promptController.text.isEmpty) return;
    if (imagesBytes.isEmpty && imageUrlController.text.isEmpty) return;

    setState(() => loading = true);

    try {
      final uri = Uri.parse('$backendUrl/jobs');
      final request = http.MultipartRequest('POST', uri);
      request.fields['prompt'] = promptController.text;
      request.fields['model'] = 'image-to-image';

      // Çoklu resimleri ekle
      for (int i = 0; i < imagesBytes.length; i++) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'images',
            imagesBytes[i],
            filename: fileNames[i],
            contentType: MediaType('image', 'png'),
          ),
        );
      }

      if (imageUrlController.text.isNotEmpty) {
        request.fields['image_urls'] = imageUrlController.text.trim();
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final resJson = jsonDecode(response.body);
      print("📩 resJson: $resJson");

      final urls = resJson['result_urls'] as List<dynamic>? ?? [];
      if (urls.isNotEmpty) {
        setState(() {
          resultUrl = urls[0]; // ilk resmi göster
          // job history ekle
          jobHistory.insert(
            0,
            Job(
              prompt: promptController.text,
              imageUrl: urls[0],
              createdAt: DateTime.now(),
            ),
          );
        });
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("No image returned")));
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Upload Error: $e")));
    } finally {
      setState(() => loading = false);
    }
  }

  // Seçilen resimleri yatay preview
  Widget buildSelectedImages() {
    if (imagesBytes.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 150,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: imagesBytes.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Image.memory(
                entry.value,
                width: 150,
                height: 150,
                fit: BoxFit.cover,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Resmi gösterme ve indirme
  Widget buildResultImage(String imageUrl, DateTime date) {
    final formattedDate =
        "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 300,
            ),
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              onPressed: () async {
                final response = await http.get(Uri.parse(imageUrl));
                final blob = html.Blob([response.bodyBytes]);
                final url = html.Url.createObjectUrlFromBlob(blob);
                final anchor = html.AnchorElement(href: url)
                  ..download = imageUrl.split('/').last
                  ..click();
                html.Url.revokeObjectUrl(url);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Yüklenme tarihi: $formattedDate",
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Image Editor")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // GestureDetector içinde hem tıklama hem local preview
                GestureDetector(
                  onTap: pickImages,
                  child: Container(
                    height: 180,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: imagesBytes.isNotEmpty
                        ? buildSelectedImages()
                        : const Center(child: Text("Click to select images")),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(child: Text("OR")),
                const SizedBox(height: 10),
                TextField(
                  controller: imageUrlController,
                  decoration: const InputDecoration(
                    labelText: "Enter image URL (optional)",
                    border: OutlineInputBorder(),
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
                ),
                const SizedBox(height: 16),
                if (loading) const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 20),
                // Son işlem resmi
                if (resultUrl != null) buildResultImage(resultUrl!, DateTime.now()),
                const SizedBox(height: 20),
                // Job history
                const Divider(),
                const SizedBox(height: 8),
                const Text("Job History",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Column(
                  children: jobHistory
                      .map((job) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: buildResultImage(job.imageUrl, job.createdAt),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
