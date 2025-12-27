import 'poi_type.dart';
import 'poi_source.dart';
import 'location.dart';
import '../utils/distance_calculator.dart';

/// Represents a Point of Interest (notable place, attraction, landmark, or sight)
class POI {
  final String id;
  final String name;
  final POIType type;
  final double latitude;
  final double longitude;
  final double distanceFromCity;
  final List<POISource> sources;
  final String? description;
  final String? wikipediaTitle;
  final String?
      wikipediaLang; // Language code from Wikipedia tag (e.g., 'de', 'fr')
  final String? wikidataId;
  final String? imageUrl;
  final String? website;
  final String? openingHours;
  final int notabilityScore;
  final DateTime discoveredAt;

  // Google Places specific fields
  final String? placeId; // Google Places place_id for fetching details
  final double? rating; // Average rating (1-5)
  final int? userRatingsTotal; // Number of reviews
  final String? formattedAddress; // Full formatted address
  final String? formattedPhoneNumber; // Phone number
  final int? priceLevel; // 0-4 (0=free, 4=expensive)
  final bool? isOpenNow; // Current open/closed status

  POI({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.distanceFromCity,
    required this.sources,
    this.description,
    this.wikipediaTitle,
    this.wikipediaLang,
    this.wikidataId,
    this.imageUrl,
    this.website,
    this.openingHours,
    required this.notabilityScore,
    required this.discoveredAt,
    this.placeId,
    this.rating,
    this.userRatingsTotal,
    this.formattedAddress,
    this.formattedPhoneNumber,
    this.priceLevel,
    this.isOpenNow,
  }) {
    if (latitude < -90 || latitude > 90) {
      throw ArgumentError('Latitude must be between -90 and 90');
    }
    if (longitude < -180 || longitude > 180) {
      throw ArgumentError('Longitude must be between -180 and 180');
    }
    if (distanceFromCity < 0) {
      throw ArgumentError('Distance from city must be non-negative');
    }
    if (sources.isEmpty) {
      throw ArgumentError('POI must have at least one source');
    }
    if (notabilityScore < 0 || notabilityScore > 100) {
      throw ArgumentError('Notability score must be between 0 and 100');
    }
  }

  /// Create POI from Wikipedia Geosearch API response
  factory POI.fromWikipediaGeosearch(
    Map<String, dynamic> json,
    Location city,
  ) {
    final lat = (json['lat'] as num).toDouble();
    final lon = (json['lon'] as num).toDouble();
    final title = json['title'] as String;
    final dist = json['dist'] as num;

    return POI(
      id: _generateId(title, lat, lon),
      name: title,
      type: POIType.touristAttraction,
      latitude: lat,
      longitude: lon,
      distanceFromCity: dist.toDouble(),
      sources: [POISource.wikipediaGeosearch],
      wikipediaTitle: title,
      notabilityScore: 75,
      discoveredAt: DateTime.now(),
    );
  }

  /// Create POI from OpenStreetMap Overpass API response
  factory POI.fromOverpass(
    Map<String, dynamic> element,
    Location city,
  ) {
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    final lat = (element['lat'] as num).toDouble();
    final lon = (element['lon'] as num).toDouble();
    final name = tags['name'] as String? ?? 'Unnamed Location';

    final distanceFromCity = calculateDistance(
      city.latitude,
      city.longitude,
      lat,
      lon,
    );

    final wikipediaTag = tags['wikipedia'] as String?;
    final wikipediaInfo = _extractWikipediaInfo(wikipediaTag);

    return POI(
      id: _generateId(name, lat, lon),
      name: name,
      description: tags['description'] as String?,
      type: _mapOSMTagToType(tags),
      latitude: lat,
      longitude: lon,
      distanceFromCity: distanceFromCity,
      sources: [POISource.overpass],
      wikipediaTitle: wikipediaInfo?.title,
      wikipediaLang: wikipediaInfo?.lang,
      wikidataId: tags['wikidata'] as String?,
      website: tags['website'] as String?,
      openingHours: tags['opening_hours'] as String?,
      notabilityScore: _calculateNotabilityFromTags(tags),
      discoveredAt: DateTime.now(),
    );
  }

