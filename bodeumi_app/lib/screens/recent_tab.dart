import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../models/photo.dart';
import '../services/api_service.dart';
import '../utils/media_helper.dart';

const _gradientDecoration = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF3E8FF),
      Color(0xFFFCE4EC),
    ],
  ),
);

/// A group of photos uploaded by the same person around the same time.
class _UploadGroup {
  final String uploaderName;
  final DateTime uploadedAt;
  final List<Photo> photos;

  _UploadGroup({
    required this.uploaderName,
    required this.uploadedAt,
    required this.photos,
  });
}

class RecentTab extends StatefulWidget {
  final VoidCallback onFavoriteChanged;

  const RecentTab({super.key, required this.onFavoriteChanged});

  @override
  State<RecentTab> createState() => RecentTabState();
}

class RecentTabState extends State<RecentTab> {
  List<Photo> _allPhotos = [];
  List<_UploadGroup> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void reload() => _load();

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final photos = await ApiService.getRecent(limit: 50);
      setState(() {
        _allPhotos = photos;
        _groups = _groupPhotos(photos);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  /// Group photos by uploader_name + upload time window (within 1 hour)
  List<_UploadGroup> _groupPhotos(List<Photo> photos) {
    if (photos.isEmpty) return [];

    final groups = <_UploadGroup>[];
    String currentName = photos.first.uploaderName;
    DateTime currentTime = photos.first.uploadedAt;
    List<Photo> currentPhotos = [photos.first];

    for (int i = 1; i < photos.length; i++) {
      final photo = photos[i];
      final timeDiff = currentTime.difference(photo.uploadedAt).inMinutes.abs();

      if (photo.uploaderName == currentName && timeDiff < 60) {
        currentPhotos.add(photo);
      } else {
        groups.add(_UploadGroup(
          uploaderName: currentName,
          uploadedAt: currentTime,
          photos: currentPhotos,
        ));
        currentName = photo.uploaderName;
        currentTime = photo.uploadedAt;
        currentPhotos = [photo];
      }
    }
    groups.add(_UploadGroup(
      uploaderName: currentName,
      uploadedAt: currentTime,
      photos: currentPhotos,
    ));

    return groups;
  }

  int _flatIndexOf(Photo photo) {
    return _allPhotos.indexWhere((p) => p.id == photo.id);
  }

  void _openPhotoView(Photo photo) {
    final index = _flatIndexOf(photo);
    if (index < 0) return;

    openMedia(
      context: context,
      photos: _allPhotos,
      index: index,
      onDelete: (p) async {
        await ApiService.deletePhoto(p.id);
        reload();
      },
      onFavoriteToggle: (p) async {
        final updated = await ApiService.toggleFavorite(p.id);
        widget.onFavoriteChanged();
        return updated;
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('M월 d일').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('최신 업로드'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Container(
        decoration: _gradientDecoration,
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _groups.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.schedule, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            '아직 업로드된 사진이 없습니다',
                            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _groups.length,
                        itemBuilder: (context, index) {
                          final group = _groups[index];
                          return _UploadGroupCard(
                            group: group,
                            onPhotoTap: _openPhotoView,
                            formatTime: _formatTime,
                          );
                        },
                      ),
                    ),
        ),
      ),
    );
  }
}

class _UploadGroupCard extends StatelessWidget {
  final _UploadGroup group;
  final void Function(Photo photo) onPhotoTap;
  final String Function(DateTime dt) formatTime;

  const _UploadGroupCard({
    required this.group,
    required this.onPhotoTap,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final name = group.uploaderName.isEmpty ? '익명' : group.uploaderName;
    final count = group.photos.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      color: Colors.white.withAlpha(180),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: name + count + time
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE1BEE7),
                  child: Text(
                    name.characters.first,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A1B9A),
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$name님이 $count장을 공유했습니다',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatTime(group.uploadedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Photo grid
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const crossAxisCount = 3;
                const spacing = 4.0;
                final itemWidth =
                    (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                        crossAxisCount;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: group.photos.map((photo) {
                    return GestureDetector(
                      onTap: () => onPhotoTap(photo),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: itemWidth,
                          height: itemWidth,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Hero(
                                tag: 'photo_${photo.id}',
                                child: CachedNetworkImage(
                                  imageUrl:
                                      ApiService.imageUrl(photo.thumbnailUrl),
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      Container(color: Colors.grey[200]),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.broken_image,
                                        color: Colors.grey, size: 24),
                                  ),
                                ),
                              ),
                              if (photo.isVideo)
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(100),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.play_arrow,
                                        color: Colors.white, size: 20),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
