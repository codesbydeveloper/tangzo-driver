import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/app/auth_screen/login_screen.dart';
import 'package:driver/app/dash_board_screen/dash_board_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/zone_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SignupController extends GetxController {
  Rx<TextEditingController> firstNameEditingController = TextEditingController().obs;
  Rx<TextEditingController> lastNameEditingController = TextEditingController().obs;
  Rx<TextEditingController> emailEditingController = TextEditingController().obs;
  Rx<TextEditingController> phoneNUmberEditingController = TextEditingController().obs;
  Rx<TextEditingController> countryCodeEditingController = TextEditingController(text: Constant.defaultCountryCode).obs;
  Rx<TextEditingController> countryISOCodeEditingController = TextEditingController(text: Constant.defaultCountryCode).obs;
  Rx<TextEditingController> passwordEditingController = TextEditingController().obs;
  Rx<TextEditingController> conformPasswordEditingController = TextEditingController().obs;

  RxBool passwordVisible = true.obs;
  RxBool conformPasswordVisible = true.obs;

  RxString type = "".obs;

  Rx<UserModel> userModel = UserModel().obs;

  RxList<ZoneModel> zoneList = <ZoneModel>[].obs;
  Rx<ZoneModel> selectedZone = ZoneModel().obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getArgument();
    super.onInit();
  }

  Future<void> getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      type.value = argumentData['type'];
      userModel.value = argumentData['userModel'];
      if (type.value == "mobileNumber" || type.value == "whatsapp") {
        phoneNUmberEditingController.value.text = userModel.value.phoneNumber ?? "";
        countryCodeEditingController.value.text = userModel.value.countryCode ?? "";
        countryISOCodeEditingController.value.text = userModel.value.countryISOCode ?? "";
      } else if (type.value == "google" || type.value == "apple") {
        emailEditingController.value.text = userModel.value.email ?? "";
        firstNameEditingController.value.text = userModel.value.firstName ?? "";
        lastNameEditingController.value.text = userModel.value.lastName ?? "";
      }
    }

    await FireStoreUtils.getZone().then((value) {
      if (value != null) {
        zoneList.value = value;
      }
    });
  }

  Future<void> signUpWithEmailAndPassword() async {
    signUp();
  }

  Future<void> signUp() async {
    final isSocialSignUp = type.value == "google" || type.value == "apple";
    if (!isSocialSignUp) {
      ShowToastDialog.showLoader("Please wait");
    }
    if (type.value == "google" || type.value == "apple" || type.value == "mobileNumber") {
      userModel.value.firstName = firstNameEditingController.value.text.toString();
      userModel.value.lastName = lastNameEditingController.value.text.toString();
      userModel.value.email = emailEditingController.value.text.toString().toLowerCase();
      userModel.value.phoneNumber = phoneNUmberEditingController.value.text.toString();
      userModel.value.role = Constant.userRoleDriver;
      userModel.value.fcmToken = await NotificationService.getToken();
      userModel.value.active = false;
      userModel.value.isDocumentVerify = false;
      userModel.value.countryCode = countryCodeEditingController.value.text;
      userModel.value.countryISOCode = countryISOCodeEditingController.value.text;
      userModel.value.createdAt = Timestamp.now();
      userModel.value.zoneId = selectedZone.value.id;
      userModel.value.appIdentifier = Platform.isAndroid ? 'android' : 'ios';
      userModel.value.isAutoVerify = false;

      await FireStoreUtils.updateUser(userModel.value).then(
        (value) {
          if (Constant.autoApproveDriver == true) {
            Get.offAll(const DashBoardScreen());
            ShowToastDialog.showToast("Account create successfully");
          } else {
            ShowToastDialog.showToast("Thank you for sign up, your application is under approval so please wait till that approve.");
            Get.offAll(const LoginScreen());
          }
        },
      );
    } else {
      try {
        log("emailEditingController.value.text :::: ${emailEditingController.value.text}");
        log("passwordEditingController.value.text :::: ${passwordEditingController.value.text}");

        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailEditingController.value.text.trim(),
          password: passwordEditingController.value.text.trim(),
        );
        log("emailEditingController.value.text :::: ${emailEditingController.value.text}");
        log("passwordEditingController.value.text :::: ${passwordEditingController.value.text} :: ${credential.user?.uid}");
        if (credential.user != null) {
          userModel.value.id = credential.user!.uid;
          userModel.value.firstName = firstNameEditingController.value.text.toString();
          userModel.value.lastName = lastNameEditingController.value.text.toString();
          userModel.value.email = emailEditingController.value.text.toString().toLowerCase();
          userModel.value.phoneNumber = phoneNUmberEditingController.value.text.toString();
          userModel.value.role = Constant.userRoleDriver;
          userModel.value.fcmToken = await NotificationService.getToken();
          userModel.value.active = false;
          userModel.value.isDocumentVerify = false;
          userModel.value.countryCode = countryCodeEditingController.value.text;
          userModel.value.countryISOCode = countryISOCodeEditingController.value.text;
          userModel.value.createdAt = Timestamp.now();
          userModel.value.zoneId = selectedZone.value.id;
          userModel.value.appIdentifier = Platform.isAndroid ? 'android' : 'ios';
          userModel.value.provider = type.value == "whatsapp" ? 'whatsapp' : 'email';
          userModel.value.isAutoVerify = false;

          await FireStoreUtils.updateUser(userModel.value).then(
            (value) async {
              if (Constant.autoApproveDriver == true) {
                Get.offAll(const DashBoardScreen());
              } else {
                ShowToastDialog.showToast("Thank you for sign up, your application is under approval so please wait till that approve.");
                Get.offAll(const LoginScreen());
              }
            },
          );
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          ShowToastDialog.showToast("The password provided is too weak.");
        } else if (e.code == 'email-already-in-use') {
          ShowToastDialog.showToast("The account already exists for that email.");
        } else if (e.code == 'invalid-email') {
          ShowToastDialog.showToast("Enter email is Invalid");
        }
      } catch (e) {
        ShowToastDialog.showToast(e.toString());
      }
    }

    if (!isSocialSignUp) {
      ShowToastDialog.closeLoader();
    }
  }
}
