import 'package:flutter/material.dart';
import '../../services/lottery.dart';

class LotteryScreen extends StatefulWidget {
  const LotteryScreen({super.key, required this.prizes});
  final List<Prize> prizes;
  @override
  State<LotteryScreen> createState() => _LotteryScreenState();
}

class _LotteryScreenState extends State<LotteryScreen> {
  Prize? _result;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('抽奖')),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_result == null ? '点击抽奖' : '恭喜获得：${_result!.name}', style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () {
            final seed = DateTime.now().millisecondsSinceEpoch;
            setState(() => _result = Lottery(widget.prizes).draw(seed));
          }, child: const Text('抽奖')),
        ])),
      );
}
