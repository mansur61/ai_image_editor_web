import 'dart:typed_data';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

import 'model/job.dart';

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

  List<Uint8List> imagesBytes = [];
  List<String> fileNames = [];
  List<String> resultUrls = [];
  bool loading = false;

  List<Job> jobHistory = [];

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
        resultUrls.clear();
      });
      print("🖼 ${imagesBytes.length} images selected: $fileNames");
    }
  }

  Future<void> uploadAndEdit() async {
    if (promptController.text.isEmpty) return;
    if (imagesBytes.isEmpty && imageUrlController.text.isEmpty) return;

    setState(() {
      loading = true;
      jobHistory = [];
    });

    try {
      final uri = Uri.parse('$backendUrl/jobs');
      final request = http.MultipartRequest('POST', uri);
      request.fields['prompt'] = promptController.text;
      request.fields['model'] = 'image-to-image';

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

      final urls = List<String>.from(resJson['result_urls'] ?? []);
      if (urls.isNotEmpty) {
        setState(() {
          resultUrls = urls;
          jobHistory.insert(
            0,
            Job(
              prompt: promptController.text,
              imageUrls: urls,
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
 

  Widget buildComparisonSlider(String originalUrl, String resultUrl) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double sliderPosition = constraints.maxWidth / 2;
        return StatefulBuilder(builder: (context, setState) {
          return GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                sliderPosition += details.delta.dx;
                if (sliderPosition < 0) sliderPosition = 0;
                if (sliderPosition > constraints.maxWidth)
                  sliderPosition = constraints.maxWidth;
              });
            },
            child: Stack(
              children: [
                Image.network(
                  originalUrl,
                  width: constraints.maxWidth,
                  height: 200,
                  fit: BoxFit.cover,
                ),
                ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: sliderPosition / constraints.maxWidth,
                    child: Image.network(
                      resultUrl,
                      width: constraints.maxWidth,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  left: sliderPosition - 3,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

Widget buildComparisonJob(Job job) {
  final formattedDate =
      "${job.createdAt.day.toString().padLeft(2, '0')}-${job.createdAt.month.toString().padLeft(2, '0')}-${job.createdAt.year} ${job.createdAt.hour.toString().padLeft(2, '0')}:${job.createdAt.minute.toString().padLeft(2, '0')}";

  List<Widget> comparisonWidgets = [];

  for (int i = 0; i < imagesBytes.length; i++) {
    String original = "data:image/png;base64," + base64Encode(imagesBytes[i]);
    String result = job.imageUrls[i];

    comparisonWidgets.add(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildComparisonSlider(original, result),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Sol ve sağa hizala
            children: [
              Text(
                "Yüklenme tarihi: $formattedDate",
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              IconButton(
                icon: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.download,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                onPressed: () async {
                  final response = await http.get(Uri.parse(result));
                  final blob = html.Blob([response.bodyBytes]);
                  final urlBlob = html.Url.createObjectUrlFromBlob(blob);
                  final _ = html.AnchorElement(href: urlBlob)
                    ..download = result.split('/').last
                    ..click();
                  html.Url.revokeObjectUrl(urlBlob);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  return Column(children: comparisonWidgets);
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
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  "Job History",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Column(
                  children: jobHistory
                      .map((job) => buildComparisonJob(job))
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
