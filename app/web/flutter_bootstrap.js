{{flutter_js}}
{{flutter_build_config}}
// Local prototype: avoid serving an obsolete app after a firmware/app update.
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) build.mainJsPath += '?revision=ble-reconnect-2';
}
_flutter.loader.load();
