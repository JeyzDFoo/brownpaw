import 'package:brownpaw/router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? redirect(String location, {required bool signedIn}) =>
      authRedirect(signedIn: signedIn, location: Uri.parse(location));

  group('signed out', () {
    test('home goes to sign-in', () {
      expect(redirect('/', signedIn: false), '/sign-in');
    });

    test('a deep link is remembered for after sign-in', () {
      expect(
        redirect('/runs/chilliwack-tamihi', signedIn: false),
        '/sign-in?from=%2Fruns%2Fchilliwack-tamihi',
      );
    });

    test('sign-in itself is allowed', () {
      expect(redirect('/sign-in', signedIn: false), isNull);
    });
  });

  group('signed in', () {
    test('normal pages are allowed', () {
      expect(redirect('/', signedIn: true), isNull);
      expect(redirect('/logbook', signedIn: true), isNull);
      expect(redirect('/runs/x', signedIn: true), isNull);
    });

    test('sign-in returns to where they were headed', () {
      expect(
        redirect('/sign-in?from=%2Fruns%2Fchilliwack-tamihi', signedIn: true),
        '/runs/chilliwack-tamihi',
      );
    });

    test('sign-in without a destination goes home', () {
      expect(redirect('/sign-in', signedIn: true), '/');
    });

    test('an off-site destination is ignored', () {
      expect(
        redirect('/sign-in?from=https%3A%2F%2Fevil.example', signedIn: true),
        '/',
      );
    });
  });

  test('run paths are URL-safe', () {
    expect(AppRoutes.run('chilliwack-tamihi'), '/runs/chilliwack-tamihi');
    expect(AppRoutes.run('a b/c'), '/runs/a%20b%2Fc');
  });
}
