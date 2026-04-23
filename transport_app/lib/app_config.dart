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
// IMPORTANT: Never commit real values here. Rotate the Mapbox token and
// Supabase anon key if they were previously committed to git.

const mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
