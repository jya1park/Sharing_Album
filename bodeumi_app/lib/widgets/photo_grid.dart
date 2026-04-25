import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  /// Build rows: photos fill 4 columns, videos take 2x2 at random column position
  List<Widget> _buildRows() {
    final rows = <Widget>[];
    int i = 0;
    int videoIndex = 0;

    while (i < widget.photos.length) {
      final photo = widget.photos[i];

      if (photo.isVideo) {
        // Video: 2x2 block. Pick random start column (0, 1, or 2)
        final positions = [0, 1, 2];
        final startCol = positions[videoIndex % positions.length];
        videoIndex++;

        // Fill remaining 2 cells in each row with photos from the list
        final topPhotos = <Photo>[];
        final bottomPhotos = <Photo>[];
        int j = i + 1;

        // Collect photos for the 2 cells beside the video (top row)
        if (startCol == 0) {
          // Video at col 0-1, photos at col 2-3
          while (topPhotos.length < 2 && j < widget.photos.length) {
            if (!widget.photos[j].isVideo) topPhotos.add(widget.photos[j]);
            j++;
          }
        } else if (startCol == 2) {
          // Photos at col 0-1, video at col 2-3
          while (topPhotos.length < 2 && j < widget.photos.length) {
            if (!widget.photos[j].isVideo) topPhotos.add(widget.photos[j]);
            j++;
          }
        } else {
          // startCol == 1: photo at col 0, video at col 1-2, photo at col 3
          while (topPhotos.isEmpty && j < widget.photos.length) {
            if (!widget.photos[j].isVideo) topPhotos.add(widget.photos[j]);
            j++;
          }
          while (bottomPhotos.isEmpty && j < widget.photos.length) {
            if (!widget.photos[j].isVideo) bottomPhotos.add(widget.photos[j]);
            j++;
          }
        }

        // Build 2-row block
        final videoWidget = _buildItem(photo, i);
        if (startCol == 1) {
          // [photo][video video][photo]
          // [photo][video video][photo]
          final leftTop = topPhotos.isNotEmpty ? topPhotos[0] : null;
          final rightTop = bottomPhotos.isNotEmpty ? bottomPhotos[0] : null;

          // Collect bottom-row side photos
          final leftBottom = <Photo>[];
          final rightBottom = <Photo>[];
          while (leftBottom.isEmpty && j < widget.photos.length) {
            if (!widget.photos[j].isVideo) leftBottom.add(widget.photos[j]);
            j++;
          }
          while (rightBottom.isEmpty && j < widget.photos.length) {
            if (!widget.photos[j].isVideo) rightBottom.add(widget.photos[j]);
            j++;
          }

          rows.add(_buildVideoRow2x2Center(
            videoWidget,
            leftTop != null ? _buildItem(leftTop, widget.photos.indexOf(leftTop)) : null,
            rightTop != null ? _buildItem(rightTop, widget.photos.indexOf(rightTop)) : null,
            leftBottom.isNotEmpty ? _buildItem(leftBottom[0], widget.photos.indexOf(leftBottom[0])) : null,
            rightBottom.isNotEmpty ? _buildItem(rightBottom[0], widget.photos.indexOf(rightBottom[0])) : null,
          ));
        } else {
          // Collect bottom-row photos for the 2 side cells
          while (bottomPhotos.length < 2 && j < widget.photos.length) {
            if (!widget.photos[j].isVideo) bottomPhotos.add(widget.photos[j]);
            j++;
          }

          if (startCol == 0) {
            rows.add(_buildVideoRow2x2Side(
              videoWidget, topPhotos, bottomPhotos, true,
            ));
          } else {
            rows.add(_buildVideoRow2x2Side(
              videoWidget, topPhotos, bottomPhotos, false,
            ));
          }
        }

        i = j;
      } else {
        // Regular row: up to 4 photos
        final rowPhotos = <Photo>[];
        int j = i;
        while (rowPhotos.length < 4 && j < widget.photos.length) {
          if (!widget.photos[j].isVideo) {
            rowPhotos.add(widget.photos[j]);
            j++;
          } else {
            break;
          }
        }

        if (rowPhotos.isEmpty) {
          i++;
          continue;
        }

        rows.add(Row(
          children: rowPhotos.map((p) {
            return Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: _buildItem(p, widget.photos.indexOf(p)),
                  ),
                ),
              ),
            );
          }).toList()
            ..addAll(List.generate(4 - rowPhotos.length, (_) => const Expanded(child: SizedBox()))),
        ));

        i = j;
      }
    }
    return rows;
  }

  Widget _buildVideoRow2x2Side(Widget video, List<Photo> topPhotos, List<Photo> bottomPhotos, bool videoOnLeft) {
    final sideTop = topPhotos.map((p) => Expanded(
      child: AspectRatio(aspectRatio: 1, child: Padding(padding: const EdgeInsets.all(2), child: ClipRRect(borderRadius: BorderRadius.circular(2), child: _buildItem(p, widget.photos.indexOf(p))))),
    )).toList();
    final sideBottom = bottomPhotos.map((p) => Expanded(
      child: AspectRatio(aspectRatio: 1, child: Padding(padding: const EdgeInsets.all(2), child: ClipRRect(borderRadius: BorderRadius.circular(2), child: _buildItem(p, widget.photos.indexOf(p))))),
    )).toList();

    while (sideTop.length < 2) {
      sideTop.add(const Expanded(child: SizedBox()));
    }
    while (sideBottom.length < 2) {
      sideBottom.add(const Expanded(child: SizedBox()));
    }

    final videoBlock = Expanded(
      flex: 2,
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(padding: const EdgeInsets.all(2), child: ClipRRect(borderRadius: BorderRadius.circular(2), child: video)),
      ),
    );

    final sideBlock = Expanded(
      flex: 2,
      child: Column(
        children: [
          Row(children: sideTop),
          Row(children: sideBottom),
        ],
      ),
    );

    return Row(
      children: videoOnLeft ? [videoBlock, sideBlock] : [sideBlock, videoBlock],
    );
  }

  Widget _buildVideoRow2x2Center(Widget video, Widget? leftTop, Widget? rightTop, Widget? leftBottom, Widget? rightBottom) {
    Widget cell(Widget? w) => Expanded(
      child: AspectRatio(aspectRatio: 1, child: Padding(padding: const EdgeInsets.all(2), child: w != null ? ClipRRect(borderRadius: BorderRadius.circular(2), child: w) : const SizedBox())),
    );

    final videoBlock = Expanded(
      flex: 2,
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(padding: const EdgeInsets.all(2), child: ClipRRect(borderRadius: BorderRadius.circular(2), child: video)),
      ),
    );

    return Column(
      children: [
        Row(children: [cell(leftTop), videoBlock, cell(rightTop)]),
        // Bottom row hidden - video occupies both rows via aspect ratio
      ],
    );
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
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(2),
              children: _buildRows(),
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
