import '../utils/prng.dart';

class Prize {
  final String id;
  final String name;
  final int weight;
  final int stock;
  const Prize(this.id, this.name, this.weight, this.stock);
  factory Prize.fromJson(Map<String, dynamic> j) =>
      Prize(j['id'] as String, j['name'] as String, j['weight'] as int, j['stock'] as int);
}

class Lottery {
  Lottery(this.prizes);
  final List<Prize> prizes;

  Prize draw(int seed) {
    final available = prizes.where((p) => p.weight > 0 && p.stock > 0).toList();
    final total = available.fold<int>(0, (s, p) => s + p.weight);
    if (total == 0) return prizes.first;
    final r = Mulberry32(seed).nextInt(total);
    var acc = 0;
    for (final p in available) {
      acc += p.weight;
      if (r < acc) return p;
    }
    return available.last;
  }
}
