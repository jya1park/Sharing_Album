import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final users = await AuthService.getUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy.MM.dd').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _togglePermission(String userId, String field, bool value) async {
    try {
      await AuthService.updatePermission(userId, {field: value});
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('권한 변경 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showPermissionDialog(Map<String, dynamic> user) {
    final nickname = (user['nickname'] ?? user['name'] ?? '').toString();
    bool canUpload = user['can_upload'] ?? true;
    bool canDelete = user['can_delete'] ?? true;
    bool canDownload = user['can_download'] ?? true;
    final userId = user['id'] as String;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('$nickname 권한 관리'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('업로드'),
                subtitle: const Text('사진/동영상 업로드 허용'),
                value: canUpload,
                onChanged: (v) {
                  setDialogState(() => canUpload = v);
                  _togglePermission(userId, 'can_upload', v);
                },
              ),
              SwitchListTile(
                title: const Text('삭제'),
                subtitle: const Text('사진/동영상 삭제 허용'),
                value: canDelete,
                onChanged: (v) {
                  setDialogState(() => canDelete = v);
                  _togglePermission(userId, 'can_delete', v);
                },
              ),
              SwitchListTile(
                title: const Text('다운로드'),
                subtitle: const Text('원본 다운로드 허용'),
                value: canDownload,
                onChanged: (v) {
                  setDialogState(() => canDownload = v);
                  _togglePermission(userId, 'can_download', v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
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
        title: const Text('멤버 목록'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF3E8FF),
              Color(0xFFFCE4EC),
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? const Center(child: Text('멤버가 없습니다'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final nickname = (user['nickname'] ?? '').toString();
                          final name = (user['name'] ?? '').toString();
                          final displayName = nickname.isNotEmpty ? nickname : name;
                          final isMe = user['id'] == AuthService.userId;
                          final isAdmin = user['role'] == 'admin';
                          final initial = displayName.isNotEmpty
                              ? displayName.characters.first
                              : '?';

                          return Card(
                            elevation: 0,
                            color: Colors.white.withAlpha(180),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isAdmin
                                    ? const Color(0xFFFF9800)
                                    : isMe
                                        ? const Color(0xFF7C4DFF)
                                        : const Color(0xFFE1BEE7),
                                child: Text(
                                  initial,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: (isAdmin || isMe) ? Colors.white : const Color(0xFF6A1B9A),
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  if (isAdmin)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF9800),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        '관리자',
                                        style: TextStyle(color: Colors.white, fontSize: 11),
                                      ),
                                    ),
                                  if (isMe && !isAdmin)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7C4DFF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        '나',
                                        style: TextStyle(color: Colors.white, fontSize: 11),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                '@$name  |  가입일: ${_formatDate(user['created_at'] ?? '')}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              trailing: (AuthService.isAdmin && !isAdmin)
                                  ? IconButton(
                                      icon: const Icon(Icons.settings, size: 20),
                                      onPressed: () => _showPermissionDialog(user),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ),
    );
  }
}
