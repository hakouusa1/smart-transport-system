// API keys are injected at build time via --dart-define.
// Example:
//   flutter run \
//     --dart-define=MAPBOX_TOKEN=pk.eyJ... \
//     --dart-define=SUPABASE_URL=https://xxx.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=eyJ...
//
// To avoid passing these flags every time, create a run configuration in
// your IDE (VS Code: .vscode/launch.json, Android Studio: Run > Edit Config)
// and add the --dart-define entries there.
//
// IMPORTANT: Never commit real values here. The defaultValue must always
// be empty. Real keys belong in .vscode/launch.json (git-ignored) or CI
// environment variables.

const mapboxToken = String.fromEnvironment('MAPBOX_TOKEN', defaultValue: 'pk.eyJ1IjoiaGFrb3UwODgiLCJhIjoiY21tZXgxMTJvMDF5eDJyc2hxY2Y3OW1rOCJ9.v74bMi9y79UmP4ixwsuLJw');
const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://dqtedpkzuppiotbvkxon.supabase.co');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRxdGVkcGt6dXBwaW90YnZreG9uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwMjU4MjgsImV4cCI6MjA5MTYwMTgyOH0.YF_KS_c01L8AgSplYKDr2CBHLGhP6tp7bcApnYlmOcE');

bool get useMapbox => mapboxToken.isNotEmpty;

String get mapTileUrl => useMapbox
    ? 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}@2x?access_token=$mapboxToken'
    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

double get mapTileSize => useMapbox ? 512.0 : 256.0;
double get mapZoomOffset => useMapbox ? -1.0 : 0.0;

String getDirectionsUrl(double startLng, double startLat, double endLng, double endLat, {bool steps = false}) {
  if (useMapbox) {
    final stepsQuery = steps ? '&overview=false&steps=true' : '&overview=full';
    return 'https://api.mapbox.com/directions/v5/mapbox/driving/$startLng,$startLat;$endLng,$endLat?geometries=geojson$stepsQuery&access_token=$mapboxToken';
  } else {
    final stepsQuery = steps ? '&overview=false&steps=true' : '&overview=full';
    return 'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?geometries=geojson$stepsQuery';
  }
}
