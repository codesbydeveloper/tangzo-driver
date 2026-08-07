import 'package:driver/app/auth_screen/login_screen.dart';
import 'package:driver/controllers/on_boarding_controller.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/utils/dark_theme_provider.dart';

import 'package:driver/utils/preferences.dart';
import 'package:driver/widget/translated_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../constant/constant.dart';

class OnBoardingScreen extends StatelessWidget {
  const OnBoardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<OnBoardingController>(
      init: OnBoardingController(),
      builder: (controller) {
        return Scaffold(
          body: controller.isLoading.value
              ? Constant.loader()
              : Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage("assets/images/onbording_bg.png"),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () {
                            Preferences.setBoolean(Preferences.isFinishOnBoardingKey, true);
                            Get.offAll(
                              const LoginScreen(),
                              transition: Transition.fadeIn,
                              duration: const Duration(milliseconds: 450),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                TranslatedText(
                                  "Skip",
                                  style: TextStyle(color: themeChange.getThem() ? AppThemeData.grey800 : AppThemeData.grey800, fontSize: 16, fontFamily: AppThemeData.bold),
                                ),
                                const Icon(Icons.chevron_right)
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 50,
                        ),
                        ClipRRect(
                          borderRadius: BorderRadiusGeometry.circular(10),
                          child: Image.asset(
                            "assets/icons/ic_logo.png",
                            height: 120,
                          ),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        Expanded(
                          child: PageView.builder(
                              controller: controller.pageController,
                              onPageChanged: controller.selectedPageIndex.call,
                              itemCount: controller.onBoardingList.length,
                              itemBuilder: (context, index) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    TranslatedText(
                                      controller.onBoardingList[index].title.toString(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: themeChange.getThem() ? AppThemeData.grey900 : AppThemeData.grey900,
                                        fontSize: 22,
                                        fontFamily: AppThemeData.bold,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    TranslatedText(
                                      controller.onBoardingList[index].description.toString(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: themeChange.getThem() ? AppThemeData.grey600 : AppThemeData.grey600,
                                        fontSize: 16,
                                        fontFamily: AppThemeData.regular,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                );
                              }),
                        ),
                        Expanded(
                          flex: 4,
                          child: Container(
                            transform: Matrix4.translationValues(0, 30, 0),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              switchInCurve: Curves.easeInOut,
                              switchOutCurve: Curves.easeInOut,
                              transitionBuilder: (child, animation) {
                                final offsetAnimation = Tween<Offset>(
                                  begin: const Offset(0.15, 0),
                                  end: Offset.zero,
                                ).animate(animation);
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: offsetAnimation,
                                    child: child,
                                  ),
                                );
                              },
                              child: Image.asset(
                                controller.selectedPageIndex.value == 0
                                    ? "assets/images/image_1.png"
                                    : controller.selectedPageIndex.value == 1
                                        ? "assets/images/image_2.png"
                                        : "assets/images/image_3.png",
                                key: ValueKey(controller.selectedPageIndex.value),
                                fit: BoxFit.fill,
                                width: Responsive.width(60, context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          bottomNavigationBar: InkWell(
            onTap: () {
              if (controller.selectedPageIndex.value == 2) {
                Preferences.setBoolean(Preferences.isFinishOnBoardingKey, true);
                Get.offAll(
                  const LoginScreen(),
                  transition: Transition.fadeIn,
                  duration: const Duration(milliseconds: 450),
                );
              } else {
                controller.pageController.animateToPage(
                  controller.selectedPageIndex.value + 1,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              color: controller.selectedPageIndex.value == 2 ? AppThemeData.driverApp300 : AppThemeData.grey900,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: TranslatedText(
                    controller.selectedPageIndex.value == 2 ? "Get Started".tr : "Next",
                    key: ValueKey(controller.selectedPageIndex.value == 2),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: themeChange.getThem() ? AppThemeData.grey50 : AppThemeData.grey50,
                      fontSize: 16,
                      fontFamily: AppThemeData.medium,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
