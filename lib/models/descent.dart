import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a user's descent/log of a river run.
///
/// Collection: descents (top-level)
/// Document ID: auto-generated
class Descent {
  /// Unique identifier for the descent
  final String id;

  /// ID of the river run
  final String runId;

  /// Name of the run (denormalized for easy display)
  final String runName;

  /// User ID who logged this descent
  final String userId;

  /// Date of the descent
  final DateTime date;

  /// Flow at time of descent (optional)
  final double? flow;

  /// Flow unit (e.g., "cms")
  final String? flowUnit;

  /// User's notes about the descent
  final String? notes;

  /// Rating (1-5 stars, optional)
  final int? rating;

  /// Difficulty encountered (may differ from published difficulty)
  final String? difficulty;

  /// Photos from the descent
  final List<String>? photos;

  /// Whether this descent is publicly visible
  final bool isPublic;

  /// Created timestamp
  final DateTime createdAt;

  /// Updated timestamp
  final DateTime? updatedAt;

  Descent({
    required this.id,
    required this.runId,
    required this.runName,
    required this.userId,
    required this.date,
    this.flow,
    this.flowUnit,
    this.notes,
    this.rating,
    this.difficulty,
    this.photos,
    this.isPublic = false,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create from Firestore document
  factory Descent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Descent(
      id: doc.id,
      runId: data['runId'] ?? '',
      runName: data['runName'] ?? '',
      userId: data['userId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      flow: data['flow']?.toDouble(),
      flowUnit: data['flowUnit'],
      notes: data['notes'],
      rating: data['rating'],
      difficulty: data['difficulty'],
      photos: data['photos'] != null ? List<String>.from(data['photos']) : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'runId': runId,
      'runName': runName,
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'flow': flow,
      'flowUnit': flowUnit,
      'notes': notes,
      'rating': rating,
      'difficulty': difficulty,
      'photos': photos,
      'isPublic': isPublic,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  Descent copyWith({
    String? id,
    String? runId,
    String? runName,
    String? userId,
    DateTime? date,
    double? flow,
    String? flowUnit,
    String? notes,
    int? rating,
    String? difficulty,
    List<String>? photos,
    bool? isPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Descent(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      runName: runName ?? this.runName,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      flow: flow ?? this.flow,
      flowUnit: flowUnit ?? this.flowUnit,
      notes: notes ?? this.notes,
      rating: rating ?? this.rating,
      difficulty: difficulty ?? this.difficulty,
      photos: photos ?? this.photos,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