  /// Create POI from Wikidata SPARQL query response
  factory POI.fromWikidata(
    Map<String, dynamic> binding,
    Location city,
  ) {
    final coordString = binding['coord']['value'] as String;
    final coord = _parseWKTCoordinate(coordString);
    final wikidataId = _extractWikidataId(binding['place']['value'] as String);
    final name = binding['placeLabel']['value'] as String;

    final distanceFromCity = calculateDistance(
      city.latitude,
      city.longitude,
      coord['lat']!,
      coord['lon']!,
    );

    final wikipediaUrl = binding['wikipedia']?['value'] as String?;
    final wikipediaInfo = _extractWikipediaInfoFromUrl(wikipediaUrl);

    return POI(
      id: _generateId(name, coord['lat']!, coord['lon']!),
      name: name,
      description: binding['description']?['value'] as String?,
      type: POIType.other,
      latitude: coord['lat']!,
      longitude: coord['lon']!,
      distanceFromCity: distanceFromCity,
      sources: [POISource.wikidata],
      wikipediaTitle: wikipediaInfo?.title,
      wikipediaLang: wikipediaInfo?.lang,
      wikidataId: wikidataId,
      notabilityScore: _calculateNotabilityFromWikidata(binding),
      discoveredAt: DateTime.now(),
    );
  }

