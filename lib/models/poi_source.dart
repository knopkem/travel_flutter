import 'package:flutter/material.dart';

/// Tracks which data source(s) provided information about a POI
enum POISource {
  wikipediaGeosearch,
  overpass,
  wikidata,
  googlePlaces;

  /// Returns a user-friendly display name for this source
  String get displayName {
    switch (this) {
      case POISource.wikipediaGeosearch:
        return 'Wikipedia';
      case POISource.overpass:
        return 'OpenStreetMap';
      case POISource.wikidata:
        return 'Wikidata';
      case POISource.googlePlaces:
        return 'Google Places';
    }
  }

  /// Returns an icon for this source
  IconData get icon {
    switch (this) {
      case POISource.wikipediaGeosearch:
        return Icons.article;
      case POISource.overpass:
        return Icons.map;
      case POISource.wikidata:
        return Icons.storage;
      case POISource.googlePlaces:
        return Icons.place;
    }
  }

  /// Returns a description for this source
  String get description {
    switch (this) {
      case POISource.wikipediaGeosearch:
        return 'Articles about notable places';
      case POISource.overpass:
        return 'Tourist attractions from OpenStreetMap';
      case POISource.wikidata:
        return 'Structured knowledge base';
      case POISource.googlePlaces:
        return 'Commercial places & reviews';
    }
  }

  /// Priority for merge preference (higher = preferred)
  /// Google Places > Wikipedia > Wikidata > Overpass
  int get priority {
    switch (this) {
      case POISource.googlePlaces:
        return 4;
      case POISource.wikipediaGeosearch:
        return 3;
      case POISource.wikidata:
        return 2;
      case POISource.overpass:
        return 1;
    }
  }

  /// Whether this source requires an API key
  bool get requiresApiKey {
    switch (this) {
      case POISource.googlePlaces:
        return true;
      default:
        return false;
    }
  }
}
