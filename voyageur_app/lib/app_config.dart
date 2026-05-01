// API keys are injected at build time via --dart-define.
// Example:
//   flutter run --dart-define=MAPBOX_TOKEN=pk.eyJ...
//
// To avoid passing these flags every time, add a run configuration in
// your IDE with the --dart-define entries.
//
// IMPORTANT: Never commit real values here. The defaultValue must always
// be empty. Real keys belong in .vscode/launch.json (git-ignored) or CI
// environment variables.

const mapboxToken = String.fromEnvironment('MAPBOX_TOKEN', defaultValue: 'pk.eyJ1IjoiaGFrb3UwODgiLCJhIjoiY21tZXgxMTJvMDF5eDJyc2hxY2Y3OW1rOCJ9.v74bMi9y79UmP4ixwsuLJw');
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get useMapbox => mapboxToken.isNotEmpty;

String get mapTileUrl => useMapbox
    ? 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}@2x?access_token=$mapboxToken'
    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

double get mapTileSize => useMapbox ? 512.0 : 256.0;
double get mapZoomOffset => useMapbox ? -1.0 : 0.0;


String getDirectionsUrl(double startLng, double startLat, double endLng, double endLat) {
  if (useMapbox) {
    return 'https://api.mapbox.com/directions/v5/mapbox/driving/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=geojson&access_token=$mapboxToken';
  } else {
    return 'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=geojson';
  }
}
