import 'dart:io';

import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/utils/preferences.dart';
import 'package:driver/widget/translated_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Google Play prominent disclosure for ACCESS_BACKGROUND_LOCATION (Android only).
/// Must be shown in-app and accepted before enabling background location.
class LocationDisclosureDialog extends StatelessWidget {
  const LocationDisclosureDialog({super.key});

  /// Returns true only after the user taps Accept.
  /// On iOS this always returns true (Play policy does not apply).
  static Future<bool> ensureConsent() async {
    if (!Platform.isAndroid) {
      return true;
    }

    if (Preferences.getBoolean(Preferences.backgroundLocationDisclosureAccepted)) {
      return true;
    }

    // Wait until the navigator/route is fully idle to avoid rebuild recursion.
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;

    if (Get.context == null || (Get.isDialogOpen ?? false)) {
      return false;
    }

    final accepted = await Get.dialog<bool>(
      const LocationDisclosureDialog(),
      barrierDismissible: false,
    );

    if (accepted == true) {
      await Preferences.setBoolean(Preferences.backgroundLocationDisclosureAccepted, true);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_rounded,
              color: AppThemeData.driverApp300,
              size: 56,
            ),
            const SizedBox(height: 16),
            TranslatedText(
              'Location access required',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontFamily: AppThemeData.semiBold,
                color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: Responsive.height(40, context)),
              child: SingleChildScrollView(
                child: TranslatedText(
                  'Tangzo Driver collects location data to enable delivery features even when the app is closed or not in use. This includes assigning nearby delivery requests and sharing your live location with restaurants and customers during active deliveries.\n\nYour location is used only for delivery operations and is not sold for advertising.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: AppThemeData.regular,
                    height: 1.4,
                    color: isDark ? AppThemeData.grey200 : AppThemeData.grey700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => Get.back(result: false),
                    child: Container(
                      height: Responsive.height(5, context),
                      decoration: ShapeDecoration(
                        color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(200),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: TranslatedText(
                        'Deny',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppThemeData.medium,
                          color: isDark ? AppThemeData.grey100 : AppThemeData.grey900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => Get.back(result: true),
                    child: Container(
                      height: Responsive.height(5, context),
                      decoration: ShapeDecoration(
                        color: AppThemeData.driverApp300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(200),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const TranslatedText(
                        'Accept',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppThemeData.medium,
                          color: AppThemeData.grey50,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
