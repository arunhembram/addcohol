import 'dart:js_interop';

@JS('eval')
external JSAny? _eval(String code);

bool checkGoogleMapsSdkAvailable() {
  try {
    final res = _eval(
      'Boolean(typeof window !== "undefined" && window.google && window.google.maps && window.googleMapsAuthFailed !== true)',
    );
    return (res as JSBoolean?)?.toDart ?? false;
  } catch (_) {
    return false;
  }
}
