# Feature Specification: City POI Discovery & Detail View
*Path: kitty-specs/002-city-poi-discovery/spec.md*

**Feature Branch**: `002-city-poi-discovery`  
**Created**: 2025-12-18  
**Status**: Draft  
**Input**: User description: "Rework city selection to single active city model. Display full Wikipedia article content instead of summaries. Add POI discovery: fetch nearby points of interest from OpenStreetMap/Overpass API, Wikipedia Geosearch, and Wikidata when city is selected. Filter duplicate POIs across sources. Enable users to view detailed information for each POI."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Single City Selection & Full Content (Priority: P1)

Users can search for and select one city at a time, viewing the complete Wikipedia article content for that city rather than just a summary. This replaces the previous multi-city selection model with a focused single-city experience.

**Why this priority**: This is foundational - it establishes the core navigation pattern that all other features depend on. Without single-city selection, POI discovery cannot function.

**Independent Test**: Can be fully tested by searching for "Paris", selecting it, and verifying that: (1) only one city is active at a time, (2) selecting a new city replaces the previous one, and (3) the full Wikipedia article content is displayed instead of just the introductory paragraph.

**Acceptance Scenarios**:

1. **Given** I have no city selected, **When** I search for "Berlin" and select it, **Then** Berlin becomes the active city and full Wikipedia content is displayed
2. **Given** I have "Paris" selected, **When** I search for and select "Tokyo", **Then** Paris is deselected, Tokyo becomes the active city, and Tokyo's full Wikipedia content is displayed
3. **Given** I have "London" selected, **When** I view the city details, **Then** I see the complete Wikipedia article including all sections (history, geography, culture, etc.) not just the introduction
4. **Given** Wikipedia has a long article for a city, **When** I view the city details, **Then** the full content is scrollable and all sections are accessible

---

### User Story 2 - POI Discovery for Selected City (Priority: P1)

When a city is selected, the system automatically discovers and displays nearby points of interest (landmarks, museums, monuments, attractions) by querying multiple data sources and presenting a unified, deduplicated list.

**Why this priority**: This is the core new feature that provides immediate value - helping users discover what to visit in their selected city. It's independently valuable even without detailed POI information.

**Independent Test**: Can be fully tested by selecting "Rome" and verifying that: (1) POIs automatically appear after city selection, (2) the POI list includes diverse sources (OpenStreetMap, Wikipedia, Wikidata), (3) duplicate POIs are filtered out, and (4) the list is relevant to Rome's location.

**Acceptance Scenarios**:

1. **Given** I select "Rome", **When** the city loads, **Then** a list of nearby POIs appears automatically showing landmarks like "Colosseum", "Vatican Museums", "Trevi Fountain"
2. **Given** I select "Paris", **When** POI discovery completes, **Then** I see famous sites like "Eiffel Tower", "Louvre Museum", "Notre-Dame Cathedral" with no duplicates even though they appear in multiple data sources
3. **Given** I select a small town with few POIs, **When** POI discovery runs, **Then** I see available POIs or a message indicating limited attractions in the area
4. **Given** POI data is loading, **When** I'm viewing the city, **Then** I see a loading indicator until POIs are ready
5. **Given** I switch from "London" to "New York", **When** the new city loads, **Then** the POI list updates to show New York attractions, not London's

---

### User Story 3 - View Detailed POI Information (Priority: P2)

Users can select any POI from the list to view comprehensive information about that sight, including descriptions, images, and relevant details fetched from appropriate data sources.

**Why this priority**: This completes the discovery journey - users find interesting POIs and can learn more about them. While valuable, users still get benefit from just seeing the POI list (P1).

**Independent Test**: Can be fully tested by selecting "Rome", clicking on "Colosseum" from the POI list, and verifying that: (1) detailed information appears, (2) content is fetched from appropriate sources, (3) images are displayed if available, and (4) the user can navigate back to the POI list.

**Acceptance Scenarios**:

1. **Given** I'm viewing Rome's POI list, **When** I click on "Colosseum", **Then** I see a detailed view with full description, history, images, and other relevant information
2. **Given** I'm viewing POI details for "Eiffel Tower", **When** I read the content, **Then** I see comprehensive information including construction details, visiting information, and historical context
3. **Given** I'm viewing a POI detail page, **When** I want to return to the POI list, **Then** I can navigate back easily and the POI list is preserved
4. **Given** a POI has limited information available, **When** I view its details, **Then** I see whatever information is available without errors or empty sections
5. **Given** I'm viewing "Louvre Museum" details, **When** I decide to explore another sight, **Then** I can return to the POI list and select a different POI

---

### User Story 4 - Search and Replace City (Priority: P3)

