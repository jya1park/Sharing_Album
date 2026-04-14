import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/photo.dart';
import '../services/api_service.dart';
import 'photo_view_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> _months = [];
  String? _selectedMonth;
  List<Photo> _photos = [];
  bool _isLoading = true;
  bool _isUploading = false;
  int _uploadTotal = 0;
  int _uploadDone = 0;
  int _uploadSkipped = 0;

  @override
  void initState() {
    super.initState();
    _loadMonths();
  }

  Future<void> _loadMonths() async {
    setState(() => _isLoading = true);
    try {
      final months = await ApiService.getMonths();
      setState(() {
        _months = months;
        if (months.isNotEmpty) {
          _selectedMonth = months.first;
        }
      });
      if (_selectedMonth != null) {
        await _loadPhotos(_selectedMonth!);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) _showError('서버 연결 실패: $e');
    }
  }

  Future<void> _loadPhotos(String month) async {
    setState(() => _isLoading = true);
    try {
      final photos = await ApiService.getPhotos(month);
      setState(() {
        _photos = photos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) _showError('사진 로딩 실패');
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
    );
    if (picked == null) return;
    await _uploadFiles([picked]);
  }

  Future<void> _pickMultiplePhotos() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 100);
    if (picked.isEmpty) return;
    await _uploadFiles(picked);
  }

  Future<void> _uploadFiles(List<XFile> files) async {
    setState(() {
      _isUploading = true;
      _uploadTotal = files.length;
      _uploadDone = 0;
      _uploadSkipped = 0;
    });

    int failed = 0;

    for (final file in files) {
      try {
        await ApiService.uploadPhoto(File(file.path));
      } on DuplicatePhotoException {
        _uploadSkipped++;
      } catch (e) {
        failed++;
      }
      setState(() => _uploadDone++);
    }

    setState(() => _isUploading = false);

    if (mounted) {
      final uploaded = _uploadTotal - _uploadSkipped - failed;
      final parts = <String>[];
      if (uploaded > 0) parts.add('$uploaded장 업로드 완료');
      if (_uploadSkipped > 0) parts.add('$_uploadSkipped장 중복');
      if (failed > 0) parts.add('$failed장 실패');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(parts.join(', ')),
          backgroundColor: failed > 0 ? Colors.orange : Colors.green,
        ),
      );
    }

    await _loadMonths();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatMonth(String month) {
    try {
      final date = DateFormat('yyyy-MM').parse(month);
      return DateFormat('yyyy년 M월').format(date);
    } catch (_) {
      return month;
    }
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택 (여러 장)'),
              onTap: () {
                Navigator.pop(context);
                _pickMultiplePhotos();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('보드미'),
        centerTitle: true,
        actions: [
          if (_months.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.calendar_month),
              onSelected: (month) {
                setState(() => _selectedMonth = month);
                _loadPhotos(month);
              },
              itemBuilder: (context) => _months
                  .map((m) => PopupMenuItem(
                        value: m,
                        child: Text(
                          _formatMonth(m),
                          style: TextStyle(
                            fontWeight:
                                m == _selectedMonth ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Upload progress
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadTotal > 0 ? _uploadDone / _uploadTotal : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_uploadDone / $_uploadTotal 업로드 중...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

          // Month header
          if (_selectedMonth != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    _formatMonth(_selectedMonth!),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${_photos.length}장',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
            ),

          // Photo grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _photos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_album_outlined,
                                size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              '아직 사진이 없습니다',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '아래 + 버튼으로 사진을 추가하세요',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadPhotos(_selectedMonth!),
                        child: GridView.builder(
                          padding: const EdgeInsets.all(2),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                          itemCount: _photos.length,
                          itemBuilder: (context, index) {
                            final photo = _photos[index];
                            return _PhotoGridItem(
                              photo: photo,
                              onTap: () => _openPhotoView(index),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : _showUploadOptions,
        child: _isUploading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.add_a_photo),
      ),
    );
  }

  void _openPhotoView(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewScreen(
          photos: _photos,
          initialIndex: initialIndex,
          onDelete: (photo) async {
            await ApiService.deletePhoto(photo.id);
            await _loadMonths();
          },
        ),
      ),
    );
  }
}

class _PhotoGridItem extends StatelessWidget {
  final Photo photo;
  final VoidCallback onTap;

  const _PhotoGridItem({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: 'photo_${photo.id}',
        child: CachedNetworkImage(
          imageUrl: ApiService.imageUrl(photo.thumbnailUrl),
          fit: BoxFit.cover,
          memCacheWidth: 75,
          placeholder: (context, url) => Container(
            color: Colors.grey[200],
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[200],
            child: const Icon(Icons.broken_image, color: Colors.grey, size: 16),
          ),
        ),
      ),
    );
  }
}
