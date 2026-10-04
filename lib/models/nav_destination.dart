/// A top-level screen reachable from the main navigation shell, addressed
/// by meaning rather than by tab position — the bottom tab bar's layout is
/// configurable, so "departures" might be tab index 1, or not a tab at all.
///
/// Kept in its own file (rather than alongside `MainNavigationScreen`, which
/// owns the switching logic) since `MapScreen` also needs it to request a
/// destination, and `main_navigation_screen.dart` already imports
/// `map_screen.dart` — putting it there would create a cycle.
enum NavDestination { main, departures, savedTrips, settings }
