import 'package:flutter/material.dart';

import '../models/photo.dart';
import '../screens/photo_view_screen.dart';
import '../screens/video_player_screen.dart';

Future<void> openMedia({
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
          photo: photo,
          onDelete: onDelete,
          onFavoriteToggle: onFavoriteToggle,
        ),
      ),
    );
  } else {
    final photoOnly = photos.where((p) => !p.isVideo).toList();
    int photoIndex = photoOnly.indexWhere((p) => p.id == photo.id);
    if (photoIndex < 0) photoIndex = 0;
    if (photoOnly.isEmpty) return Future.value();

    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewScreen(
          photos: photoOnly,
          initialIndex: photoIndex,
          onDelete: onDelete,
          onFavoriteToggle: onFavoriteToggle,
        ),
      ),
    );
  }
}
