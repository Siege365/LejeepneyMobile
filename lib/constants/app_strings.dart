// App Strings - All text strings for the app
class AppStrings {
  AppStrings._();

  // ========== APP INFO ==========
  static const String appName = 'Lejeepney';
  static const String appTagline = 'Your Jeepney Companion';

  // ========== AUTH ==========
  static const String login = 'Login';
  static const String signUp = 'Sign Up';
  static const String logout = 'Logout';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String forgotPassword = 'Forgot Password?';
  static const String fullName = 'Full Name';
  static const String phoneNumber = 'Phone Number';
  static const String createAccount = 'Create Account';
  static const String alreadyHaveAccount = 'Already have an account?';
  static const String dontHaveAccount = "Don't have an account?";
  static const String orContinueWith = 'Or continue with';
  static const String google = 'Google';
  static const String facebook = 'Facebook';

  // ========== NAVIGATION ==========
  static const String home = 'Home';
  static const String search = 'Search';
  static const String fareCalculator = 'Fare Calculator';
  static const String landmarks = 'Landmarks';
  static const String profile = 'Profile';
  static const String settings = 'Settings';

  // ========== FARE CALCULATOR ==========
  static const String calculateFare = 'Calculate Fare';
  static const String estimatedFare = 'Estimated Fare';
  static const String distance = 'Distance';
  static const String pointA = 'Point A';
  static const String pointB = 'Point B';
  static const String noRouteSelected = 'No Route Selected';
  static const String useMapCalculator = 'Use Map Calculator';
  static const String suggestedRoutes = 'Suggested Routes';
  static const String directRoutes = 'Direct Routes';
  static const String transferRoutes = 'Transfer Routes';
  static const String baseFare = 'Base Fare';
  static const String additionalFare = 'Additional Fare';

  // ========== ROUTES ==========
  static const String routes = 'Routes';
  static const String viewRoute = 'View Route';
  static const String routeDetails = 'Route Details';
  static const String allRoutes = 'All Routes';
  static const String terminal = 'Terminal';
  static const String destination = 'Destination';
  static const String fare = 'Fare';
  static const String available = 'Available';
  static const String unavailable = 'Unavailable';

  // ========== MAP ==========
  static const String myLocation = 'My Location';
  static const String searchLocation = 'Search location...';
  static const String getDirections = 'Get Directions';
  static const String tapToSelectLocation = 'Tap on map to select location';
  static const String gettingLocation = 'Getting your location...';
  static const String locationNotFound = 'Location not found';

  // ========== LANDMARKS ==========
  static const String allCategories = 'All';
  static const String featured = 'Featured';
  static const String nearby = 'Nearby';
  static const String howToGetThere = 'How to get there';

  // ========== COMMON ACTIONS ==========
  static const String submit = 'Submit';
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String close = 'Close';
  static const String confirm = 'Confirm';
  static const String retry = 'Retry';
  static const String refresh = 'Refresh';
  static const String viewAll = 'View All';
  static const String seeMore = 'See More';
  static const String done = 'Done';
  static const String next = 'Next';
  static const String back = 'Back';
  static const String skip = 'Skip';
  static const String clear = 'Clear';

  // ========== STATUS ==========
  static const String loading = 'Loading...';
  static const String success = 'Success';
  static const String error = 'Error';
  static const String noResults = 'No results found';
  static const String noData = 'No data available';
  static const String empty = 'Nothing here yet';

  // ========== ERROR MESSAGES ==========
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork =
      'No internet connection. Please check your network.';
  static const String errorTimeout = 'Request timed out. Please try again.';
  static const String errorInvalidEmail = 'Please enter a valid email address.';
  static const String errorInvalidPassword =
      'Password must be at least 8 characters.';
  static const String errorPasswordMismatch = 'Passwords do not match.';
  static const String errorEmptyField = 'This field cannot be empty.';
  static const String errorInvalidPhone = 'Please enter a valid phone number.';
  static const String errorUnauthorized = 'Please login to continue.';
  static const String errorForbidden =
      'You do not have permission for this action.';
  static const String errorNotFound = 'The requested resource was not found.';
  static const String errorLocationPermission =
      'Location permission is required.';
  static const String errorLocationDisabled =
      'Please enable location services.';

  // ========== SUCCESS MESSAGES ==========
  static const String successLogin = 'Welcome back!';
  static const String successSignUp = 'Account created successfully!';
  static const String successLogout = 'Logged out successfully.';
  static const String successSaved = 'Changes saved successfully.';
  static const String successDeleted = 'Deleted successfully.';

  // ========== DISCLAIMERS ==========
  static const String fareDisclaimer =
      'Please note: This fare estimate is based on calculated road distance and is accurate most of the time. '
      'However, the actual fare may vary depending on your exact drop-off point along the route.';
}
