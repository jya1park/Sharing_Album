import 'package:flutter/material.dart';

import '../models/photo.dart';
import '../services/api_service.dart';
import '../utils/media_helper.dart';
import '../widgets/photo_grid.dart';

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

class FavoritesTab extends StatefulWidget {
  final VoidCallback onFavoriteChanged;

  const FavoritesTab({super.key, required this.onFavoriteChanged});

  @override
  State<FavoritesTab> createState() => FavoritesTabState();
}

class FavoritesTabState extends State<FavoritesTab> {
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
      final photos = await ApiService.getFavorites();
      setState(() {
        _photos = photos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _openPhotoView(int index) {
    openMedia(
      context: context,
      photos: _photos,
      index: index,
      onDelete: (photo) async {
        await ApiService.deletePhoto(photo.id);
        widget.onFavoriteChanged();
        reload();
      },
      onFavoriteToggle: (photo) async {
        final updated = await ApiService.toggleFavorite(photo.id);
        widget.onFavoriteChanged();
        return updated;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('즐겨찾기'),
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
                          Icon(Icons.favorite_outline,
                              size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            '즐겨찾기한 사진이 없습니다',
                            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '사진을 열고 하트를 눌러보세요',
                            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    )
                  : PhotoGrid(
                      photos: _photos,
                      onTap: _openPhotoView,
                      onRefresh: _load,
                      showFavoriteIcon: true,
                    ),
        ),
      ),
    );
  }
}
