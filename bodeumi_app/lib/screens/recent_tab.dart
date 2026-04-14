import 'package:flutter/material.dart';

import '../models/photo.dart';
import '../services/api_service.dart';
import '../widgets/photo_grid.dart';
import 'photo_view_screen.dart';

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

class RecentTab extends StatefulWidget {
  final VoidCallback onFavoriteChanged;

  const RecentTab({super.key, required this.onFavoriteChanged});

  @override
  State<RecentTab> createState() => RecentTabState();
}

class RecentTabState extends State<RecentTab> {
  List<Photo> _photos = [];
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
        _photos = photos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _openPhotoView(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewScreen(
          photos: _photos,
          initialIndex: index,
          onDelete: (photo) async {
            await ApiService.deletePhoto(photo.id);
            reload();
          },
          onFavoriteToggle: (photo) async {
            final updated = await ApiService.toggleFavorite(photo.id);
            widget.onFavoriteChanged();
            return updated;
          },
        ),
      ),
    );
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
              : _photos.isEmpty
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
                  : PhotoGrid(
                      photos: _photos,
                      onTap: _openPhotoView,
                      onRefresh: _load,
                    ),
        ),
      ),
    );
  }
}
