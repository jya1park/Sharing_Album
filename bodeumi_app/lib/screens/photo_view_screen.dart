import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:intl/intl.dart';

import '../models/photo.dart';
import '../services/api_service.dart';

class PhotoViewScreen extends StatefulWidget {
  final List<Photo> photos;
  final int initialIndex;
  final Future<void> Function(Photo photo) onDelete;
  final Future<Photo> Function(Photo photo) onFavoriteToggle;

  const PhotoViewScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.onDelete,
    required this.onFavoriteToggle,
  });

  @override
  State<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<PhotoViewScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late List<Photo> _photos;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _photos = List.from(widget.photos);
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Photo get _currentPhoto => _photos[_currentIndex];

  String _formatDate(DateTime? takenAt, DateTime uploadedAt) {
    final date = takenAt ?? uploadedAt;
    return DateFormat('yyyy.MM.dd HH:mm').format(date);
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _toggleFavorite() async {
    try {
      final updated = await widget.onFavoriteToggle(_currentPhoto);
      setState(() {
        _photos[_currentIndex] = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('즐겨찾기 변경 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사진 삭제'),
        content: const Text('이 사진을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              navigator.pop(); // close dialog
              try {
                await widget.onDelete(_currentPhoto);
                if (mounted) {
                  navigator.pop(); // go back to grid
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('삭제 완료'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('삭제 실패: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showInfoSheet() {
    final photo = _currentPhoto;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '사진 정보',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _infoRow('파일명', photo.originalFilename),
              _infoRow('날짜', _formatDate(photo.takenAt, photo.uploadedAt)),
              _infoRow('크기', _formatFileSize(photo.fileSize)),
              if (photo.takenAt != null)
                _infoRow('촬영일', DateFormat('yyyy.MM.dd HH:mm').format(photo.takenAt!)),
              _infoRow('업로드', DateFormat('yyyy.MM.dd HH:mm').format(photo.uploadedAt)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${_photos.length}',
          style: const TextStyle(fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _currentPhoto.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _currentPhoto.isFavorite ? Colors.redAccent : Colors.white,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoSheet,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _showDeleteDialog,
          ),
        ],
      ),
      body: PhotoViewGallery.builder(
        pageController: _pageController,
        itemCount: _photos.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        builder: (context, index) {
          final photo = _photos[index];
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(
              ApiService.imageUrl(photo.originalUrl),
            ),
            heroAttributes: PhotoViewHeroAttributes(tag: 'photo_${photo.id}'),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
          );
        },
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}
