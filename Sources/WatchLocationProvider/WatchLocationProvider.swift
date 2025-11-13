@_exported import pawWatchFeature

// This target now simply re-exports the shared WatchLocationProvider implementation
// from the pawWatchFeature Swift package so downstream modules can `import
// WatchLocationProvider` without changing source.
