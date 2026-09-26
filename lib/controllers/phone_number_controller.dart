import 'package:driver/app/auth_screen/otp_screen.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/services/otp_api.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driver/constant/constant.dart';

class PhoneNumberController extends GetxController {
  Rx<TextEditingController> phoneNUmberEditingController =
      TextEditingController().obs;
  Rx<TextEditingController> countryCodeEditingController =
      TextEditingController(text: Constant.defaultCountryCode).obs;
  Rx<TextEditingController> countryISOCodeEditingController =
      TextEditingController(text: Constant.defaultCountryCode).obs;

  Future<void> sendCode() async {
    ShowToastDialog.showLoader("Please wait");

    final rawCountry =
        countryCodeEditingController.value.text.replaceAll('+', '');
    final rawPhone = phoneNUmberEditingController.value.text.trim();
    final fullNumber = '$rawCountry$rawPhone';

    final error = await OtpApi.sendOtp(phoneNumber: fullNumber);

    ShowToastDialog.closeLoader();

    if (error == null) {
      Get.to(const OtpScreen(), arguments: {
        "countryCode": countryCodeEditingController.value.text,
        "countryISOCode": countryISOCodeEditingController.value.text,
        "phoneNumber": rawPhone,
        "fullPhoneNumber": fullNumber,
      });
    } else {
      ShowToastDialog.showToast(error);
    }
  }
}
