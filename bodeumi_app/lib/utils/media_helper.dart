import 'package:flutter/material.dart';

import '../models/photo.dart';
import '../screens/photo_view_screen.dart';
import '../screens/video_player_screen.dart';

Future<dynamic> openMedia({
  required BuildContext context,
  required List<Photo> photos,
  required int index,
  required Future<void> Function(Photo photo) onDelete,
  required Future<Photo> Function(Photo photo) onFavoriteToggle,
}) {
  final photo = photos[index];

  if (photo.isVideo) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          allMedia: photos,
          initialIndex: index,
          onDelete: onDelete,
          onFavoriteToggle: onFavoriteToggle,
          onSwitchToPhoto: (newIndex) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PhotoViewScreen(
                  photos: photos,
                  initialIndex: newIndex,
                  onDelete: onDelete,
                  onFavoriteToggle: onFavoriteToggle,
                  onOpenVideo: (videoPhoto) {
                    final vidIdx = photos.indexWhere((p) => p.id == videoPhoto.id);
                    if (vidIdx >= 0) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoPlayerScreen(
                            allMedia: photos,
                            initialIndex: vidIdx,
                            onDelete: onDelete,
                            onFavoriteToggle: onFavoriteToggle,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  } else {
    if (photos.isEmpty) return Future.value();

    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewScreen(
          photos: photos,
          initialIndex: index,
          onDelete: onDelete,
          onFavoriteToggle: onFavoriteToggle,
          onOpenVideo: (videoPhoto) {
            final vidIdx = photos.indexWhere((p) => p.id == videoPhoto.id);
            if (vidIdx >= 0) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerScreen(
                    allMedia: photos,
                    initialIndex: vidIdx,
                    onDelete: onDelete,
                    onFavoriteToggle: onFavoriteToggle,
                    onSwitchToPhoto: (newIndex) {
                      Navigator.of(context).pop(photos[newIndex].id);
                    },
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
