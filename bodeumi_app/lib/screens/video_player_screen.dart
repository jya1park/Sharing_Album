import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

import '../models/photo.dart';
import '../services/api_service.dart';

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
          IconButton(
            icon: Icon(
              _photo.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _photo.isFavorite ? Colors.redAccent : Colors.white,
            ),
            onPressed: _toggleFavorite,
          ),
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
