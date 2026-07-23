class DailyUsage {
  final String date; // Format: "YYYY-MM-DD"
  final int uploadBytes;
  final int downloadBytes;
  final int sessionCount;
  final DateTime lastUpdated;

  DailyUsage({
    required this.date,
    this.uploadBytes = 0,
    this.downloadBytes = 0,
    this.sessionCount = 0,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  int get totalBytes => uploadBytes + downloadBytes;

  Map<String, dynamic> toJson() => {
        'date': date,
        'uploadBytes': uploadBytes,
        'downloadBytes': downloadBytes,
        'sessionCount': sessionCount,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory DailyUsage.fromJson(Map<String, dynamic> json) => DailyUsage(
        date: json['date'] as String? ?? '',
        uploadBytes: (json['uploadBytes'] as num?)?.toInt() ?? 0,
        downloadBytes: (json['downloadBytes'] as num?)?.toInt() ?? 0,
        sessionCount: (json['sessionCount'] as num?)?.toInt() ?? 0,
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.tryParse(json['lastUpdated'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  DailyUsage copyWith({
    int? uploadBytes,
    int? downloadBytes,
    int? sessionCount,
  }) =>
      DailyUsage(
        date: date,
        uploadBytes: uploadBytes ?? this.uploadBytes,
        downloadBytes: downloadBytes ?? this.downloadBytes,
        sessionCount: sessionCount ?? this.sessionCount,
        lastUpdated: DateTime.now(),
      );
}
