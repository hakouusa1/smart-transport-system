// API keys are injected at build time via --dart-define.
// Example:
//   flutter run --dart-define=MAPBOX_TOKEN=pk.eyJ...
//
// To avoid passing these flags every time, add a run configuration in
// your IDE with the --dart-define entries.
//
// IMPORTANT: Never commit real values here. Rotate the Mapbox token
// if it was previously committed to git.

const mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
