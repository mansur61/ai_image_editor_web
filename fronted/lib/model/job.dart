class Job {
  final String prompt;
  final List<String> imageUrls; // artık liste
  final DateTime createdAt;

  Job({required this.prompt, required this.imageUrls, required this.createdAt});
}