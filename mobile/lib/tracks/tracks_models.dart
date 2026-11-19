import 'package:flutter/material.dart';

import '../social/social_models.dart';

/// Eixos da trilha, na ordem em que aparecem.
enum TrackCategory {
  guard('GUARD', 'Guarda', Icons.shield_outlined),
  pass('PASS', 'Passagem', Icons.call_split_rounded),
  control('CONTROL', 'Controle', Icons.back_hand_outlined),
  submission('SUBMISSION', 'Finalizações', Icons.sports_martial_arts_rounded);

  const TrackCategory(this.apiName, this.label, this.icon);

  final String apiName;
  final String label;
  final IconData icon;

  static TrackCategory fromApi(String value) =>
      values.firstWhere((category) => category.apiName == value, orElse: () => TrackCategory.guard);
}

/// Cor "#rrggbb" da faixa; inválida vira branco.
Color parseBeltColor(String? hex) {
  final value = int.tryParse((hex ?? '').replaceFirst('#', ''), radix: 16);
  return value == null ? const Color(0xFFF5F5F5) : Color(0xFF000000 | value);
}

/// "Faixa Branca" → "Descomplicando a Faixa Branca".
String tracksTitle(String beltTitle) => 'Descomplicando a $beltTitle';

class TrackProgress {
  const TrackProgress({this.completed = 0, this.total = 0, this.percent = 0});

  factory TrackProgress.fromJson(Json? json) => json == null
      ? const TrackProgress()
      : TrackProgress(
          completed: json['completed'] as int,
          total: json['total'] as int,
          percent: json['percent'] as int,
        );

  final int completed;
  final int total;
  final int percent;

  double get fraction => total == 0 ? 0 : completed / total;
}

class TrackBelt {
  const TrackBelt({
    required this.id,
    required this.name,
    required this.title,
    required this.color,
    required this.order,
    this.current = false,
    this.degree = 0,
    this.progress = const TrackProgress(),
    this.lessonCount = 0,
    this.publishedCount = 0,
    this.studentCount = 0,
  });

  factory TrackBelt.fromJson(Json json) => TrackBelt(
    id: json['id'] as String,
    name: json['name'] as String,
    title: json['title'] as String,
    color: parseBeltColor(json['color'] as String?),
    order: json['order'] as int,
    current: json['current'] as bool? ?? false,
    degree: json['degree'] as int? ?? 0,
    progress: TrackProgress.fromJson(json['progress'] as Json?),
    lessonCount: json['lessonCount'] as int? ?? 0,
    publishedCount: json['publishedCount'] as int? ?? 0,
    studentCount: json['studentCount'] as int? ?? 0,
  );

  final String id;
  final String name;
  final String title;
  final Color color;
  final int order;
  final bool current;
  final int degree;
  final TrackProgress progress;
  final int lessonCount;
  final int publishedCount;
  final int studentCount;
}

class TrackLesson {
  const TrackLesson({
    required this.id,
    required this.beltId,
    required this.category,
    required this.title,
    this.description,
    this.media,
    this.published = false,
    this.completed = false,
  });

  factory TrackLesson.fromJson(Json json) => TrackLesson(
    id: json['id'] as String,
    beltId: json['beltId'] as String,
    category: TrackCategory.fromApi(json['category'] as String),
    title: json['title'] as String,
    description: json['description'] as String?,
    media: json['media'] == null ? null : SocialMedia.fromJson(json['media'] as Json),
    published: json['published'] as bool? ?? false,
    completed: json['completed'] as bool? ?? false,
  );

  final String id;
  final String beltId;
  final TrackCategory category;
  final String title;
  final String? description;
  final SocialMedia? media;
  final bool published;
  final bool completed;

  TrackLesson copyWith({bool? completed, bool? published}) => TrackLesson(
    id: id,
    beltId: beltId,
    category: category,
    title: title,
    description: description,
    media: media,
    published: published ?? this.published,
    completed: completed ?? this.completed,
  );
}

class TrackSection {
  const TrackSection({required this.category, required this.lessons, this.progress = const TrackProgress()});

  factory TrackSection.fromJson(Json json) => TrackSection(
    category: TrackCategory.fromApi(json['key'] as String),
    lessons: [for (final item in json['lessons'] as List) TrackLesson.fromJson(item as Json)],
    progress: TrackProgress.fromJson(json['progress'] as Json?),
  );

  final TrackCategory category;
  final List<TrackLesson> lessons;
  final TrackProgress progress;
}

/// Trilha do aluno: faixa atual, faixas anteriores para revisão e os conceitos liberados.
class StudentTrack {
  const StudentTrack({
    required this.current,
    required this.belts,
    required this.belt,
    required this.progress,
    required this.sections,
  });

  factory StudentTrack.fromJson(Json json) => StudentTrack(
    current: TrackBelt.fromJson(json['current'] as Json),
    belts: [for (final item in json['belts'] as List) TrackBelt.fromJson(item as Json)],
    belt: TrackBelt.fromJson(json['belt'] as Json),
    progress: TrackProgress.fromJson(json['progress'] as Json?),
    sections: [for (final item in json['categories'] as List) TrackSection.fromJson(item as Json)],
  );

  final TrackBelt current;
  final List<TrackBelt> belts;
  final TrackBelt belt;
  final TrackProgress progress;
  final List<TrackSection> sections;
}

/// Visão do professor: todas as faixas e todos os conceitos (liberados ou em rascunho).
class StaffTrack {
  const StaffTrack({required this.belts, required this.belt, required this.sections});

  factory StaffTrack.fromJson(Json json) => StaffTrack(
    belts: [for (final item in json['belts'] as List) TrackBelt.fromJson(item as Json)],
    belt: json['belt'] == null ? null : TrackBelt.fromJson(json['belt'] as Json),
    sections: [for (final item in json['categories'] as List) TrackSection.fromJson(item as Json)],
  );

  final List<TrackBelt> belts;
  final TrackBelt? belt;
  final List<TrackSection> sections;
}
