import 'package:flutter/material.dart';

/// Lets the user pick a profile, and create one when none exist.
class ProfileSelectScreen extends StatelessWidget {
  const ProfileSelectScreen({
    super.key,
    required this.names,
    required this.onSelect,
    this.onCreate,
  });

  final List<String> names;
  final void Function(int index) onSelect;

  /// When provided, enables the "新建档案" action.
  final Future<void> Function(String name)? onCreate;

  Future<void> _showCreateDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建档案'),
        content: TextField(
          key: const Key('profile_name_field'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '档案名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            key: const Key('profile_create_confirm'),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await onCreate!(name);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('选择档案')),
        body: ListView.builder(
          itemCount: names.length,
          itemBuilder: (c, i) =>
              ListTile(title: Text(names[i]), onTap: () => onSelect(i)),
        ),
        floatingActionButton: onCreate == null
            ? null
            : FloatingActionButton.extended(
                key: const Key('profile_create'),
                onPressed: () => _showCreateDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('新建档案'),
              ),
      );
}
