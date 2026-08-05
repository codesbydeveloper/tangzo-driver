import 'package:driver/constant/constant.dart';
import 'package:driver/themes/app_them_data.dart';

import 'package:driver/utils/translation_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';

class TermsAndConditionScreen extends StatelessWidget {
  final String? type;

  const TermsAndConditionScreen({super.key, this.type});

  @override
  Widget build(BuildContext context) {
    // final themeChange = Provider.of<DarkThemeProvider>(context);
    return Scaffold(
      backgroundColor: AppThemeData.surface,
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        child: SingleChildScrollView(
          child: ValueListenableBuilder(
              valueListenable: TranslationNotifier.refresh,
              builder: (_, __, ___) {
                return Html(
                  shrinkWrap: true,
                  data: cleanHtml(
                    type == "privacy" ? Constant.privacyPolicy.tr : Constant.termsAndConditions.tr,
                  ),
                  style: {
                    "body": Style(
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      color: AppThemeData.grey900,
                      fontSize: FontSize(14),
                      fontFamily: AppThemeData.medium,
                    ),
                    "p": Style(
                      color: AppThemeData.grey900,
                    ),
                    "li": Style(
                      color: AppThemeData.grey900,
                    ),
                    "h1": Style(
                      color: AppThemeData.grey900,
                    ),
                    "h2": Style(
                      color: AppThemeData.grey900,
                    ),
                    "h3": Style(
                      color: AppThemeData.grey900,
                    ),
                    "a": Style(
                      color: AppThemeData.primary300,
                    ),
                  },
                );
              }),
        ),
      ),
    );
  }

  String cleanHtml(String html) {
    return html

        /// remove style tag
        .replaceAll(
          RegExp(r'<style[^>]*>[\s\S]*?<\/style>'),
          '',
        )

        /// remove script tag
        .replaceAll(
          RegExp(r'<script[^>]*>[\s\S]*?<\/script>'),
          '',
        )

        /// remove inline style=""
        .replaceAll(
          RegExp(r'style="[^"]*"'),
          '',
        )

        /// remove tailwind css variables text
        .replaceAll(
          RegExp(r'--tw-[^;]+;'),
          '',
        )

        /// remove extra font-family css text
        .replaceAll(
          RegExp(r'font-family:[^;]+;'),
          '',
        );
  }
}
