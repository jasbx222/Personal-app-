/// Default TCP port of the desktop receiver.
const int kDefaultPort = 53317;

/// mDNS / Bonjour service type advertised by the desktop app.
/// (Written without the trailing dot; Bonsoir/NSD accept this form.)
const String kServiceType = '_phone2pc._tcp';

/// Value of the `app` field in the `/ping` response.
const String kAppId = 'phone2pc';

const String kApiVersion = '1';

/// Maximum accepted size of a `/text` request body (5 MiB).
const int kMaxTextBytes = 5 * 1024 * 1024;

/// Routes exposed by the desktop server.
abstract final class ApiRoutes {
  static const ping = '/ping';
  static const text = '/text';
  static const file = '/file';
  static const history = '/history';
}
