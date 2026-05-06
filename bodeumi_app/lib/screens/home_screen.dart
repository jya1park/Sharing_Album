import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'gallery_tab.dart';
import 'recent_tab.dart';
import 'favorites_tab.dart';
import 'members_screen.dart';
import 'login_screen.dart';

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
  double _currentFileProgress = 0.0;
  String _currentFileName = '';

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

  Future<void> _takeVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.camera);
    if (picked == null) return;
    await _uploadFiles([picked]);
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultipleMedia();
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
      setState(() {
        _currentFileProgress = 0.0;
        _currentFileName = file.name;
      });
      try {
        await ApiService.uploadPhoto(
          File(file.path),
          onProgress: (progress) {
            setState(() => _currentFileProgress = progress);
          },
        );
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C4DFF).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_camera_rounded, color: Color(0xFF7C4DFF)),
                ),
                title: const Text('사진 촬영', style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE91E63).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.videocam_rounded, color: Color(0xFFE91E63)),
                ),
                title: const Text('동영상 촬영', style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _takeVideo();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF4CAF50)),
                ),
                title: const Text('갤러리에서 선택 (사진+동영상)', style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia();
              },
            ),
          ],
          ),
        ),
      ),
    );
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF7C4DFF),
                      child: Text(
                        (AuthService.nickname ?? '?').characters.first,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AuthService.nickname ?? '',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${AuthService.userName ?? ''}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey[200]),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C4DFF).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.group_rounded, color: Color(0xFF7C4DFF), size: 20),
                ),
                title: const Text('멤버 목록', style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MembersScreen()),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
              ),
              title: const Text('로그아웃', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
              onTap: () async {
                final nav = Navigator.of(context);
                nav.pop();
                await AuthService.logout();
                if (mounted) {
                  nav.pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
            ),
          ],
        ),
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
                    value: _currentFileProgress,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_currentFileName  (${_uploadDone + 1}/$_uploadTotal)  ${(_currentFileProgress * 100).toInt()}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                RecentTab(
                  key: _recentKey,
                  onFavoriteChanged: _onFavoriteChanged,
                ),
                GalleryTab(
                  key: _galleryKey,
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
        onDestinationSelected: (index) {
          setState(() => _currentTab = index);
          // Reload the selected tab
          switch (index) {
            case 0:
              _recentKey.currentState?.reload();
            case 1:
              _galleryKey.currentState?.reload();
            case 2:
              _favoritesKey.currentState?.reload();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: '최신',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: '갤러리',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: '즐겨찾기',
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Menu button (small)
          FloatingActionButton.small(
            heroTag: 'menu',
            onPressed: _showMenu,
            backgroundColor: Colors.white,
            child: Text(
              (AuthService.nickname ?? '?').characters.first,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF7C4DFF),
                fontSize: 16,
              ),
            ),
          ),
          if (AuthService.canUpload) ...[
            const SizedBox(height: 8),
            // Upload button
            FloatingActionButton(
              heroTag: 'upload',
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
          ],
        ],
      ),
    );
  }
}
