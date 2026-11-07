{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({config: {canvasKitBaseUrl: 'canvaskit/'}});
if ('serviceWorker' in navigator && location.protocol !== 'file:') {
  navigator.serviceWorker.register('offline.js').catch(console.error);
}