Users can search for a different city at any time, replacing the current selection and triggering a complete refresh of city content and POIs.

**Why this priority**: This is polish for the navigation experience - users can explore multiple cities efficiently. The core functionality works without this, but it improves usability.

**Independent Test**: Can be fully tested by selecting "Madrid", viewing its POIs, then searching for "Barcelona", and verifying the complete transition happens smoothly.

**Acceptance Scenarios**:

1. **Given** I'm viewing "Madrid" with its POIs, **When** I search for and select "Barcelona", **Then** Madrid is deselected, Barcelona becomes active, city content updates, and Barcelona's POIs load automatically
2. **Given** I'm viewing a POI detail page in "Tokyo", **When** I search for and select "Kyoto", **Then** the interface returns to city view, Tokyo is deselected, Kyoto becomes active, and Kyoto's POIs begin loading
3. **Given** I have "Paris" selected with loaded POIs, **When** I start typing a search for "Lyon", **Then** the search interface is accessible without losing the Paris context until I make a selection

---

### Edge Cases

- What happens when a city has no nearby POIs in any of the data sources?
  - Display a friendly message: "No major attractions found nearby. Try selecting a larger city."
  
- How does the system handle POI data source failures?
  - If one source fails (e.g., OpenStreetMap timeout), continue with other sources
  - If all sources fail, show error message with retry option
  - Never show partial/corrupt POI data
  
- What happens when Wikipedia article content is unavailable for a city?
  - Fall back to showing the summary/introduction (previous behavior)
  - Display message: "Limited information available for this location"
  
- How does the system deduplicate POIs with slightly different names?
  - Use coordinate-based proximity matching (POIs within 50 meters considered duplicates)
  - Prefer Wikipedia entries over OpenStreetMap when duplicates detected
  - Use name similarity scoring for fuzzy matching (e.g., "Eiffel Tower" vs "The Eiffel Tower")
  
- What happens when users quickly switch between cities?
  - Cancel in-flight POI requests for previous city
  - Always show content for the most recently selected city
  - Queue city switches to prevent race conditions
  
- How does the system handle cities with hundreds of POIs?
  - Limit initial display to top 20-30 most notable POIs
  - Sort by importance/popularity (derived from Wikipedia page views or Wikidata notability)
  - Provide "load more" option if additional POIs are available
  
- What happens when a user selects a POI that becomes unavailable?
  - Show cached information if available
  - Display error message with option to retry
  - Allow navigation back to POI list

## Requirements *(mandatory)*

### Functional Requirements

#### City Selection & Content

- **FR-001**: System MUST allow only one city to be selected at any given time
- **FR-002**: System MUST replace the currently selected city when a new city is chosen
- **FR-003**: System MUST fetch and display the complete Wikipedia article content for the selected city, not just the introduction/summary
- **FR-004**: System MUST handle long Wikipedia articles by providing scrollable content with all sections accessible
- **FR-005**: System MUST preserve the search functionality from the previous feature to find cities by name

#### POI Discovery

- **FR-006**: System MUST automatically fetch nearby POIs when a city is selected
- **FR-007**: System MUST query OpenStreetMap/Overpass API for POI data (landmarks, museums, monuments, tourist attractions)
- **FR-008**: System MUST query Wikipedia Geosearch API for locations with Wikipedia articles near the city coordinates
- **FR-009**: System MUST query Wikidata for notable places near the city coordinates
- **FR-010**: System MUST deduplicate POIs found across multiple data sources using coordinate proximity (within 50 meters) and name similarity matching
- **FR-011**: System MUST present a unified list of POIs after deduplication, showing each unique place once
- **FR-012**: System MUST display POIs sorted by relevance or notability (derived from data source rankings)
- **FR-013**: System MUST define "nearby" as within 10 kilometers of the city center coordinates for POI searches
- **FR-014**: System MUST show a loading indicator while POI discovery is in progress
- **FR-015**: System MUST handle empty POI results gracefully with an appropriate message

#### POI Details

- **FR-016**: System MUST allow users to select any POI from the list to view detailed information
- **FR-017**: System MUST fetch comprehensive information about the selected POI from appropriate data sources
- **FR-018**: System MUST display POI details including name, description, images (if available), and other relevant information
- **FR-019**: System MUST fetch POI information from Wikipedia if a Wikipedia article exists for that POI
- **FR-020**: System MUST fetch POI information from Wikidata for structured data about the POI
- **FR-021**: System MUST merge information from multiple sources to create a comprehensive POI detail view
- **FR-022**: System MUST provide navigation to return from POI details to the POI list
- **FR-023**: System MUST preserve the POI list state when navigating between POI details and list view

#### Error Handling & Performance

