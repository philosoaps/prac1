import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/tasks/v1.dart' as tasks;
import 'package:googleapis_auth/googleapis_auth.dart' as gapis;

class GoogleAuthService {
  static const String serverClientId =
      '474219026009-u6504gfv7i29e0a8akde37ptcq2nh7lf.apps.googleusercontent.com';

  static const List<String> scopes = [
    calendar.CalendarApi.calendarEventsScope,
    tasks.TasksApi.tasksScope,
    drive.DriveApi.driveAppdataScope,
  ];

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: serverClientId,
    scopes: scopes,
  );

  static GoogleSignIn get instance => _googleSignIn;

  static Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (_) {
      return null;
    }
  }

  static Future<GoogleSignInAccount?> signIn() async {
    return await _googleSignIn.signIn();
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  static Future<gapis.AuthClient?> getAuthClient() async {
    return await _googleSignIn.authenticatedClient();
  }
}