  /// Create POI from Google Places API response
  factory POI.fromGooglePlaces(
    Map<String, dynamic> result,
    Location city, {
    String? apiKey,
  }) {
    final geometry = result['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;
    final lat = (location['lat'] as num).toDouble();
    final lng = (location['lng'] as num).toDouble();
    final name = result['name'] as String;

    final distanceFromCity = calculateDistance(
      city.latitude,
      city.longitude,
      lat,
      lng,
    );

    return POI(
      id: _generateId(name, lat, lng),
      name: name,
      type: _mapGooglePlaceType(result['types'] as List<dynamic>?),
      latitude: lat,
      longitude: lng,
      distanceFromCity: distanceFromCity,
      sources: [POISource.googlePlaces],
      description: result['vicinity'] as String?,
      imageUrl: _extractGooglePhotoUrl(result, apiKey),
      notabilityScore: _calculateGoogleNotability(result),
      discoveredAt: DateTime.now(),
      placeId: result['place_id'] as String?,
      rating: (result['rating'] as num?)?.toDouble(),
      userRatingsTotal: result['user_ratings_total'] as int?,
      priceLevel: result['price_level'] as int?,
      isOpenNow: (result['opening_hours'] as Map<String, dynamic>?)?['open_now']
          as bool?,
    );
  }

  /// Merge duplicate POIs from multiple sources
  static POI merge(List<POI> duplicates) {
    if (duplicates.isEmpty) {
      throw ArgumentError('Cannot merge empty list of POIs');
    }
    if (duplicates.length == 1) {
      return duplicates.first;
    }

    // Sort by priority (Wikipedia > Wikidata > Overpass)
    final sorted = List<POI>.from(duplicates)
      ..sort((a, b) {
        final aPriority =
            a.sources.map((s) => s.priority).reduce((a, b) => a > b ? a : b);
        final bPriority =
            b.sources.map((s) => s.priority).reduce((a, b) => a > b ? a : b);
        return bPriority.compareTo(aPriority);
      });

    final primary = sorted.first;
    final allSources = duplicates.expand((poi) => poi.sources).toSet().toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    return POI(
      id: primary.id,
      name: primary.name,
      type: primary.type,
      latitude: primary.latitude,
      longitude: primary.longitude,
      distanceFromCity: primary.distanceFromCity,
      sources: allSources,
      description: _pickBest(duplicates.map((p) => p.description)),
      wikipediaTitle: _pickBest(duplicates.map((p) => p.wikipediaTitle)),
      wikipediaLang: _pickBest(duplicates.map((p) => p.wikipediaLang)),
      wikidataId: _pickBest(duplicates.map((p) => p.wikidataId)),
      imageUrl: _pickBest(duplicates.map((p) => p.imageUrl)),
      website: _pickBest(duplicates.map((p) => p.website)),
      openingHours: _pickBest(duplicates.map((p) => p.openingHours)),
      notabilityScore: duplicates
          .map((p) => p.notabilityScore)
          .reduce((a, b) => a > b ? a : b),
      discoveredAt: duplicates
          .map((p) => p.discoveredAt)
          .reduce((a, b) => a.isBefore(b) ? a : b),
      placeId: _pickBest(duplicates.map((p) => p.placeId)),
      rating: duplicates
          .map((p) => p.rating)
          .where((r) => r != null)
          .fold<double?>(null, (max, r) => max == null || r! > max ? r : max),
      userRatingsTotal: duplicates
          .map((p) => p.userRatingsTotal)
          .where((t) => t != null)
          .fold<int?>(null, (sum, t) => (sum ?? 0) + t!),
      formattedAddress: _pickBest(duplicates.map((p) => p.formattedAddress)),
      formattedPhoneNumber:
          _pickBest(duplicates.map((p) => p.formattedPhoneNumber)),
      priceLevel: _pickBest(duplicates.map((p) => p.priceLevel)),
      isOpenNow: duplicates
          .map((p) => p.isOpenNow)
          .where((o) => o != null)
          .firstOrNull,
    );
  }

  /// Generate consistent ID from name and coordinates
  static String _generateId(String name, double lat, double lon) {
    final normalized = name.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final latRounded = (lat * 10000).round();
    final lonRounded = (lon * 10000).round();
    return '$normalized-$latRounded-$lonRounded'.hashCode.abs().toString();
  }

  /// Map OpenStreetMap tags to POIType
  static POIType _mapOSMTagToType(Map<String, dynamic> tags) {
    if (tags['historic'] != null) {
      final historic = tags['historic'] as String;
      if (historic == 'monument' || historic == 'memorial') {
        return POIType.monument;
      }
      return POIType.historicSite;
    }

    if (tags['tourism'] != null) {
      final tourism = tags['tourism'] as String;
      switch (tourism) {
        case 'museum':
          return POIType.museum;
        case 'viewpoint':
          return POIType.viewpoint;
        case 'attraction':
          return POIType.touristAttraction;
        default:
          return POIType.touristAttraction;
      }
    }

    if (tags['leisure'] == 'park') {
      return POIType.park;
    }

    if (tags['amenity'] == 'place_of_worship') {
      return POIType.religiousSite;
    }

    return POIType.other;
  }

  /// Calculate notability from OSM tags
  static int _calculateNotabilityFromTags(Map<String, dynamic> tags) {
    int score = 50;
    if (tags['wikidata'] != null) score += 20;
    if (tags['wikipedia'] != null) score += 15;
    if (tags['website'] != null) score += 5;
    if (tags['unesco'] != null) score += 30;
    return score.clamp(0, 100);
  }

  /// Map Google Places types to POIType
  static POIType _mapGooglePlaceType(List<dynamic>? types) {
    if (types == null || types.isEmpty) return POIType.other;

    final typeSet = types.map((t) => t.toString()).toSet();

    if (typeSet.contains('museum')) return POIType.museum;
    if (typeSet.contains('church') ||
        typeSet.contains('mosque') ||
        typeSet.contains('synagogue') ||
        typeSet.contains('hindu_temple') ||
        typeSet.contains('place_of_worship')) {
      return POIType.religiousSite;
    }
    if (typeSet.contains('park')) return POIType.park;
    if (typeSet.contains('tourist_attraction')) {
      return POIType.touristAttraction;
    }

    return POIType.other;
  }

  /// Extract photo URL from Google Places result (if available)
  static String? _extractGooglePhotoUrl(
      Map<String, dynamic> result, String? apiKey) {
    if (apiKey == null || apiKey.isEmpty) return null;

    final photos = result['photos'] as List<dynamic>?;
    if (photos == null || photos.isEmpty) return null;

    final photoReference = photos[0]['photo_reference'] as String?;
    if (photoReference == null) return null;

    // Generate Google Places Photo API URL
    return 'https://maps.googleapis.com/maps/api/place/photo?'
        'photoreference=$photoReference&maxwidth=800&key=$apiKey';
  }

  /// Calculate notability score from Google Places data
  static int _calculateGoogleNotability(Map<String, dynamic> result) {
    int score = 50; // Base score

    // Higher rating = more notable
    final rating = result['rating'] as num?;
    if (rating != null) {
      score += (rating * 5).round(); // Up to +25 for 5-star rating
    }

    // More reviews = more notable
    final reviewCount = result['user_ratings_total'] as int?;
    if (reviewCount != null) {
      if (reviewCount > 10000) {
        score += 25;
      } else if (reviewCount > 1000) {
        score += 15;
      } else if (reviewCount > 100) {
        score += 10;
      } else if (reviewCount > 10) {
        score += 5;
      }
    }

    return score.clamp(0, 100);
  }

  /// Calculate notability from Wikidata binding
  static int _calculateNotabilityFromWikidata(Map<String, dynamic> binding) {
    int score = 60;
    if (binding['wikipedia'] != null) score += 15;
    if (binding['heritageStatus'] != null) {
      final status = binding['heritageStatus']['value'] as String;
      if (status.contains('UNESCO')) {
        score += 30;
      } else {
        score += 15;
      }
    }
    if (binding['visitorCount'] != null) {
      final count = int.tryParse(binding['visitorCount']['value'] as String);
      if (count != null && count > 1000000) score += 10;
    }
    if (binding['inception'] != null) score += 5;
    return score.clamp(0, 100);
  }

  /// Extract Wikipedia info from wikipedia tag (format: "lang:Title")
  /// Returns a record with lang and title, or null if parsing fails
  static ({String lang, String title})? _extractWikipediaInfo(
      String? wikipedia) {
    if (wikipedia == null) return null;
    final parts = wikipedia.split(':');
    if (parts.length < 2) return null;
    final lang = parts[0].toLowerCase();
    final title = parts.sublist(1).join(':'); // Handle titles with colons
    return (lang: lang, title: title);
  }

  /// Extract Wikipedia info from full URL (e.g., https://de.wikipedia.org/wiki/Title)
  /// Returns a record with lang and title, or null if parsing fails
  static ({String lang, String title})? _extractWikipediaInfoFromUrl(
      String? url) {
    if (url == null) return null;
    // URL format: https://XX.wikipedia.org/wiki/Title
    final langMatch =
        RegExp(r'https?://([a-z]{2,})\.wikipedia\.org/').firstMatch(url);
    if (langMatch == null) return null;
    final lang = langMatch.group(1)!;
    final title = url.split('/').last;
    return (lang: lang, title: Uri.decodeComponent(title.replaceAll('_', ' ')));
  }

  /// Extract Wikidata ID from entity URI
  static String _extractWikidataId(String uri) {
    return uri.split('/').last;
  }

  /// Parse WKT coordinate format: "Point(lon lat)" → {lat, lon}
  static Map<String, double> _parseWKTCoordinate(String wkt) {
    final match = RegExp(r'Point\(([-\d.]+)\s+([-\d.]+)\)').firstMatch(wkt);
    if (match == null) {
      throw FormatException('Invalid WKT coordinate: $wkt');
    }
    return {
      'lon': double.parse(match.group(1)!),
      'lat': double.parse(match.group(2)!),
    };
  }

  /// Pick the best (first non-null) value from a list
  static T? _pickBest<T>(Iterable<T?> values) {
    return values.firstWhere((v) => v != null, orElse: () => null);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is POI && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
