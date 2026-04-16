class Photo {
  final String id;
  final String originalFilename;
  final String thumbnailUrl;
  final String originalUrl;
  final int fileSize;
  final DateTime? takenAt;
  final DateTime uploadedAt;
  final String monthFolder;
  final String mediaType;
  final bool isFavorite;
  final String uploaderName;

  Photo({
    required this.id,
    required this.originalFilename,
    required this.thumbnailUrl,
    required this.originalUrl,
    required this.fileSize,
    this.takenAt,
    required this.uploadedAt,
    required this.monthFolder,
    this.mediaType = 'photo',
    this.isFavorite = false,
    this.uploaderName = '',
  });

  bool get isVideo => mediaType == 'video';

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
      mediaType: json['media_type'] ?? 'photo',
      isFavorite: json['is_favorite'] ?? false,
      uploaderName: json['uploader_name'] ?? '',
    );
  }

  Photo copyWith({bool? isFavorite}) {
    return Photo(
      id: id,
      originalFilename: originalFilename,
      thumbnailUrl: thumbnailUrl,
      originalUrl: originalUrl,
      fileSize: fileSize,
      takenAt: takenAt,
      uploadedAt: uploadedAt,
      monthFolder: monthFolder,
      mediaType: mediaType,
      isFavorite: isFavorite ?? this.isFavorite,
      uploaderName: uploaderName,
    );
  }
}
