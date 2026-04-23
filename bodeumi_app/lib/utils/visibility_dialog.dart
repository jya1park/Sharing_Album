import 'package:flutter/material.dart';

import '../models/photo.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

Future<void> showBatchVisibilityDialog({
  required BuildContext context,
  required List<Photo> photos,
  required VoidCallback onDone,
}) async {
  List<Map<String, dynamic>> users;
  try {
    users = await AuthService.getUsers();
  } catch (_) {
    return;
  }

  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (context) {
      bool allPublic = true;
      final selected = <String>{};

      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${photos.length}개 공개 범위 설정'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('전체 공개'),
                  value: allPublic,
                  onChanged: (v) => setDialogState(() {
                    allPublic = v;
                    if (v) selected.clear();
                  }),
                ),
                if (!allPublic) ...[
                  const Divider(),
                  const Text('볼 수 있는 사람 선택:', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  ...users.map((u) {
                    final uid = u['id'] as String;
                    final nickname = (u['nickname'] ?? u['name'] ?? '').toString();
                    return CheckboxListTile(
                      title: Text(nickname),
                      value: selected.contains(uid),
                      onChanged: (v) => setDialogState(() {
                        if (v == true) {
                          selected.add(uid);
                        } else {
                          selected.remove(uid);
                        }
                      }),
                      dense: true,
                    );
                  }),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                nav.pop();

                final newVisible = allPublic ? <String>[] : selected.toList();
                int success = 0;
                for (final photo in photos) {
                  try {
                    await ApiService.updateVisibility(photo.id, newVisible);
                    success++;
                  } catch (_) {}
                }

                messenger.showSnackBar(
                  SnackBar(
                    content: Text(allPublic
                        ? '$success개 전체 공개로 변경됨'
                        : '$success개를 ${selected.length}명에게만 공개'),
                    backgroundColor: Colors.green,
                  ),
                );
                onDone();
              },
              child: const Text('저장'),
            ),
          ],
        ),
      );
    },
  );
}
