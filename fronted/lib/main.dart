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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController promptController = TextEditingController();
  final TextEditingController imageUrlController = TextEditingController();

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
        imageUrlController.clear();
        resultUrl = null;
      });
      print("🖼 Image selected: $fileName");
    }
  }

  Future<void> uploadAndEdit() async {
    if (promptController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a prompt")),
      );
      return;
    }

    if (imageBytes == null && imageUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an image or enter a URL")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final uri = Uri.parse('$backendUrl/jobs');
      final request = http.MultipartRequest('POST', uri);
      request.fields['prompt'] = promptController.text;
      request.fields['model'] = 'image-to-image';

      if (imageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes!,
            filename: fileName ?? 'image.png',
            contentType: MediaType('image', 'png'),
          ),
        );
      } else if (imageUrlController.text.isNotEmpty) {
        request.fields['image_url'] = imageUrlController.text.trim();
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print("📩 Raw backend response: ${response.body}");
      final resJson = jsonDecode(response.body);
print("📩 resJson: $resJson");

// Tek URL string olduğu için direkt al
final imageUrl = resJson['result_url'] as String?;
if (imageUrl != null && imageUrl.isNotEmpty) {
  setState(() {
    resultUrl = imageUrl;
  });
} else {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("No image returned from server")),
  );
}

    } catch (e) {
      print("🔥 Upload Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload Error: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  Widget buildResultImage() {
    if (resultUrl == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final formattedDate =
        "${now.day.toString().padLeft(2,'0')}-${now.month.toString().padLeft(2,'0')}-${now.year} ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            Image.network(
              resultUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 300,
            ),
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              onPressed: () {
                final anchor = html.AnchorElement(href: resultUrl!)
                  ..target = 'blank'
                  ..download = resultUrl!.split('/').last;
                html.document.body!.append(anchor);
                anchor.click();
                anchor.remove();
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
                      child: (imageBytes != null)
                          ? Image.memory(imageBytes!, fit: BoxFit.contain)
                          : const Text("Click to select an image"),
                    ),
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
                buildResultImage(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
