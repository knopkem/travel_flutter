import '../models/poi.dart';

/// Utility class for extracting and matching brand names from POI names
class BrandMatcher {
  // Curated list of common retail brands in Germany/Europe
  static const List<String> _knownBrands = [
    // Supermarkets
    'Lidl',
    'Aldi',
    'Rewe',
    'Edeka',
    'Penny',
    'Netto',
    'Norma',
    'Kaufland',
    
    // Hardware/DIY
    'Bauhaus',
    'OBI',
    'Hornbach',
    'Toom',
    
    // Drugstores/Pharmacies
    'DM',
    'Rossmann',
    'Müller',
    
    // Gas Stations
    'Shell',
    'Aral',
    'Esso',
    'Total',
    'Jet',
    
    // Fast Food
    'McDonald\'s',
    'Burger King',
    'KFC',
    'Subway',
    
    // Bakeries
    'Kamps',
    'Backwerk',
    'Ditsch',
    
    // Other retail
    'Saturn',
    'Media Markt',
    'Ikea',
    'Decathlon',
  ];

  /// Extract brand name from POI name
  /// Returns null if no brand is detected
  static String? extractBrand(String poiName) {
    // Normalize the name for comparison
    final normalizedName = poiName.toLowerCase().trim();
    
    // Check against known brands (case-insensitive)
    for (final brand in _knownBrands) {
      if (normalizedName.contains(brand.toLowerCase())) {
        return brand;
      }
    }
    
    // Fallback: use first word as brand (for unknown brands)
    // This handles cases like "REWE City" or "Lidl Markt"
    final firstWord = poiName.split(RegExp(r'[\s\-,]')).first.trim();
    if (firstWord.isNotEmpty && firstWord.length >= 3) {
      return _capitalizeFirst(firstWord);
    }
    
    return null;
  }

  /// Check if a POI matches a given brand name
  static bool doesPoiMatchBrand(POI poi, String brandName) {
    final extractedBrand = extractBrand(poi.name);
    if (extractedBrand == null) return false;
    
    // Case-insensitive comparison
    return extractedBrand.toLowerCase() == brandName.toLowerCase();
  }

  /// Capitalize first letter of a string
  static String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}
