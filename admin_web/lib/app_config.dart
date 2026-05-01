// API keys are injected at build time via --dart-define.
// Example:
//   flutter run --dart-define=MAPBOX_TOKEN=pk.eyJ...
//
// IMPORTANT: Never commit real values here. The defaultValue must always
// be empty. Real keys belong in .vscode/launch.json (git-ignored) or CI
// environment variables.

const mapboxToken = String.fromEnvironment(
  'MAPBOX_TOKEN',
  defaultValue: 'pk.eyJ1IjoiaGFrb3UwODgiLCJhIjoiY21tZXgxMTJvMDF5eDJyc2hxY2Y3OW1rOCJ9.v74bMi9y79UmP4ixwsuLJw',
);

bool get hasMapbox => mapboxToken.isNotEmpty;
