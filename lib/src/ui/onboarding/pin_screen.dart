import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/pin_service.dart';

class PinScreen extends StatefulWidget {
  PinScreen({
    super.key,
    required this.onUnlocked,
    PinService? pinService,
    this.maxAttempts = 5,
    this.cooldown = const Duration(seconds: 30),
  }) : pinService = pinService ?? PinService();

  final Future<void> Function(List<int> key) onUnlocked;
  final PinService pinService;

  /// Consecutive failed unlocks before submission is disabled.
  final int maxAttempts;

  /// How long submission stays disabled after too many failures.
  final Duration cooldown;

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  static final RegExp _pinPattern = RegExp(r'^\d{4,6}$');

  final TextEditingController _c = TextEditingController();
  String? _error;
  int _failures = 0;
  bool _coolingDown = false;
  bool _busy = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _coolingDown) return;
    final pin = _c.text;
    if (!_pinPattern.hasMatch(pin)) {
      setState(() => _error = '请输入 4-6 位数字 PIN');
      return;
    }
    setState(() => _busy = true);
    try {
      final key = await widget.pinService.deriveKeyFor(pin);
      await widget.onUnlocked(key);
      if (!mounted) return;
      setState(() {
        _error = null;
        _failures = 0;
        _busy = false;
      });
    } on SaltPersistenceException catch (e) {
      // A storage failure is not a wrong PIN: surface it without counting it
      // toward the lockout, otherwise a device issue locks the user out.
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      _failures++;
      if (_failures >= widget.maxAttempts) {
        _startCooldown();
      } else {
        setState(() {
          _error = 'PIN 错误，请重试';
          _busy = false;
        });
      }
    }
  }

  void _startCooldown() {
    setState(() {
      _busy = false;
      _coolingDown = true;
      _error = '尝试次数过多，请等待 ${widget.cooldown.inSeconds} 秒';
    });
    _timer?.cancel();
    _timer = Timer(widget.cooldown, () {
      if (!mounted) return;
      setState(() {
        _coolingDown = false;
        _failures = 0;
        _error = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('发现自我', style: TextStyle(fontSize: 28)),
            TextField(
              key: const Key('pin_field'),
              controller: _c,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '输入 PIN (4-6位)',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('pin_submit'),
              onPressed: (_busy || _coolingDown) ? null : _submit,
              child: const Text('解锁'),
            ),
          ]),
        ),
      );
}
