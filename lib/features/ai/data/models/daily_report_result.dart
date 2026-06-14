/// Result of the `ai-daily-report` Edge Function — a WhatsApp-ready summary.
class DailyReportResult {
  final String summary;
  final String language; // 'en' | 'hi'
  final String projectId;
  final String date; // yyyy-mm-dd

  const DailyReportResult({
    required this.summary,
    required this.language,
    required this.projectId,
    required this.date,
  });

  factory DailyReportResult.fromJson(Map<String, dynamic> json) =>
      DailyReportResult(
        summary: (json['summary'] ?? '').toString(),
        language: (json['language'] as String?) ?? 'en',
        projectId: (json['project_id'] ?? '').toString(),
        date: (json['date'] ?? '').toString(),
      );
}
