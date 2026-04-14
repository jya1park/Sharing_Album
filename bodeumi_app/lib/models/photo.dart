class Photo {
  final String id;
  final String originalFilename;
  final String thumbnailUrl;
  final String originalUrl;
  final int fileSize;
  final DateTime? takenAt;
  final DateTime uploadedAt;
  final String monthFolder;

  Photo({
    required this.id,
    required this.originalFilename,
    required this.thumbnailUrl,
    required this.originalUrl,
    required this.fileSize,
    this.takenAt,
    required this.uploadedAt,
    required this.monthFolder,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'],
      originalFilename: json['original_filename'],
      thumbnailUrl: json['thumbnail_url'],
      originalUrl: json['original_url'],
      fileSize: json['file_size'],
      takenAt: json['taken_at'] != null ? DateTime.parse(json['taken_at']) : null,
      uploadedAt: DateTime.parse(json['uploaded_at']),
      monthFolder: json['month_folder'],
    );
  }
}
