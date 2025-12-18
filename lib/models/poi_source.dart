/// Tracks which data source(s) provided information about a POI
enum POISource {
  wikipediaGeosearch,
  overpass,
  wikidata;

  /// Returns a user-friendly display name for this source
  String get displayName {
    switch (this) {
      case POISource.wikipediaGeosearch:
        return 'Wikipedia';
      case POISource.overpass:
        return 'OpenStreetMap';
      case POISource.wikidata:
        return 'Wikidata';
    }
  }

  /// Priority for merge preference (higher = preferred)
  /// Wikipedia > Wikidata > Overpass
  int get priority {
    switch (this) {
      case POISource.wikipediaGeosearch:
        return 3;
      case POISource.wikidata:
        return 2;
      case POISource.overpass:
        return 1;
    }
  }
}
