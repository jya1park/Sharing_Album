import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/photo.dart';
import '../services/api_service.dart';
import '../widgets/photo_grid.dart';
import 'photo_view_screen.dart';

const _gradientDecoration = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF3E8FF), // 연한 라벤더
      Color(0xFFFCE4EC), // 연한 핑크
    ],
  ),
);

class GalleryTab extends StatefulWidget {
  final VoidCallback onFavoriteChanged;

  const GalleryTab({super.key, required this.onFavoriteChanged});

  @override
  State<GalleryTab> createState() => GalleryTabState();
}

class GalleryTabState extends State<GalleryTab> {
  List<String> _months = [];
  final Map<String, List<Photo>> _photoCache = {};
  late PageController _pageController;
  int _currentPage = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadMonths();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void reload() {
    _photoCache.clear();
    _loadMonths();
  }

  Future<void> _loadMonths() async {
    setState(() => _isLoading = true);
    try {
      final months = await ApiService.getMonths();
      setState(() {
        _months = months;
        _isLoading = false;
      });
      if (months.isNotEmpty) {
        _loadPhotosForPage(0);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('서버 연결 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadPhotosForPage(int pageIndex) async {
    if (pageIndex < 0 || pageIndex >= _months.length) return;
    final month = _months[pageIndex];
    if (_photoCache.containsKey(month)) return;

    try {
      final photos = await ApiService.getPhotos(month);
      setState(() => _photoCache[month] = photos);
    } catch (_) {}
  }

  String _formatMonth(String month) {
    try {
      final date = DateFormat('yyyy-MM').parse(month);
      return DateFormat('yyyy년 M월').format(date);
    } catch (_) {
      return month;
    }
  }

  void _openPhotoView(List<Photo> photos, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewScreen(
          photos: photos,
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Container(
        decoration: _gradientDecoration,
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _months.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_album_outlined,
                              size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            '아직 사진이 없습니다',
                            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Month indicator
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: _currentPage < _months.length - 1
                                    ? () => _pageController.nextPage(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        )
                                    : null,
                              ),
                              Expanded(
                                child: Text(
                                  _formatMonth(_months[_currentPage]),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: _currentPage > 0
                                    ? () => _pageController.previousPage(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        )
                                    : null,
                              ),
                            ],
                          ),
                        ),

                        // Swipeable month pages
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            reverse: true,
                            itemCount: _months.length,
                            onPageChanged: (index) {
                              setState(() => _currentPage = index);
                              _loadPhotosForPage(index);
                              _loadPhotosForPage(index - 1);
                              _loadPhotosForPage(index + 1);
                            },
                            itemBuilder: (context, index) {
                              final month = _months[index];
                              final photos = _photoCache[month];

                              if (photos == null) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              if (photos.isEmpty) {
                                return Center(
                                  child: Text(
                                    '이 달에는 사진이 없습니다',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey[500]),
                                  ),
                                );
                              }

                              return PhotoGrid(
                                photos: photos,
                                onTap: (i) => _openPhotoView(photos, i),
                                onRefresh: () async {
                                  _photoCache.remove(month);
                                  await _loadPhotosForPage(index);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
