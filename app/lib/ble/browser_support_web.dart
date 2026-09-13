import 'dart:js_interop';

@JS('navigator.bluetooth')
external JSAny? get _bluetooth;
bool get browserSupportsBle => _bluetooth != null;
