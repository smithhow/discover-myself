import 'package:flutter/material.dart';
import '../../encryption/key_derivation.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key, required this.onUnlocked});
  final Future<void> Function(List<int> key) onUnlocked;
  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _c = TextEditingController();
  static final _salt = List<int>.filled(16, 1);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('发现自我', style: TextStyle(fontSize: 28)),
            TextField(key: const Key('pin_field'), controller: _c, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '输入 PIN (4-6位)')),
            const SizedBox(height: 16),
            ElevatedButton(key: const Key('pin_submit'), onPressed: () async {
              if (_c.text.length < 4) return;
              await widget.onUnlocked(deriveKey(_c.text, _salt));
            }, child: const Text('解锁')),
          ]),
        ),
      );
}
