import 'enums.dart';

class IncidentReport {
  final String id;
  final String missionId;
  final IncidentType type;
  final String? note;
  final DateTime createdAt;

  const IncidentReport({
    required this.id,
    required this.missionId,
    required this.type,
    this.note,
    required this.createdAt,
  });
}
