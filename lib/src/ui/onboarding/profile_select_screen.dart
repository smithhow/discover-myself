import 'package:flutter/material.dart';

class ProfileSelectScreen extends StatelessWidget {
  const ProfileSelectScreen({super.key, required this.names, required this.onSelect});
  final List<String> names;
  final void Function(int index) onSelect;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('选择档案')),
        body: ListView.builder(
          itemCount: names.length,
          itemBuilder: (c, i) => ListTile(title: Text(names[i]), onTap: () => onSelect(i)),
        ),
      );
}
