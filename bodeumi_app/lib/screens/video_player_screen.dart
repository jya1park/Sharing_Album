import 'dart:io';

import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:dio/dio.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import '../models/photo.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final List<Photo> allMedia;
  final int initialIndex;
  final Future<void> Function(Photo photo) onDelete;
  final Future<Photo> Function(Photo photo) onFavoriteToggle;
  final void Function(int index)? onSwitchToPhoto;

  const VideoPlayerScreen({
    super.key,
    required this.allMedia,
    required this.initialIndex,
    required this.onDelete,
    required this.onFavoriteToggle,
    this.onSwitchToPhoto,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  late int _currentIndex;
  late Photo _photo;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _photo = widget.allMedia[_currentIndex];
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = ApiService.imageUrl(_photo.originalUrl);
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));

    await _videoController.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoController,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoController.value.aspectRatio,
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            '재생 실패: $errorMessage',
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );

    if (mounted) setState(() {});
  }

  Future<void> _switchTo(int newIndex) async {
    final newPhoto = widget.allMedia[newIndex];

    if (!newPhoto.isVideo) {
      // Switch back to photo viewer at this index
      _chewieController?.dispose();
      _videoController.dispose();
      if (mounted) {
        Navigator.of(context).pop(newPhoto.id);
        widget.onSwitchToPhoto?.call(newIndex);
      }
      return;
    }

    // Switch to another video
    _chewieController?.dispose();
    _videoController.dispose();
    _chewieController = null;

    setState(() {
      _currentIndex = newIndex;
      _photo = newPhoto;
    });

    await _initVideo();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  bool get _hasPrev => _currentIndex > 0;
  bool get _hasNext => _currentIndex < widget.allMedia.length - 1;

  Future<void> _toggleFavorite() async {
    try {
      final updated = await widget.onFavoriteToggle(_photo);
      setState(() => _photo = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('즐겨찾기 변경 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _downloadVideo() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
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

      final url = ApiService.imageUrl(_photo.originalUrl);
      final tempDir = await getTemporaryDirectory();
      final ext = _photo.originalFilename.split('.').last;
      final tempPath = '${tempDir.path}/download_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await Dio().download(url, tempPath);

      final result = await ImageGallerySaverPlus.saveFile(tempPath);
      File(tempPath).deleteSync();

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
        title: const Text('동영상 삭제'),
        content: const Text('이 동영상을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              navigator.pop();
              try {
                await widget.onDelete(_photo);
                if (mounted) {
                  navigator.pop(_photo.id);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('삭제 완료'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('삭제 실패: $e'), backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.of(context).pop(_photo.id);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_photo.id),
          ),
          title: Text(
            '${_currentIndex + 1} / ${widget.allMedia.length}',
            style: const TextStyle(fontSize: 14),
          ),
          centerTitle: true,
          actions: [
            if (AuthService.canDelete || AuthService.isAdmin)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _showDeleteDialog,
              ),
            IconButton(
              icon: Icon(
                _photo.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _photo.isFavorite ? Colors.redAccent : Colors.white,
              ),
              onPressed: _toggleFavorite,
            ),
            if (AuthService.canDownload)
              IconButton(
                icon: _isDownloading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                onPressed: _isDownloading ? null : _downloadVideo,
              ),
          ],
        ),
        body: Stack(
          children: [
            Center(
              child: _chewieController != null
                  ? Chewie(controller: _chewieController!)
                  : const CircularProgressIndicator(color: Colors.white),
            ),
            // Previous button
            if (_hasPrev)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                    ),
                    onPressed: () => _switchTo(_currentIndex - 1),
                  ),
                ),
              ),
            // Next button
            if (_hasNext)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                    ),
                    onPressed: () => _switchTo(_currentIndex + 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
