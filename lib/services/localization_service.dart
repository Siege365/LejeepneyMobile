import 'package:flutter/material.dart';

/// Localization service for app-wide translations
/// Provides translations for English, Filipino, and Cebuano
class LocalizationService {
  static const Map<String, Map<String, String>> _translations = {
    // English translations
    'English': {
      // App Info
      'app_name': 'LeJeepney',
      'app_tagline': 'Your Jeepney Companion',
      'welcome_message': 'Welcome to LeJeepney',

      // Navigation
      'home': 'Home',
      'search': 'Search',
      'fare_calculator': 'Fare Calculator',
      'landmarks': 'Landmarks',
      'profile': 'Profile',
      'settings': 'Settings',
      'tickets': 'Tickets',
      'recent_activity': 'Recent Activity',

      // Common Actions
      'get_directions': 'Get Directions',
      'cancel': 'Cancel',
      'save': 'Save',
      'close': 'Close',
      'confirm': 'Confirm',
      'retry': 'Retry',
      'refresh': 'Refresh',
      'clear': 'Clear',
      'done': 'Done',
      'back': 'Back',

      // Settings
      'notifications': 'Notifications',
      'push_notifications': 'Push Notifications',
      'ticket_updates': 'Support Ticket Updates',
      'sound': 'Sound',
      'vibration': 'Vibration',
      'general': 'General',
      'language': 'Language',
      'distance_unit': 'Distance Unit',
      'kilometers': 'Kilometers',
      'miles': 'Miles',
      'privacy': 'Privacy',
      'location_services': 'Location Services',
      'clear_cache': 'Clear Cache',
      'language_set_to': 'Language set to',
      'distances_shown_in': 'Distances shown in',

      // Routes & Directions
      'routes': 'Routes',
      'route_details': 'Route Details',
      'no_routes_found': 'No routes found',
      'calculating_route': 'Calculating route...',
      'from': 'From',
      'to': 'To',
      'fare': 'Fare',
      'distance': 'Distance',
      'duration': 'Duration',
      'transfers': 'Transfers',

      // Landmarks
      'all_categories': 'All',
      'nearby': 'Nearby',
      'how_to_get_there': 'How to get there',

      // Status
      'loading': 'Loading...',
      'no_results': 'No results found',
      'error': 'Error',
      'success': 'Success',

      // About
      'about': 'About',
      'version': 'Version',
      'about_description':
          'LeJeepney is your comprehensive guide to navigating Davao City using public jeepney transportation. Discover optimal routes with real-time navigation, book tickets seamlessly, explore landmarks, and calculate fares accurately. Built for Filipino commuters who need reliable, offline-capable transit assistance.',
      'features': 'Features',
      'development_team': 'Development Team',
      'copyright': '© 2026 LeJeepney',
      'made_with_love': 'Made with ❤️ in the Philippines',
    },

    // Filipino translations
    'Filipino': {
      // App Info
      'app_name': 'LeJeepney',
      'app_tagline': 'Iyong Kasama sa Jeepney',
      'welcome_message': 'Maligayang pagdating sa LeJeepney',

      // Navigation
      'home': 'Home',
      'search': 'Maghanap',
      'fare_calculator': 'Kalkulador ng Pamasahe',
      'landmarks': 'Mga Tanda',
      'profile': 'Profile',
      'settings': 'Mga Setting',
      'tickets': 'Mga Tiket',
      'recent_activity': 'Kamakailang Aktibidad',

      // Common Actions
      'get_directions': 'Kumuha ng Direksyon',
      'cancel': 'Kanselahin',
      'save': 'I-save',
      'close': 'Isara',
      'confirm': 'Kumpirmahin',
      'retry': 'Subukan Muli',
      'refresh': 'I-refresh',
      'clear': 'Burahin',
      'done': 'Tapos',
      'back': 'Bumalik',

      // Settings
      'notifications': 'Mga Notipikasyon',
      'push_notifications': 'Push Notifications',
      'ticket_updates': 'Mga Update sa Ticket',
      'sound': 'Tunog',
      'vibration': 'Vibration',
      'general': 'Pangkalahatan',
      'language': 'Wika',
      'distance_unit': 'Yunit ng Distansya',
      'kilometers': 'Kilometro',
      'miles': 'Milya',
      'privacy': 'Privacy',
      'location_services': 'Mga Serbisyo ng Lokasyon',
      'clear_cache': 'Burahin ang Cache',
      'language_set_to': 'Wika ay naitakda sa',
      'distances_shown_in': 'Mga distansya ay ipinakita sa',

      // Routes & Directions
      'routes': 'Mga Ruta',
      'route_details': 'Detalye ng Ruta',
      'no_routes_found': 'Walang nahanap na ruta',
      'calculating_route': 'Kinakalkula ang ruta...',
      'from': 'Mula sa',
      'to': 'Patungo sa',
      'fare': 'Pamasahe',
      'distance': 'Distansya',
      'duration': 'Tagal',
      'transfers': 'Paglipat',

      // Landmarks
      'all_categories': 'Lahat',
      'nearby': 'Malapit',
      'how_to_get_there': 'Paano makarating doon',

      // Status
      'loading': 'Naglo-load...',
      'no_results': 'Walang nahanap',
      'error': 'May Mali',
      'success': 'Tagumpay',

      // About
      'about': 'Tungkol',
      'version': 'Bersyon',
      'about_description':
          'Ang LeJeepney ay iyong komprehensibong gabay sa pag-navigate sa Davao City gamit ang pampublikong jeepney. Tuklasin ang pinakamahusay na mga ruta, mag-book ng mga tiket, tuklasin ang mga tanda, at kalkulahin ang mga pamasahe nang tumpak. Ginawa para sa mga Filipino commuter.',
      'features': 'Mga Tampok',
      'development_team': 'Koponan ng Pag-develop',
      'copyright': '© 2026 LeJeepney',
      'made_with_love': 'Ginawa ng may ❤️ sa Pilipinas',
    },

    // Cebuano translations
    'Cebuano': {
      // App Info
      'app_name': 'LeJeepney',
      'app_tagline': 'Imong Kauban sa Jeepney',
      'welcome_message': 'Welcome sa LeJeepney',

      // Navigation
      'home': 'Home',
      'search': 'Pangita',
      'fare_calculator': 'Calculator sa Plite',
      'landmarks': 'Mga Landmark',
      'profile': 'Profile',
      'settings': 'Mga Setting',
      'tickets': 'Mga Ticket',
      'recent_activity': 'Bag-ong Kalihokan',

      // Common Actions
      'get_directions': 'Kuha ug Direksyon',
      'cancel': 'Kanselahon',
      'save': 'I-save',
      'close': 'Sirad-i',
      'confirm': 'Kumpirmahon',
      'retry': 'Sulayi Balik',
      'refresh': 'I-refresh',
      'clear': 'Burahin',
      'done': 'Tapos',
      'back': 'Balik',

      // Settings
      'notifications': 'Mga Notification',
      'push_notifications': 'Push Notifications',
      'ticket_updates': 'Mga Update sa Ticket',
      'sound': 'Tunog',
      'vibration': 'Vibration',
      'general': 'Kinatibuk-an',
      'language': 'Pinulongan',
      'distance_unit': 'Yunit sa Distansya',
      'kilometers': 'Kilometro',
      'miles': 'Milya',
      'privacy': 'Privacy',
      'location_services': 'Mga Serbisyo sa Lokasyon',
      'clear_cache': 'Burahin ang Cache',
      'language_set_to': 'Pinulongan gi-set sa',
      'distances_shown_in': 'Mga distansya gipakita sa',

      // Routes & Directions
      'routes': 'Mga Ruta',
      'route_details': 'Detalye sa Ruta',
      'no_routes_found': 'Walay nakit-an nga ruta',
      'calculating_route': 'Gikalkula ang ruta...',
      'from': 'Gikan sa',
      'to': 'Paingon sa',
      'fare': 'Plite',
      'distance': 'Distansya',
      'duration': 'Gidugayon',
      'transfers': 'Paglipat',

      // Landmarks
      'all_categories': 'Tanan',
      'nearby': 'Duol',
      'how_to_get_there': 'Unsaon pag-abot didto',

      // Status
      'loading': 'Nag-load...',
      'no_results': 'Walay nakit-an',
      'error': 'May Sayop',
      'success': 'Malampuson',

      // About
      'about': 'Mahitungod',
      'version': 'Bersyon',
      'about_description':
          'Ang LeJeepney usa ka komprehensibo nga giya sa pag-navigate sa Davao City gamit ang pampublikong jeepney. Diskubreha ang labing maayo nga mga ruta, mag-book ug mga ticket, tukion ang mga landmark, ug kalkulahin ang mga plite nga tukma. Gihimo para sa mga Filipino commuter.',
      'features': 'Mga Feature',
      'development_team': 'Team sa Development',
      'copyright': '© 2026 LeJeepney',
      'made_with_love': 'Gihimo uban ang ❤️ sa Pilipinas',
    },
  };

  /// Get translation for a key in the given language
  static String translate(String key, String language) {
    final languageMap = _translations[language];
    if (languageMap == null) {
      // Fallback to English if language not found
      return _translations['English']?[key] ?? key;
    }
    return languageMap[key] ?? _translations['English']?[key] ?? key;
  }

  /// Get locale for a language string
  static Locale getLocale(String language) {
    switch (language) {
      case 'Filipino':
        return const Locale('fil', 'PH');
      case 'Cebuano':
        return const Locale('ceb', 'PH');
      case 'English':
      default:
        return const Locale('en', 'US');
    }
  }

  /// Get language from locale
  static String getLanguageFromLocale(Locale locale) {
    switch (locale.languageCode) {
      case 'fil':
        return 'Filipino';
      case 'ceb':
        return 'Cebuano';
      case 'en':
      default:
        return 'English';
    }
  }
}

/// Extension to make translations easier to access
extension TranslationExtension on BuildContext {
  String tr(String key) {
    // Get current language from SettingsService
    // This requires importing SettingsService
    // For now, we'll use a default approach
    return LocalizationService.translate(key, 'English');
  }
}
