/// A progress photo / document item shown read-only in the client timeline.
///
/// Sourced from `public.project_photos` when that table exists, otherwise from
/// image/PDF rows in `public.blueprints` (both gated by RLS in migration 058).
/// Plain Dart class — no codegen.
class ClientPhoto {
  final String id;
  final String projectId;
  final String url;
  final String? title;
  final String? caption;
  final DateTime? capturedAt;

  const ClientPhoto({
    required this.id,
    required this.projectId,
    required this.url,
    this.title,
    this.caption,
    this.capturedAt,
  });

  /// From a `project_photos` row.
  factory ClientPhoto.fromPhotoJson(Map<String, dynamic> json) {
    return ClientPhoto(
      id: json['id'] as String,
      projectId: json['project_id'] as String? ?? '',
      url: (json['photo_url'] ?? json['url'] ?? json['image_url'] ?? '')
          .toString(),
      title: json['title'] as String?,
      caption: json['caption'] as String? ?? json['description'] as String?,
      capturedAt: _parseDate(
        json['captured_at'] ?? json['taken_at'] ?? json['created_at'],
      ),
    );
  }

  /// From a `blueprints` row used as a document/photo item.
  factory ClientPhoto.fromBlueprintJson(Map<String, dynamic> json) {
    return ClientPhoto(
      id: json['id'] as String,
      projectId: json['project_id'] as String? ?? '',
      url: (json['file_url'] ?? '').toString(),
      title: json['title'] as String?,
      caption: json['description'] as String?,
      capturedAt: _parseDate(json['created_at']),
    );
  }

  factory ClientPhoto.fromJson(Map<String, dynamic> json) =>
      ClientPhoto.fromPhotoJson(json);

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'url': url,
        'title': title,
        'caption': caption,
        'captured_at': capturedAt?.toIso8601String(),
      };

  ClientPhoto copyWith({
    String? id,
    String? projectId,
    String? url,
    String? title,
    String? caption,
    DateTime? capturedAt,
  }) {
    return ClientPhoto(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      url: url ?? this.url,
      title: title ?? this.title,
      caption: caption ?? this.caption,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }

  /// True when the source is an image (heuristic on the file extension).
  bool get isImage {
    final lower = url.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
