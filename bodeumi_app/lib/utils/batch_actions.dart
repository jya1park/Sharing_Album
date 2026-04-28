import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/photo.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'visibility_dialog.dart';

Future<void> handleBatchAction(
  BuildContext context,
  List<Photo> selected,
  String action,
  VoidCallback onDone,
) async {
  switch (action) {
    case 'visibility':
      if (!AuthService.canSetVisibility) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공개 설정 권한이 없습니다'), backgroundColor: Colors.orange),
        );
        return;
      }
      await showBatchVisibilityDialog(context: context, photos: selected, onDone: onDone);
    case 'delete':
      await _batchDelete(context, selected, onDone);
    case 'favorite':
      await _batchFavorite(context, selected, onDone);
    case 'download':
      await _batchDownload(context, selected);
  }
}

Future<void> _batchDelete(BuildContext context, List<Photo> photos, VoidCallback onDone) async {
  if (!AuthService.canDelete && !AuthService.isAdmin) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('삭제 권한이 없습니다'), backgroundColor: Colors.orange),
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('일괄 삭제'),
      content: Text('${photos.length}개를 삭제하시겠습니까?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('삭제', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  int success = 0;
  for (final photo in photos) {
    try {
      await ApiService.deletePhoto(photo.id);
      success++;
    } catch (_) {}
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$success개 삭제 완료'), backgroundColor: Colors.green),
    );
  }
  onDone();
}

Future<void> _batchFavorite(BuildContext context, List<Photo> photos, VoidCallback onDone) async {
  int success = 0;
  for (final photo in photos) {
    try {
      await ApiService.toggleFavorite(photo.id);
      success++;
    } catch (_) {}
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$success개 즐겨찾기 변경'), backgroundColor: Colors.green),
    );
  }
  onDone();
}

Future<void> _batchDownload(BuildContext context, List<Photo> photos) async {
  if (!AuthService.canDownload) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('다운로드 권한이 없습니다'), backgroundColor: Colors.orange),
      );
    }
    return;
  }

  final status = await Permission.photos.request();
  if (!status.isGranted) {
    final storageStatus = await Permission.storage.request();
    if (!storageStatus.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장소 권한이 필요합니다'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
  }

  int success = 0;
  for (final photo in photos) {
    try {
      final url = ApiService.imageUrl(photo.originalUrl);
      if (photo.isVideo) {
        final tempDir = await getTemporaryDirectory();
        final ext = photo.originalFilename.split('.').last;
        final tempPath = '${tempDir.path}/dl_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await Dio().download(url, tempPath);
        await ImageGallerySaverPlus.saveFile(tempPath);
        File(tempPath).deleteSync();
      } else {
        final response = await Dio().get(url, options: Options(responseType: ResponseType.bytes));
        await ImageGallerySaverPlus.saveImage(
          Uint8List.fromList(response.data),
          quality: 100,
          name: photo.originalFilename.replaceAll(RegExp(r'\.[^.]+$'), ''),
        );
      }
      success++;
    } catch (_) {}
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$success개 갤러리에 저장 완료'), backgroundColor: Colors.green),
    );
  }
}
