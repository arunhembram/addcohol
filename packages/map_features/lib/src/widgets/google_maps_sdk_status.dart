import 'google_maps_sdk_status_stub.dart'
    if (dart.library.js_interop) 'google_maps_sdk_status_web.dart';

/// Returns true if Google Maps JavaScript SDK is defined and ready to render
bool isGoogleMapsAvailable() => checkGoogleMapsSdkAvailable();
