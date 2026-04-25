import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../models/photo.dart';
import '../services/api_service.dart';

class PhotoGrid extends StatefulWidget {
  final List<Photo> photos;
  final void Function(int index) onTap;
  final Future<void> Function() onRefresh;
  final bool showFavoriteIcon;
  final void Function(List<Photo> selected, String action)? onBatchAction;

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

  bool get _hasSelection => _selectedIds.isNotEmpty;
  Color get _activeColor => Colors.white;
  Color get _inactiveColor => Colors.white54;

  /// Build tile layout: videos get 2x2, photos get 1x1, packed into 4 columns
  List<StaggeredGridTile> _buildTiles() {
    final tiles = <StaggeredGridTile>[];
    for (int i = 0; i < widget.photos.length; i++) {
      final photo = widget.photos[i];
      if (photo.isVideo) {
        tiles.add(StaggeredGridTile.count(
          crossAxisCellCount: 2,
          mainAxisCellCount: 2,
          child: _buildItem(photo, i),
        ));
      } else {
        tiles.add(StaggeredGridTile.count(
          crossAxisCellCount: 1,
          mainAxisCellCount: 1,
          child: _buildItem(photo, i),
        ));
      }
    }
    return tiles;
  }

  Widget _buildItem(Photo photo, int index) {
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(100),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isSelecting)
          Container(
            color: const Color(0xFF7C4DFF),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: clearSelection,
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      '${_selectedIds.length}개 선택',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.select_all, color: Colors.white, size: 20),
                      tooltip: '전체 선택',
                      onPressed: () {
                        setState(() {
                          for (final p in widget.photos) {
                            _selectedIds.add(p.id);
                          }
                        });
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _actionButton(Icons.lock, '공개설정', 'visibility'),
                    _actionButton(Icons.delete_outline, '삭제', 'delete'),
                    _actionButton(Icons.favorite, '즐겨찾기', 'favorite'),
                    _actionButton(Icons.download, '다운로드', 'download'),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(4),
              child: StaggeredGrid.count(
                crossAxisCount: 4,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                children: _buildTiles(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, String action) {
    return InkWell(
      onTap: _hasSelection
          ? () => widget.onBatchAction?.call(selectedPhotos, action)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _hasSelection ? _activeColor : _inactiveColor, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: _hasSelection ? _activeColor : _inactiveColor, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
