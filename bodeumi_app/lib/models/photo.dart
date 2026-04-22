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
  final List<String>? visibleTo;

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
    this.visibleTo,
  });

  bool get isVideo => mediaType == 'video';
  bool get isPrivate => visibleTo != null && visibleTo!.isNotEmpty;

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
      visibleTo: json['visible_to'] != null
          ? List<String>.from(json['visible_to'])
          : null,
    );
  }

  Photo copyWith({bool? isFavorite, List<String>? visibleTo}) {
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
      visibleTo: visibleTo ?? this.visibleTo,
    );
  }
}
