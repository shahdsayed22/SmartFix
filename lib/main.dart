import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'l10n/locale_provider.dart';
import 'providers/notification_provider.dart';
import 'services/auth_service.dart';
import 'screens/auth/splash_screen.dart';

// Firebase web configuration from your Firebase project
const firebaseWebOptions = FirebaseOptions(
  apiKey: 'AIzaSyAwx6A5ByB-WcjTXfdayF4WGbK6R09oM3k',
  authDomain: 'smartfix-469cd.firebaseapp.com',
  projectId: 'smartfix-469cd',
  storageBucket: 'smartfix-469cd.firebasestorage.app',
  messagingSenderId: '770688265663',
  appId: '1:770688265663:android:4e59c2475ab5341b54450a',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(options: firebaseWebOptions);
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    debugPrint(
      'Running without Firebase. Configure your firebase options to enable backend features.',
    );
  }

  runApp(const SmartFixApp());
}

class SmartFixApp extends StatelessWidget {
  const SmartFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..tryAutoLogin()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
            title: 'SmartFix',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            locale: localeProvider.locale,
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            // Arabic-first: force RTL by default, flip to LTR only in English.
            builder: (context, child) {
              return Directionality(
                textDirection: localeProvider.isEn
                    ? TextDirection.ltr
                    : TextDirection.rtl,
                child: child!,
              );
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
