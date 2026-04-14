import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/photo.dart';
import '../services/api_service.dart';

class PhotoGrid extends StatelessWidget {
  final List<Photo> photos;
  final void Function(int index) onTap;
  final Future<void> Function() onRefresh;
  final bool showFavoriteIcon;

  const PhotoGrid({
    super.key,
    required this.photos,
    required this.onTap,
    required this.onRefresh,
    this.showFavoriteIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final photo = photos[index];
          return GestureDetector(
            onTap: () => onTap(index),
            child: Hero(
              tag: 'photo_${photo.id}',
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: ApiService.imageUrl(photo.thumbnailUrl),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image,
                          color: Colors.grey, size: 24),
                    ),
                  ),
                  if (showFavoriteIcon || photo.isFavorite)
                    const Positioned(
                      right: 4,
                      bottom: 4,
                      child: Icon(
                        Icons.favorite,
                        color: Colors.redAccent,
                        size: 16,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
