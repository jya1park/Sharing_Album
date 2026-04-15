import 'package:flutter/material.dart';

import '../models/photo.dart';
import '../screens/photo_view_screen.dart';
import '../screens/video_player_screen.dart';

void openMedia({
  required BuildContext context,
  required List<Photo> photos,
  required int index,
  required Future<void> Function(Photo photo) onDelete,
  required Future<Photo> Function(Photo photo) onFavoriteToggle,
}) {
  final photo = photos[index];

  if (photo.isVideo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          photo: photo,
          onDelete: onDelete,
          onFavoriteToggle: onFavoriteToggle,
        ),
      ),
    );
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewScreen(
          photos: photos.where((p) => !p.isVideo).toList(),
          initialIndex: photos.where((p) => !p.isVideo).toList().indexWhere((p) => p.id == photo.id).clamp(0, photos.length),
          onDelete: onDelete,
          onFavoriteToggle: onFavoriteToggle,
        ),
      ),
    );
  }
}
