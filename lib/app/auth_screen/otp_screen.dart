import 'dart:io';

import 'package:driver/app/auth_screen/login_screen.dart';
import 'package:driver/app/auth_screen/signup_screen.dart';
import 'package:driver/app/dash_board_screen/dash_board_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/otp_controller.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/utils/dark_theme_provider.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:driver/utils/translation_notifier.dart';
import 'package:driver/widget/translated_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

class OtpScreen extends StatelessWidget {
  const OtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<OtpController>(
        init: OtpController(),
        builder: (controller) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: themeChange.getThem() ? AppThemeData.surfaceDark : AppThemeData.surface,
            ),
            body: controller.isLoading.value
                ? Constant.loader()
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TranslatedText(
                            "Verify Your Mobile Number",
                            style: TextStyle(color: themeChange.getThem() ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 22, fontFamily: AppThemeData.semiBold),
                          ),
                          TranslatedText(
                            "Enter the OTP sent to your mobile number to verify and secure your account.",
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              color: themeChange.getThem() ? AppThemeData.grey200 : AppThemeData.grey700,
                              fontFamily: AppThemeData.regular,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(
                            height: 60,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: MaterialPinField(
                              length: 6,
                              keyboardType: TextInputType.number,
                              enableAutofill: true,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              hintCharacter: "-",
                              pinController: controller.otpController.value,
                              theme: MaterialPinTheme(
                                cellSize: const Size(50, 50),
                                shape: MaterialPinShape.outlined,
                                borderRadius: BorderRadius.circular(10),

                                // Text Style
                                textStyle: TextStyle(
                                  fontFamily: AppThemeData.regular,
                                  color: themeChange.getThem() ? AppThemeData.grey50 : AppThemeData.grey900,
                                ),

                                // Hint Style
                                hintStyle: TextStyle(
                                  fontFamily: AppThemeData.regular,
                                  color: themeChange.getThem() ? AppThemeData.grey50 : AppThemeData.grey900,
                                ),

                                // Fill (same as enableActiveFill: true)
                                fillColor: themeChange.getThem() ? AppThemeData.grey900 : AppThemeData.grey50,

                                // Border colors (matching your old inactive/selected)
                                borderColor: themeChange.getThem() ? AppThemeData.grey900 : AppThemeData.grey50,

                                focusedBorderColor: AppThemeData.secondary300,

                                errorColor: themeChange.getThem() ? AppThemeData.grey600 : AppThemeData.grey300,

                                cursorColor: AppThemeData.secondary300,
                              ),
                              onChanged: (value) {},
                              onCompleted: (pin) async {
                                // Handle OTP complete
                              },
                            ),
                          ),
                          const SizedBox(
                            height: 50,
                          ),
                          ValueListenableBuilder(
                              valueListenable: TranslationNotifier.refresh,
                              builder: (_, __, ___) {
                                return Text.rich(
                                  textAlign: TextAlign.center,
                                  TextSpan(
                                    text: "${'Did’t receive any code? '} ".tr,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      fontFamily: AppThemeData.medium,
                                      color: themeChange.getThem() ? AppThemeData.grey100 : AppThemeData.grey800,
                                    ),
                                    children: <TextSpan>[
                                      TextSpan(
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () {
                                            controller.otpController.value.clear();
                                            controller.sendOTP();
                                          },
                                        text: 'Send Again'.tr,
                                        style: TextStyle(
                                            color: themeChange.getThem() ? AppThemeData.driverApp300 : AppThemeData.driverApp300,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                            fontFamily: AppThemeData.medium,
                                            decoration: TextDecoration.underline,
                                            decorationColor: AppThemeData.driverApp300),
                                      ),
                                    ],
                                  ),
                                );
                              })
                        ],
                      ),
                    ),
                  ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: Platform.isAndroid ? 10 : 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ValueListenableBuilder(
                          valueListenable: TranslationNotifier.refresh,
                          builder: (_, __, ___) {
                            return Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                      text: 'Already Have an account?'.tr,
                                      style: TextStyle(
                                        color: themeChange.getThem() ? AppThemeData.grey50 : AppThemeData.grey900,
                                        fontFamily: AppThemeData.medium,
                                        fontWeight: FontWeight.w500,
                                      )),
                                  const WidgetSpan(
                                      child: SizedBox(
                                    width: 10,
                                  )),
                                  TextSpan(
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () {
                                          Get.offAll(const LoginScreen());
                                        },
                                      text: 'Log in'.tr,
                                      style: const TextStyle(
                                          color: AppThemeData.secondary300,
                                          fontFamily: AppThemeData.medium,
                                          fontWeight: FontWeight.w500,
                                          decoration: TextDecoration.underline,
                                          decorationColor: AppThemeData.secondary300)),
                                ],
                              ),
                            );
                          }),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () async {
                    if (controller.otpController.value.text.length == 6) {
                      ShowToastDialog.showLoader("Verify otp");

                      PhoneAuthCredential credential = PhoneAuthProvider.credential(verificationId: controller.verificationId.value, smsCode: controller.otpController.value.text);
                      String? fcmToken = await NotificationService.getToken();
                      await FirebaseAuth.instance.signInWithCredential(credential).then((value) async {
                        if (value.additionalUserInfo!.isNewUser) {
                          UserModel userModel = UserModel();
                          userModel.id = value.user!.uid;
                          userModel.countryCode = controller.countryCode.value;
                          userModel.countryISOCode = controller.countryCode.value;
                          userModel.phoneNumber = controller.phoneNumber.value;
                          userModel.fcmToken = fcmToken;
                          userModel.provider = 'phone';

                          ShowToastDialog.closeLoader();
                          Get.off(const SignupScreen(), arguments: {
                            "userModel": userModel,
                            "type": "mobileNumber",
                          });
                        } else {
                          await FireStoreUtils.userExistOrNot(value.user!.uid).then((userExit) async {
                            ShowToastDialog.closeLoader();
                            if (userExit == true) {
                              UserModel? userModel = await FireStoreUtils.getUserProfile(value.user!.uid);
                              if (userModel!.role == Constant.userRoleDriver) {
                                if (userModel.active == true) {
                                  userModel.fcmToken = await NotificationService.getToken();
                                  await FireStoreUtils.updateUser(userModel);
                                  Get.offAll(const DashBoardScreen());
                                } else {
                                  ShowToastDialog.showToast("This user is disable please contact to administrator");
                                  await FirebaseAuth.instance.signOut();
                                  Get.offAll(const LoginScreen());
                                }
                              } else {
                                await FirebaseAuth.instance.signOut();
                                Get.offAll(const LoginScreen());
                                ShowToastDialog.showToast("Account already created in other application. You are not able login this application.");
                              }
                            } else {
                              UserModel userModel = UserModel();
                              userModel.id = value.user!.uid;
                              userModel.countryCode = controller.countryCode.value;
                              userModel.countryISOCode = controller.countryISOCode.value;
                              userModel.phoneNumber = controller.phoneNumber.value;
                              userModel.fcmToken = fcmToken;
                              userModel.provider = 'phone';

                              Get.off(const SignupScreen(), arguments: {
                                "userModel": userModel,
                                "type": "mobileNumber",
                              });
                            }
                          });
                        }
                      }).catchError((error) {
                        ShowToastDialog.closeLoader();
                        ShowToastDialog.showToast("Invalid Code");
                      });
                    } else {
                      ShowToastDialog.showToast("Enter Valid otp");
                    }
                  },
                  child: Container(
                    color: AppThemeData.driverApp300,
                    width: Responsive.width(100, context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: TranslatedText(
                        "Send Code",
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
              ],
            ),
          );
        });
  }
}
