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
  final Photo photo;
  final Future<void> Function(Photo photo) onDelete;
  final Future<Photo> Function(Photo photo) onFavoriteToggle;

  const VideoPlayerScreen({
    super.key,
    required this.photo,
    required this.onDelete,
    required this.onFavoriteToggle,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  late Photo _photo;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _photo = widget.photo;
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

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

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
                  navigator.pop();
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          _photo.originalFilename,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
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
          IconButton(
            icon: Icon(
              _photo.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _photo.isFavorite ? Colors.redAccent : Colors.white,
            ),
            onPressed: _toggleFavorite,
          ),
          if (AuthService.canDelete || AuthService.isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _showDeleteDialog,
            ),
        ],
      ),
      body: Center(
        child: _chewieController != null
            ? Chewie(controller: _chewieController!)
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
