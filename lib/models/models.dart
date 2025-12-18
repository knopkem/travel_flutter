/// Data models for the Location Search & Wikipedia Browser app.
///
/// This barrel file exports all data model classes for convenient importing.
/// Instead of importing individual model files, use:
/// ```dart
/// import 'package:travel_flutter_app/models/models.dart';
/// ```
///
/// Available models:
/// - [Location]: Saved location with coordinates
/// - [LocationSuggestion]: Temporary search result
/// - [WikipediaContent]: Wikipedia article summary data
/// - [POI]: Point of Interest with coordinates and metadata
/// - [POIType]: Categorical types for POIs
/// - [POISource]: API sources for POI data
library;

export 'location.dart';
export 'location_suggestion.dart';
export 'wikipedia_content.dart';
export 'poi.dart';
export 'poi_type.dart';
export 'poi_source.dart';
