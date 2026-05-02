import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/photo.dart';
import '../services/api_service.dart';
import '../utils/batch_actions.dart';
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
    _loadMonths(preservePage: true);
  }

  Future<void> _loadMonths({bool preservePage = false}) async {
    final previousMonth = (_months.isNotEmpty && _currentPage < _months.length)
        ? _months[_currentPage]
        : null;

    setState(() => _isLoading = true);
    try {
      final months = await ApiService.getMonths();
      int newPage = 0;
      if (preservePage && previousMonth != null) {
        final idx = months.indexOf(previousMonth);
        newPage = idx >= 0 ? idx : 0;
      }

      setState(() {
        _months = months;
        _currentPage = newPage;
        _isLoading = false;
      });

      if (months.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(newPage);
          }
        });
        _loadPhotosForPage(newPage);
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

  String _formatYear(String month) {
    try {
      final date = DateFormat('yyyy-MM').parse(month);
      return DateFormat('yyyy년').format(date);
    } catch (_) {
      return month;
    }
  }

  String _formatShortMonth(String month) {
    try {
      final date = DateFormat('yyyy-MM').parse(month);
      return DateFormat('M월').format(date);
    } catch (_) {
      return month;
    }
  }

  /// Get visible month indices: up to 5, centered on current page
  List<int> _getVisibleMonthIndices() {
    if (_months.isEmpty) return [];
    final total = _months.length;
    const windowSize = 5;

    int start = _currentPage - 2;
    int end = _currentPage + 2;

    // Adjust window to stay within bounds
    if (start < 0) {
      end = (end - start).clamp(0, total - 1);
      start = 0;
    }
    if (end >= total) {
      start = (start - (end - total + 1)).clamp(0, total - 1);
      end = total - 1;
    }

    // Limit to windowSize
    if (end - start + 1 > windowSize) {
      end = start + windowSize - 1;
    }

    return List.generate(end - start + 1, (i) => start + i);
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _handleBatchAction(List<Photo> selected, String action) {
    handleBatchAction(context, selected, action, reload);
  }

  void _openPhotoView(List<Photo> photos, int index) {
    openMedia(
      context: context,
      photos: photos,
      index: index,
      onDelete: (photo) async {
        await ApiService.deletePhoto(photo.id);
      },
      onFavoriteToggle: (photo) async {
        final updated = await ApiService.toggleFavorite(photo.id);
        widget.onFavoriteChanged();
        return updated;
      },
    ).then((_) => reload());
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
                        // Year label
                        if (_currentPage < _months.length)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _formatYear(_months[_currentPage]),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                        // 5-month tab navigation
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Row(
                            children: [
                              // Left arrow (go to newer / lower index)
                              IconButton(
                                icon: const Icon(Icons.chevron_left, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: _currentPage > 0
                                    ? () => _goToPage(_currentPage - 1)
                                    : null,
                              ),

                              // Month tabs
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: _getVisibleMonthIndices().map((index) {
                                    final isSelected = index == _currentPage;
                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () => _goToPage(index),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          margin: const EdgeInsets.symmetric(horizontal: 2),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFF7C4DFF).withAlpha(30)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(20),
                                            border: isSelected
                                                ? Border.all(color: const Color(0xFF7C4DFF), width: 1.5)
                                                : null,
                                          ),
                                          child: Text(
                                            _formatShortMonth(_months[index]),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              color: isSelected
                                                  ? const Color(0xFF7C4DFF)
                                                  : Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),

                              // Right arrow (go to older / higher index)
                              IconButton(
                                icon: const Icon(Icons.chevron_right, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: _currentPage < _months.length - 1
                                    ? () => _goToPage(_currentPage + 1)
                                    : null,
                              ),
                            ],
                          ),
                        ),

                        // Swipeable month pages (no reverse: left=newest, right=oldest)
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _months.length,
                            onPageChanged: (index) {
                              if (index >= _months.length) return;
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
                                onBatchAction: (selected, action) => _handleBatchAction(selected, action),
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
