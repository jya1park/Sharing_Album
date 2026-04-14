import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import 'gallery_tab.dart';
import 'recent_tab.dart';
import 'favorites_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  bool _isUploading = false;
  int _uploadTotal = 0;
  int _uploadDone = 0;

  // Keys to trigger reload on child tabs
  final _galleryKey = GlobalKey<GalleryTabState>();
  final _recentKey = GlobalKey<RecentTabState>();
  final _favoritesKey = GlobalKey<FavoritesTabState>();

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
    });

    int skipped = 0;
    int failed = 0;

    for (final file in files) {
      try {
        await ApiService.uploadPhoto(File(file.path));
      } on DuplicatePhotoException {
        skipped++;
      } catch (e) {
        failed++;
      }
      setState(() => _uploadDone++);
    }

    setState(() => _isUploading = false);

    if (mounted) {
      final uploaded = _uploadTotal - skipped - failed;
      final parts = <String>[];
      if (uploaded > 0) parts.add('$uploaded장 업로드 완료');
      if (skipped > 0) parts.add('$skipped장 중복');
      if (failed > 0) parts.add('$failed장 실패');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(parts.join(', ')),
          backgroundColor: failed > 0 ? Colors.orange : Colors.green,
        ),
      );
    }

    _galleryKey.currentState?.reload();
    _recentKey.currentState?.reload();
    _favoritesKey.currentState?.reload();
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

  void _onFavoriteChanged() {
    _favoritesKey.currentState?.reload();
    _galleryKey.currentState?.reload();
    _recentKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
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
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                GalleryTab(
                  key: _galleryKey,
                  onFavoriteChanged: _onFavoriteChanged,
                ),
                RecentTab(
                  key: _recentKey,
                  onFavoriteChanged: _onFavoriteChanged,
                ),
                FavoritesTab(
                  key: _favoritesKey,
                  onFavoriteChanged: _onFavoriteChanged,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) => setState(() => _currentTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: '갤러리',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: '최신',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: '즐겨찾기',
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
}
