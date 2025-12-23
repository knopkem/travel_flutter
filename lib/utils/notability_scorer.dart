/// Calculate notability score for a POI based on its attributes
/// Returns a score between 0 and 100, where higher is more notable
int calculateNotabilityScore({
  bool hasWikidata = false,
  bool hasWikipedia = false,
  bool hasWebsite = false,
  bool hasUNESCO = false,
  bool hasHighVisitorCount = false,
  bool hasOpeningHours = false,
  bool hasHistoricSignificance = false,
  bool hasImage = false,
}) {
  int score = 50; // Base score

  // Major indicators
  if (hasWikidata) score += 20;
  if (hasWikipedia) score += 15;
  if (hasUNESCO) score += 30;
  if (hasHighVisitorCount) score += 10;
  if (hasHistoricSignificance) score += 12;

  // Minor indicators
  if (hasWebsite) score += 5;
  if (hasOpeningHours) score += 3;
  if (hasImage) score += 5;

  // Clamp to valid range
  return score.clamp(0, 100);
}
