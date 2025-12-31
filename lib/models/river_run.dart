import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a whitewater river run.
///
/// Collection: river_runs
/// Document ID: riverId (e.g., "beaver-river-kinbasket-canyon")
class RiverRun {
  /// Unique identifier for the run (matches document ID)
  final String riverId;

  /// Name of the run section
  final String name;

  /// Name of the river
  final String river;

  /// Province/State code (e.g., "BC", "AB")
  final String province;

  /// Regional subdivision within province (e.g., "Vancouver Island", "Kootenays")
  final String? region;

  /// Difficulty rating (e.g., "Class IV/IV+")
  final String difficultyClass;

  /// Description of the run
  final String? description;

  /// Minimum difficulty rating (numeric)
  final int? difficultyMin;

  /// Maximum difficulty rating (numeric)
  final int? difficultyMax;

  /// Estimated time to complete
  final String? estimatedTime;

  /// Season for running (e.g., "Early Spring")
  final String? season;

  /// Flow measurement unit (e.g., "cms")
  final String flowUnit;

  /// Associated monitoring station ID
  final String? stationId;

  /// Permits and access information
  final String? permits;

  /// Access information
  final String? access;

  /// Shuttle information
  final String? shuttle;

  /// Gradient information
  final String? gradient;

  /// Length of the run
  final String? length;

  /// Flow ranges for the run
  final Map<String, dynamic>? flowRanges;

  /// Data source (e.g., "bcwhitewater.org")
  final String? source;

  /// Source URL
  final String? sourceUrl;

  /// Coordinates (lat/lng)
  final Map<String, double>? coordinates;

  /// Hazards information
  final String? hazards;

  /// Put-in location description
  final String? putIn;

  /// Take-out location description
  final String? takeOut;

  /// Put-in GPS coordinates {latitude, longitude}
  final Map<String, double>? putInCoordinates;

  /// Take-out GPS coordinates {latitude, longitude}
  final Map<String, double>? takeOutCoordinates;

  /// Gauge/monitoring station information {name, code}
  final Map<String, String>? gaugeStation;

  /// Scouting and portaging information
  final String? scouting;

  /// Full description text from source
  final String? fullText;

  /// Images with URLs and captions
  final List<Map<String, String>>? images;

  /// Minimum recommended flow
  final double? minRecommendedFlow;

  /// Maximum recommended flow
  final double? maxRecommendedFlow;

  /// Optimal minimum flow
  final double? optimalFlowMin;

  /// Optimal maximum flow
  final double? optimalFlowMax;

  /// Whether the station ID is valid
  final bool? hasValidStation;

  /// Who created this record
  final String? createdBy;

  /// When this record was created
  final DateTime? createdAt;

  /// When this record was last updated
  final DateTime? updatedAt;

