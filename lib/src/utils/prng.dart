class Mulberry32 {
  Mulberry32(int seed) : _s = seed & 0xFFFFFFFF;
  int _s;

  double next() {
    _s = (_s + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _s;
    t = (t ^ (t >> 15)) * (t | 1) & 0xFFFFFFFF;
    t = (t ^ (t + ((t ^ (t >> 7)) * (t | 61) & 0xFFFFFFFF))) & 0xFFFFFFFF;
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0;
  }

  int nextInt(int max) => (next() * max).floor();
}