- **FR-024**: System MUST handle data source failures gracefully by continuing with available sources
- **FR-025**: System MUST provide retry functionality when all data sources fail
- **FR-026**: System MUST cancel in-flight requests when a user switches to a different city
- **FR-027**: System MUST handle rate limiting from external APIs (OpenStreetMap, Wikipedia, Wikidata)
- **FR-028**: System MUST cache fetched data to minimize redundant API calls when users revisit the same city or POI
- **FR-029**: System MUST validate API responses and handle malformed or incomplete data without crashing
- **FR-030**: System MUST provide timeout handling for slow API responses (10 seconds maximum per source)

### Key Entities

- **City**: A geographic location selected by the user for exploration
  - Attributes: name, country, coordinates (latitude/longitude), Wikipedia article URL, full article content
  - Only one active city at a time
  - Replaced when a new city is selected

- **Point of Interest (POI)**: A notable place, attraction, landmark, or sight near the selected city
  - Attributes: name, type (museum, landmark, monument, etc.), coordinates, distance from city center, source(s) that provided the data, description, images
  - Multiple POIs associated with the active city
  - Unified and deduplicated across multiple data sources
  - Sorted by relevance/notability

- **POI Source**: Information about which external API provided data for a POI
  - Used for deduplication logic
  - Helps prioritize information quality (Wikipedia preferred over OpenStreetMap for descriptions)

- **Data Source Response**: Raw API responses from OpenStreetMap, Wikipedia Geosearch, and Wikidata
  - Temporary entities used during POI discovery
  - Transformed and merged into POI entities
  - Discarded after deduplication

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can select a city and view its full Wikipedia content in under 3 seconds on a standard internet connection
- **SC-002**: POI discovery completes and displays results within 5 seconds of city selection for cities with under 100 POIs
- **SC-003**: The system successfully deduplicates at least 90% of duplicate POIs from multiple data sources based on coordinate proximity
- **SC-004**: Users can view detailed information for any POI in under 2 seconds after selection
- **SC-005**: The system handles switching between cities smoothly with no UI freezes or crashes
- **SC-006**: At least 80% of searched cities return 5 or more POIs from combined data sources
- **SC-007**: Full Wikipedia article content loads completely without truncation for 95% of cities
- **SC-008**: Users can navigate from city → POI list → POI details → POI list → city without any loss of context or state
- **SC-009**: The system gracefully handles API failures with fallback to available sources in 100% of cases
- **SC-010**: Users report improved satisfaction with detailed content compared to summary-only view (measured through user testing or feedback)

## Assumptions

1. **API Availability**: OpenStreetMap/Overpass API, Wikipedia Geosearch API, and Wikidata are assumed to be available and free to use without API keys
2. **Rate Limits**: Each API has rate limiting (approximately 1 request per second for OpenStreetMap, reasonable limits for Wikipedia/Wikidata); the system will respect these limits
3. **Data Quality**: POI data from multiple sources will have sufficient overlap to enable meaningful deduplication
4. **Internet Connectivity**: Users are assumed to have active internet connection; offline functionality is not included in this feature
5. **Wikipedia Content**: Full Wikipedia articles are available via the Wikipedia API (same endpoint, different parameter or parsing strategy)
6. **Coordinate Accuracy**: City coordinates from the geocoding API are accurate enough for POI proximity searches (within 1km)
7. **POI Radius**: 10km radius around city center is sufficient to capture major attractions for most cities
8. **Deduplication Threshold**: 50 meters is an appropriate distance threshold for considering two POIs as duplicates
9. **Mobile Data Usage**: Users are aware that fetching full Wikipedia content and multiple POI sources will consume more data than the summary-only feature
10. **Language**: All content will be fetched in English; multi-language support is not included

## Out of Scope

- **Offline POI Access**: Caching full POI databases for offline use
- **User-Generated POIs**: Users cannot add or suggest new POIs
- **POI Reviews/Ratings**: No integration with review platforms like TripAdvisor or Google Reviews  
- **Navigation/Directions**: No integration with mapping services for directions to POIs
- **Booking Integration**: No hotel, restaurant, or ticket booking functionality
- **Multi-Language Support**: Content is only fetched in English
- **POI Categories/Filtering**: No ability to filter POIs by type (museums only, outdoor only, etc.)
- **Save Favorite POIs**: No functionality to bookmark or save favorite attractions
- **Share POIs**: No social sharing features for POIs
- **Opening Hours/Pricing**: No real-time information about POI opening hours or admission prices
- **Nearby Amenities**: No search for restaurants, hotels, or services near POIs
- **Route Planning**: No multi-POI itinerary or route optimization
- **Augmented Reality**: No AR features for POI discovery
- **Historical Visit Tracking**: No record of previously viewed cities or POIs
