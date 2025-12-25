/// Maps country names to ISO 639-1 language codes for API localization
///
/// Used to fetch content in the local language when "Use Local Content" setting is enabled.
/// Falls back to English ("en") for unmapped countries.
class CountryLanguageMap {
  static const Map<String, String> _countryToLanguage = {
    // European Countries
    'Germany': 'de',
    'Austria': 'de',
    'Switzerland': 'de',
    'France': 'fr',
    'Spain': 'es',
    'Italy': 'it',
    'Portugal': 'pt',
    'Netherlands': 'nl',
    'Belgium': 'nl',
    'Poland': 'pl',
    'Czech Republic': 'cs',
    'Slovakia': 'sk',
    'Hungary': 'hu',
    'Romania': 'ro',
    'Bulgaria': 'bg',
    'Greece': 'el',
    'Denmark': 'da',
    'Sweden': 'sv',
    'Norway': 'no',
    'Finland': 'fi',
    'Iceland': 'is',
    'Russia': 'ru',
    'Ukraine': 'uk',
    'Belarus': 'be',
    'Croatia': 'hr',
    'Serbia': 'sr',
    'Slovenia': 'sl',
    'Lithuania': 'lt',
    'Latvia': 'lv',
    'Estonia': 'et',
    'Turkey': 'tr',
    
    // Asian Countries
    'Japan': 'ja',
    'China': 'zh',
    'South Korea': 'ko',
    'Korea': 'ko',
    'Taiwan': 'zh',
    'Thailand': 'th',
    'Vietnam': 'vi',
    'Indonesia': 'id',
    'Malaysia': 'ms',
    'Philippines': 'fil',
    'India': 'hi',
    'Pakistan': 'ur',
    'Bangladesh': 'bn',
    'Iran': 'fa',
    'Iraq': 'ar',
    'Saudi Arabia': 'ar',
    'United Arab Emirates': 'ar',
    'Israel': 'he',
    
    // American Countries
    'United States': 'en',
    'United Kingdom': 'en',
    'Canada': 'en',
    'Australia': 'en',
    'New Zealand': 'en',
    'Ireland': 'en',
    'Mexico': 'es',
    'Argentina': 'es',
    'Chile': 'es',
    'Colombia': 'es',
    'Peru': 'es',
    'Venezuela': 'es',
    'Brazil': 'pt',
    
    // African Countries
    'South Africa': 'af',
    'Egypt': 'ar',
    'Morocco': 'ar',
    'Algeria': 'ar',
    'Tunisia': 'ar',
    'Kenya': 'sw',
    'Tanzania': 'sw',
  };

  /// Get the language code for a given country name
  /// 
  /// Returns the ISO 639-1 language code (e.g., "de" for Germany)
  /// Falls back to "en" for unmapped or null countries
  static String getLanguageCode(String? country) {
    if (country == null || country.isEmpty) {
      return 'en';
    }
    
    return _countryToLanguage[country] ?? 'en';
  }
}
