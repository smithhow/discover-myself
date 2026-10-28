/// One university-major cluster from `assets/data/majors.json`.
class MajorCluster {
  MajorCluster({
    required this.name,
    required this.summary,
    required this.majors,
    required this.weights,
    required this.minimums,
  });

  final String name;
  final String summary;
  final List<String> majors;
  final Map<String, double> weights;
  final Map<String, double> minimums;

  factory MajorCluster.fromJson(Map<String, dynamic> json) => MajorCluster(
    name: json['name'] as String,
    summary: (json['summary'] as String?) ?? '',
    majors: ((json['majors'] as List?) ?? const []).cast<String>(),
    weights: _doubleMap(json['weights']),
    minimums: _doubleMap(json['minimums']),
  );
}

/// One career from `assets/data/careers_advice.json`.
class CareerAdviceItem {
  CareerAdviceItem({
    required this.name,
    required this.cluster,
    required this.weights,
    required this.entry,
  });

  final String name;
  final String cluster;
  final Map<String, double> weights;
  final String entry;

  factory CareerAdviceItem.fromJson(Map<String, dynamic> json) =>
      CareerAdviceItem(
        name: json['name'] as String,
        cluster: json['cluster'] as String,
        weights: _doubleMap(json['weights']),
        entry: (json['entry'] as String?) ?? '',
      );
}

/// Parsed guidance content, with malformed entries skipped.
class GuidanceContent {
  GuidanceContent({required this.clusters, required this.careers});

  final List<MajorCluster> clusters;
  final List<CareerAdviceItem> careers;

  static GuidanceContent parse(
    Map<String, dynamic> majorsJson,
    Map<String, dynamic> careersJson,
  ) {
    final clusters = <MajorCluster>[];
    for (final raw in (majorsJson['clusters'] as List? ?? const [])) {
      try {
        if (raw is Map<String, dynamic>) {
          clusters.add(MajorCluster.fromJson(raw));
        }
      } catch (_) {
        // Skip malformed cluster entries.
      }
    }

    final names = {for (final cluster in clusters) cluster.name};
    final careers = <CareerAdviceItem>[];
    for (final raw in (careersJson['items'] as List? ?? const [])) {
      try {
        if (raw is Map<String, dynamic>) {
          final item = CareerAdviceItem.fromJson(raw);
          if (names.contains(item.cluster)) careers.add(item);
        }
      } catch (_) {
        // Skip malformed career entries.
      }
    }

    return GuidanceContent(clusters: clusters, careers: careers);
  }
}

class MajorFit {
  MajorFit({
    required this.cluster,
    required this.summary,
    required this.majors,
    required this.fit,
    required this.reasons,
    this.caution,
  });

  final String cluster;
  final String summary;
  final List<String> majors;
  final double fit;
  final List<String> reasons;
  final String? caution;
}

class CareerFit {
  CareerFit({
    required this.name,
    required this.cluster,
    required this.fit,
    required this.reasons,
    required this.entry,
  });

  final String name;
  final String cluster;
  final double fit;
  final List<String> reasons;
  final String entry;
}

enum LeadershipType {
  leader('领导型'),
  executor('执行型'),
  specialist('专业骨干型'),
  hybrid('混合型'),
  explorer('探索待发展');

  const LeadershipType(this.label);

  final String label;
}

class LeadershipProfile {
  LeadershipProfile({
    required this.type,
    required this.leadership,
    required this.execution,
    required this.professionalDepth,
    required this.reasons,
    required this.tips,
  });

  final LeadershipType type;
  final double leadership;
  final double execution;
  final double professionalDepth;
  final List<String> reasons;
  final List<String> tips;
}

class GuidanceReport {
  GuidanceReport({
    required this.majors,
    required this.careers,
    required this.leadership,
    required this.nextSteps,
    required this.hasWorkstyle,
  });

  final List<MajorFit> majors;
  final List<CareerFit> careers;
  final LeadershipProfile leadership;
  final List<String> nextSteps;
  final bool hasWorkstyle;
}

Map<String, double> _doubleMap(Object? raw) {
  if (raw is! Map) return const {};
  final out = <String, double>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is num) out[entry.key as String] = value.toDouble();
  }
  return out;
}
