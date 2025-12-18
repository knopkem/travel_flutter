/// Repositories for external API access.
///
/// This barrel file exports all repository classes for convenient importing.
/// Instead of importing individual repository files, use:
/// ```dart
/// import 'package:travel_flutter_app/repositories/repositories.dart';
/// ```
///
/// Available repositories:
/// - [GeocodingRepository]: Interface for location search
/// - [NominatimGeocodingRepository]: Nominatim API implementation
/// - [WikipediaRepository]: Interface for Wikipedia content
/// - [RestWikipediaRepository]: Wikipedia REST API implementation
/// - [POIRepository]: Interface for POI discovery
/// - [WikipediaGeosearchRepository]: Wikipedia Geosearch API implementation
/// - [OverpassRepository]: OpenStreetMap Overpass API implementation
library;

export 'geocoding_repository.dart';
export 'nominatim_geocoding_repository.dart';
export 'wikipedia_repository.dart';
export 'rest_wikipedia_repository.dart';
export 'poi_repository.dart';
export 'wikipedia_geosearch_repository.dart';
export 'overpass_repository.dart';
