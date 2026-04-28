import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/photo.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

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
  bool _isDownloading = false;

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

  Future<void> _downloadPhoto() async {
    if (_isDownloading) return;

    setState(() => _isDownloading = true);

    try {
      // Request storage permission
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        final storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('저장소 권한이 필요합니다'), backgroundColor: Colors.orange),
            );
          }
          setState(() => _isDownloading = false);
          return;
        }
      }

      // Download the original image
      final url = ApiService.imageUrl(_currentPhoto.originalUrl);
      final response = await Dio().get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      // Save to gallery
      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(response.data),
        quality: 100,
        name: _currentPhoto.originalFilename.replaceAll(RegExp(r'\.[^.]+$'), ''),
      );

      if (mounted) {
        final success = result['isSuccess'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '갤러리에 저장 완료' : '저장 실패'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('다운로드 실패: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isDownloading = false);
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

  Future<void> _showVisibilityDialog() async {
    List<Map<String, dynamic>> users;
    try {
      users = await AuthService.getUsers();
    } catch (_) {
      return;
    }

    final currentVisible = Set<String>.from(_currentPhoto.visibleTo ?? []);
    final isPublic = currentVisible.isEmpty;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        bool allPublic = isPublic;
        final selected = Set<String>.from(currentVisible);

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('공개 범위'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('전체 공개'),
                    value: allPublic,
                    onChanged: (v) => setDialogState(() {
                      allPublic = v;
                      if (v) selected.clear();
                    }),
                  ),
                  if (!allPublic) ...[
                    const Divider(),
                    const Text('볼 수 있는 사람 선택:', style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
                    ...users.map((u) {
                      final uid = u['id'] as String;
                      final nickname = (u['nickname'] ?? u['name'] ?? '').toString();
                      return CheckboxListTile(
                        title: Text(nickname),
                        value: selected.contains(uid),
                        onChanged: (v) => setDialogState(() {
                          if (v == true) {
                            selected.add(uid);
                          } else {
                            selected.remove(uid);
                          }
                        }),
                        dense: true,
                      );
                    }),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  nav.pop();
                  try {
                    final newVisible = allPublic ? <String>[] : selected.toList();
                    await ApiService.updateVisibility(_currentPhoto.id, newVisible);
                    setState(() {
                      _photos[_currentIndex] = _currentPhoto.copyWith(
                        visibleTo: newVisible.isEmpty ? null : newVisible,
                      );
                    });
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(allPublic ? '전체 공개로 변경됨' : '${selected.length}명에게만 공개'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('변경 실패: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                child: const Text('저장'),
              ),
            ],
          ),
        );
      },
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
          if (AuthService.canSetVisibility)
            IconButton(
              icon: Icon(
                _currentPhoto.isPrivate ? Icons.lock : Icons.lock_open,
                size: 20,
              ),
              onPressed: _showVisibilityDialog,
          ),
          if (AuthService.canDelete || AuthService.isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _showDeleteDialog,
            ),
          IconButton(
            icon: Icon(
              _currentPhoto.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _currentPhoto.isFavorite ? Colors.redAccent : Colors.white,
            ),
            onPressed: _toggleFavorite,
          ),
          if (AuthService.canDownload)
            IconButton(
              icon: _isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download),
              onPressed: _isDownloading ? null : _downloadPhoto,
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoSheet,
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
