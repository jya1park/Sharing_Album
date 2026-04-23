import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/photo.dart';
import '../services/api_service.dart';

class PhotoGrid extends StatefulWidget {
  final List<Photo> photos;
  final void Function(int index) onTap;
  final Future<void> Function() onRefresh;
  final bool showFavoriteIcon;
  final void Function(List<Photo> selected)? onBatchAction;

  const PhotoGrid({
    super.key,
    required this.photos,
    required this.onTap,
    required this.onRefresh,
    this.showFavoriteIcon = false,
    this.onBatchAction,
  });

  @override
  State<PhotoGrid> createState() => PhotoGridState();
}

class PhotoGridState extends State<PhotoGrid> {
  final Set<String> _selectedIds = {};
  bool _isSelecting = false;

  bool get isSelecting => _isSelecting;

  void clearSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelecting = false;
    });
  }

  void _toggleSelection(Photo photo) {
    setState(() {
      if (_selectedIds.contains(photo.id)) {
        _selectedIds.remove(photo.id);
        if (_selectedIds.isEmpty) _isSelecting = false;
      } else {
        _selectedIds.add(photo.id);
      }
    });
  }

  List<Photo> get selectedPhotos =>
      widget.photos.where((p) => _selectedIds.contains(p.id)).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isSelecting)
          Container(
            color: const Color(0xFF7C4DFF),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: clearSelection,
                ),
                Text(
                  '${_selectedIds.length}개 선택됨',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    // Select all
                    setState(() {
                      for (final p in widget.photos) {
                        _selectedIds.add(p.id);
                      }
                    });
                  },
                  icon: const Icon(Icons.select_all, color: Colors.white, size: 18),
                  label: const Text('전체', style: TextStyle(color: Colors.white)),
                ),
                TextButton.icon(
                  onPressed: _selectedIds.isNotEmpty
                      ? () => widget.onBatchAction?.call(selectedPhotos)
                      : null,
                  icon: Icon(Icons.lock, color: _selectedIds.isNotEmpty ? Colors.white : Colors.white54, size: 18),
                  label: Text('공개 설정', style: TextStyle(color: _selectedIds.isNotEmpty ? Colors.white : Colors.white54)),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: widget.photos.length,
              itemBuilder: (context, index) {
                final photo = widget.photos[index];
                final isSelected = _selectedIds.contains(photo.id);

                return GestureDetector(
                  onTap: () {
                    if (_isSelecting) {
                      _toggleSelection(photo);
                    } else {
                      widget.onTap(index);
                    }
                  },
                  onLongPress: () {
                    if (!_isSelecting && widget.onBatchAction != null) {
                      setState(() => _isSelecting = true);
                      _toggleSelection(photo);
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: ApiService.imageUrl(photo.thumbnailUrl),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[200]),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, color: Colors.grey, size: 24),
                        ),
                      ),
                      if (photo.isVideo)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(100),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                          ),
                        ),
                      if (photo.isPrivate)
                        Positioned(
                          left: 4,
                          top: 4,
                          child: Icon(Icons.lock, color: Colors.white.withAlpha(200), size: 14),
                        ),
                      if (widget.showFavoriteIcon || photo.isFavorite)
                        const Positioned(
                          right: 4,
                          bottom: 4,
                          child: Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                        ),
                      // Selection overlay
                      if (_isSelecting)
                        Container(
                          color: isSelected
                              ? const Color(0xFF7C4DFF).withAlpha(80)
                              : Colors.transparent,
                        ),
                      if (_isSelecting)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? const Color(0xFF7C4DFF) : Colors.white.withAlpha(200),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 16)
                                : null,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
