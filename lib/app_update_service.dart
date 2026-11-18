import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  final bool updateAvailable;
  final bool forceUpdate;
  final String message;
  final String installedVersion;
  final String latestVersion;

  const AppUpdateInfo({
    required this.updateAvailable,
    required this.forceUpdate,
    required this.message,
    required this.installedVersion,
    required this.latestVersion,
  });
}

class AppUpdateService {
  static int compareVersions(String a, String b) {
    final partsA = a.split(RegExp(r'[.+]'));
    final partsB = b.split(RegExp(r'[.+]'));

    for (var i = 0; i < 4; i++) {
      final numA = i < partsA.length ? int.tryParse(partsA[i]) ?? 0 : 0;
      final numB = i < partsB.length ? int.tryParse(partsB[i]) ?? 0 : 0;

      if (numA != numB) {
        return numA.compareTo(numB);
      }
    }
    return 0;
  }

  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;

      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 15),
          minimumFetchInterval: const Duration(minutes: 5),
        ),
      );

      await remoteConfig.fetchAndActivate();

      final packageInfo = await PackageInfo.fromPlatform();
      final installedVersion =
          '${packageInfo.version}+${packageInfo.buildNumber}';

      final latestVersion = remoteConfig.getString('latest_version');
      final minimumVersion = remoteConfig.getString('minimum_required_version');
      final forceFlag = remoteConfig.getBool('force_update');

      if (latestVersion.isEmpty || minimumVersion.isEmpty) {
        return null;
      }

      final updateAvailable =
          compareVersions(installedVersion, latestVersion) < 0;

      final belowMinimum =
          compareVersions(installedVersion, minimumVersion) < 0;

      final forceUpdate = belowMinimum || (forceFlag && updateAvailable);

      return AppUpdateInfo(
        updateAvailable: updateAvailable || belowMinimum,
        forceUpdate: forceUpdate,
        message: remoteConfig.getString('update_message'),
        installedVersion: installedVersion,
        latestVersion: latestVersion,
      );
    } catch (error) {
      // A failed fetch should not crash the login screen.
      print('Remote Config update check failed: $error');
      return null;
    }
  }
}