  RiverRun({
    required this.riverId,
    required this.name,
    required this.river,
    required this.province,
    this.region,
    required this.difficultyClass,
    this.description,
    this.difficultyMin,
    this.difficultyMax,
    this.estimatedTime,
    this.season,
    this.flowUnit = 'cms',
    this.stationId,
    this.permits,
    this.access,
    this.shuttle,
    this.gradient,
    this.length,
    this.flowRanges,
    this.source,
    this.sourceUrl,
    this.coordinates,
    this.hazards,
    this.putIn,
    this.takeOut,
    this.putInCoordinates,
    this.takeOutCoordinates,
    this.gaugeStation,
    this.scouting,
    this.fullText,
    this.images,
    this.minRecommendedFlow,
    this.maxRecommendedFlow,
    this.optimalFlowMin,
    this.optimalFlowMax,
    this.hasValidStation,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Create RiverRun from Firestore document
  factory RiverRun.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RiverRun.fromMap(data, doc.id);
  }

  /// Create RiverRun from Map
  factory RiverRun.fromMap(Map<String, dynamic> data, [String? docId]) {
    return RiverRun(
      riverId: docId ?? data['riverId'] as String,
      name: data['name'] as String,
      river: data['river'] as String,
      province: data['province'] as String,
      region: _asString(data['region']),
      difficultyClass: data['difficultyClass'] as String,
      description: _asString(data['description']),
      difficultyMin: data['difficultyMin'] as int?,
      difficultyMax: data['difficultyMax'] as int?,
      estimatedTime: _asString(data['estimatedTime']),
      season: _asString(data['season']),
      flowUnit: _asString(data['flowUnit']) ?? 'cms',
      stationId: _asString(data['stationId']),
      permits: _asString(data['permits']),
      access: _asString(data['access']),
      shuttle: _asString(data['shuttle']),
      gradient: _asString(data['gradient']),
      length: _asString(data['length']),
      flowRanges: data['flowRanges'] as Map<String, dynamic>?,
      source: _asString(data['source']),
      sourceUrl: _asString(data['sourceUrl']),
      coordinates: data['coordinates'] != null
          ? Map<String, double>.from(data['coordinates'] as Map)
          : null,
      hazards: _asString(data['hazards']),
      putIn: _asString(data['putIn']),
      takeOut: _asString(data['takeOut']),
      putInCoordinates: data['putInCoordinates'] != null
          ? Map<String, double>.from(data['putInCoordinates'] as Map)
          : null,
      takeOutCoordinates: data['takeOutCoordinates'] != null
          ? Map<String, double>.from(data['takeOutCoordinates'] as Map)
          : null,
      gaugeStation: data['gaugeStation'] != null
          ? Map<String, String>.from(data['gaugeStation'] as Map)
          : null,
      scouting: _asString(data['scouting']),
      fullText: _asString(data['fullText']),
      images: data['images'] != null
          ? (data['images'] as List)
                .map((img) => Map<String, String>.from(img as Map))
                .toList()
          : null,
      minRecommendedFlow: (data['minRecommendedFlow'] as num?)?.toDouble(),
      maxRecommendedFlow: (data['maxRecommendedFlow'] as num?)?.toDouble(),
      optimalFlowMin: (data['optimalFlowMin'] as num?)?.toDouble(),
      optimalFlowMax: (data['optimalFlowMax'] as num?)?.toDouble(),
      hasValidStation: data['hasValidStation'] as bool?,
      createdBy: _asString(data['createdBy']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Helper to safely convert dynamic values to String
  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List) return value.join(', ');
    return value.toString();
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'riverId': riverId,
      'name': name,
      'river': river,
      'province': province,
      'difficultyClass': difficultyClass,
      'flowUnit': flowUnit,
    };

    // Add region if present
    if (region != null) map['region'] = region;

    // Add optional fields only if they're not null
    if (description != null) map['description'] = description;
    if (difficultyMin != null) map['difficultyMin'] = difficultyMin;
    if (difficultyMax != null) map['difficultyMax'] = difficultyMax;
    if (estimatedTime != null) map['estimatedTime'] = estimatedTime;
    if (season != null) map['season'] = season;
    if (stationId != null) map['stationId'] = stationId;
    if (permits != null) map['permits'] = permits;
    if (putInCoordinates != null) map['putInCoordinates'] = putInCoordinates;
    if (takeOutCoordinates != null) {
      map['takeOutCoordinates'] = takeOutCoordinates;
    }
    if (gaugeStation != null) map['gaugeStation'] = gaugeStation;
    if (scouting != null) map['scouting'] = scouting;
    if (fullText != null) map['fullText'] = fullText;
    if (access != null) map['access'] = access;
    if (shuttle != null) map['shuttle'] = shuttle;
    if (gradient != null) map['gradient'] = gradient;
    if (length != null) map['length'] = length;
    if (flowRanges != null) map['flowRanges'] = flowRanges;
    if (source != null) map['source'] = source;
    if (sourceUrl != null) map['sourceUrl'] = sourceUrl;
    if (coordinates != null) map['coordinates'] = coordinates;
    if (hazards != null) map['hazards'] = hazards;
    if (putIn != null) map['putIn'] = putIn;
    if (takeOut != null) map['takeOut'] = takeOut;
    if (minRecommendedFlow != null) {
      map['minRecommendedFlow'] = minRecommendedFlow;
    }
    if (maxRecommendedFlow != null) {
      map['maxRecommendedFlow'] = maxRecommendedFlow;
    }
    if (optimalFlowMin != null) map['optimalFlowMin'] = optimalFlowMin;
    if (optimalFlowMax != null) map['optimalFlowMax'] = optimalFlowMax;
    if (hasValidStation != null) map['hasValidStation'] = hasValidStation;
    if (createdBy != null) map['createdBy'] = createdBy;
    if (createdAt != null) map['createdAt'] = Timestamp.fromDate(createdAt!);
    if (updatedAt != null) map['updatedAt'] = Timestamp.fromDate(updatedAt!);

    return map;
  }

  /// Get difficulty text for display
  String get difficultyText {
    if (difficultyMin != null && difficultyMax != null) {
      if (difficultyMin == difficultyMax) {
        return 'Class ${_toRoman(difficultyMin!)}';
      } else {
        return 'Class ${_toRoman(difficultyMin!)}-${_toRoman(difficultyMax!)}';
      }
    } else if (difficultyMax != null) {
      return 'Class ${_toRoman(difficultyMax!)}';
    } else if (difficultyMin != null) {
      return 'Class ${_toRoman(difficultyMin!)}';
    } else {
      return difficultyClass;
    }
  }

  /// Convert number to Roman numerals
  String _toRoman(int number) {
    const romanNumerals = {10: 'X', 9: 'IX', 5: 'V', 4: 'IV', 1: 'I'};

    String result = '';
    romanNumerals.forEach((value, numeral) {
      while (number >= value) {
        result += numeral;
        number -= value;
      }
    });
    return result;
  }

  /// Copy with method for creating modified copies
  RiverRun copyWith({
    String? riverId,
    String? name,
    String? river,
    String? province,
    String? region,
    String? difficultyClass,
    String? description,
    Map<String, double>? putInCoordinates,
    Map<String, double>? takeOutCoordinates,
    Map<String, String>? gaugeStation,
    String? scouting,
    String? fullText,
    List<Map<String, String>>? images,
    double? minRecommendedFlow,
    double? maxRecommendedFlow,
    double? optimalFlowMin,
    double? optimalFlowMax,
    bool? hasValidStation,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RiverRun(
      riverId: riverId ?? this.riverId,
      name: name ?? this.name,
      river: river ?? this.river,
      province: province ?? this.province,
      region: region ?? this.region,
      difficultyClass: difficultyClass ?? this.difficultyClass,
      description: description ?? this.description,
      difficultyMin: difficultyMin,
      difficultyMax: difficultyMax,
      estimatedTime: estimatedTime,
      season: season,
      flowUnit: flowUnit,
      stationId: stationId,
      permits: permits,
      access: access,
      shuttle: shuttle,
      gradient: gradient,
      length: length,
      flowRanges: flowRanges,
      source: source,
      sourceUrl: sourceUrl,
      coordinates: coordinates,
      hazards: hazards,
      putIn: putIn,
      takeOut: takeOut,
      putInCoordinates: putInCoordinates ?? this.putInCoordinates,
      takeOutCoordinates: takeOutCoordinates ?? this.takeOutCoordinates,
      gaugeStation: gaugeStation ?? this.gaugeStation,
      scouting: scouting ?? this.scouting,
      fullText: fullText ?? this.fullText,
      images: images ?? this.images,
      minRecommendedFlow: minRecommendedFlow ?? this.minRecommendedFlow,
      maxRecommendedFlow: maxRecommendedFlow ?? this.maxRecommendedFlow,
      optimalFlowMin: optimalFlowMin ?? this.optimalFlowMin,
      optimalFlowMax: optimalFlowMax ?? this.optimalFlowMax,
      hasValidStation: hasValidStation ?? this.hasValidStation,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'RiverRun(riverId: $riverId, name: $name, river: $river, '
        'province: $province, region: $region, difficulty: $difficultyText)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RiverRun && other.riverId == riverId;
  }

  @override
  int get hashCode => riverId.hashCode;
}
