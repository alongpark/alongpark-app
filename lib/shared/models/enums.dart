enum UserRole { client, driver }

enum ShipmentStatus {
  created,
  analyzing,
  matched,
  confirmed,
  pickedUp,
  inTransit,
  delivered,
  issue,
}

enum CompatibilityStatus {
  compatibleCertain,
  compatibleEffort,
  rejected,
}

enum IncidentType {
  delay,
  loadingProblem,
  doesNotFit,
  clientAbsent,
  other,
}

enum TruckStatus {
  idle,
  enRoute,
  loading,
  unloading,
}

extension ShipmentStatusLabel on ShipmentStatus {
  String get label => switch (this) {
        ShipmentStatus.created => 'Créé',
        ShipmentStatus.analyzing => 'Analyse en cours',
        ShipmentStatus.matched => 'Transport trouvé',
        ShipmentStatus.confirmed => 'Confirmé',
        ShipmentStatus.pickedUp => 'Pris en charge',
        ShipmentStatus.inTransit => 'En transit',
        ShipmentStatus.delivered => 'Livré',
        ShipmentStatus.issue => 'Incident signalé',
      };
}

extension CompatibilityLabel on CompatibilityStatus {
  String get label => switch (this) {
        CompatibilityStatus.compatibleCertain => 'Compatible certain',
        CompatibilityStatus.compatibleEffort => 'Compatible avec effort',
        CompatibilityStatus.rejected => 'Rejeté',
      };

  bool get isProposable => this != CompatibilityStatus.rejected;
}

extension IncidentTypeLabel on IncidentType {
  String get label => switch (this) {
        IncidentType.delay => 'Retard',
        IncidentType.loadingProblem => 'Problème de chargement',
        IncidentType.doesNotFit => 'Marchandise ne rentre pas',
        IncidentType.clientAbsent => 'Client absent',
        IncidentType.other => 'Autre',
      };
}
