import 'package:url_launcher/url_launcher.dart';

class RealPlayService {
  static const String realPlayUrl =
      'https://spinnerlog.com/register?src=f91e2ef0-0998-473d-85d4-4e693043cdce&utm_source=milkyway_app&utm_medium=banner&utm_campaign=return_traffic';

  /// Open external real money registration URL in mobile browser.
  static Future<bool> openRealPlay() async {
    final uri = Uri.parse(realPlayUrl);
    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
