import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:driver/firebase_options.dart';
import 'package:driver/app/auth_screen/signup_screen.dart';
import 'package:driver/app/dash_board_screen/dash_board_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginController extends GetxController {
  Rx<TextEditingController> emailEditingController = TextEditingController().obs;
  Rx<TextEditingController> passwordEditingController = TextEditingController().obs;
  static const List<String> _googleScopes = ['email', 'profile'];
  static bool _googleSignInInitialized = false;

  RxBool passwordVisible = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    super.onInit();
  }

  Future<void> loginWithEmailAndPassword() async {
    ShowToastDialog.showLoader("Please wait.");
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailEditingController.value.text.trim(),
        password: passwordEditingController.value.text.trim(),
      );
      UserModel? userModel = await FireStoreUtils.getUserProfile(credential.user!.uid);
      if (userModel?.role == Constant.userRoleDriver) {
        if (userModel?.active == true) {
          userModel?.fcmToken = await NotificationService.getToken();
          await FireStoreUtils.updateUser(userModel!);
          Get.offAll(const DashBoardScreen());
        } else {
          await FirebaseAuth.instance.signOut();
          ShowToastDialog.showToast("This user is disable please contact to administrator");
        }
      } else {
        await FirebaseAuth.instance.signOut();
        ShowToastDialog.showToast("This user is not created in driver application.");
      }
    } on FirebaseAuthException catch (e) {
      print(e.code);
      if (e.code == 'user-not-found') {
        ShowToastDialog.showToast("No user found for that email.");
      } else if (e.code == 'wrong-password') {
        ShowToastDialog.showToast("Wrong password provided for that user.");
      } else if (e.code == 'invalid-email') {
        ShowToastDialog.showToast("Invalid Email.");
      }
    }
    ShowToastDialog.closeLoader();
  }

  Future<void> loginWithGoogle() async {
    // Do not show a blocking loader before Google Sign-In — the EasyLoading mask cancels the account picker on Android.
    final value = await signInWithGoogle();
    if (value == null) {
      return;
    }

    ShowToastDialog.showLoader("please wait...");
    try{
      if (value.additionalUserInfo!.isNewUser) {
        UserModel userModel = UserModel();
        userModel.id = value.user!.uid;
        userModel.email = value.user!.email;
        userModel.firstName = value.user!.displayName?.split(' ').first;
        userModel.lastName = value.user!.displayName?.split(' ').last;
        userModel.provider = 'google';

        Get.off(const SignupScreen(), arguments: {
          "userModel": userModel,
          "type": "google",
        });
      } else {
        final userExit = await FireStoreUtils.userExistOrNot(value.user!.uid);
        if (userExit == true) {
          UserModel? userModel = await FireStoreUtils.getUserProfile(
              value.user!.uid);
          if (userModel != null && userModel.role == Constant.userRoleDriver) {
            if (userModel.active == true) {
              userModel.fcmToken = await NotificationService.getToken();
              await FireStoreUtils.updateUser(userModel);
              Get.offAll(const DashBoardScreen());
            } else {
              await FirebaseAuth.instance.signOut();
              ShowToastDialog.showToast(
                  "This user is disable please contact to administrator");
            }
          } else {
            await FirebaseAuth.instance.signOut();
            // ShowToastDialog.showToast("This user is disable please contact to administrator");
          }
        } else {
          UserModel userModel = UserModel();
          userModel.id = value.user!.uid;
          userModel.email = value.user!.email;
          userModel.firstName = value.user!
              .displayName
              ?.split(' ')
              .first;
          userModel.lastName = value.user!
              .displayName
              ?.split(' ')
              .last;
          userModel.provider = 'google';

          Get.off(const SignupScreen(), arguments: {
            "userModel": userModel,
            "type": "google",
          });
        }
      }
    } finally {
      ShowToastDialog.closeLoader();
    }
  }

  Future<void> loginWithApple() async {
    ShowToastDialog.showLoader("please wait...");
    await signInWithApple().then((value) async {
      ShowToastDialog.closeLoader();
      if (value != null) {
        Map<String, dynamic> map = value;
        AuthorizationCredentialAppleID appleCredential = map['appleCredential'];
        UserCredential userCredential = map['userCredential'];
        if (userCredential.additionalUserInfo!.isNewUser) {
          UserModel userModel = UserModel();
          userModel.id = userCredential.user!.uid;
          userModel.email = appleCredential.email;
          userModel.firstName = appleCredential.givenName;
          userModel.lastName = appleCredential.familyName;
          userModel.provider = 'apple';

          ShowToastDialog.closeLoader();
          Get.off(const SignupScreen(), arguments: {
            "userModel": userModel,
            "type": "apple",
          });
        } else {
          await FireStoreUtils.userExistOrNot(userCredential.user!.uid).then((userExit) async {
            ShowToastDialog.closeLoader();
            if (userExit == true) {
              UserModel? userModel = await FireStoreUtils.getUserProfile(userCredential.user!.uid);
              if (userModel != null && userModel.role == Constant.userRoleDriver) {
                if (userModel.active == true) {
                  userModel.fcmToken = await NotificationService.getToken();
                  await FireStoreUtils.updateUser(userModel);
                  Get.offAll(const DashBoardScreen());
                } else {
                  await FirebaseAuth.instance.signOut();
                  ShowToastDialog.showToast("This user is disable please contact to administrator");
                }
              } else {
                await FirebaseAuth.instance.signOut();
                // ShowToastDialog.showToast("This user is disable please contact to administrator");
              }
            } else {
              UserModel userModel = UserModel();
              userModel.id = userCredential.user!.uid;
              userModel.email = appleCredential.email;
              userModel.firstName = appleCredential.givenName;
              userModel.lastName = appleCredential.familyName;
              userModel.provider = 'apple';

              Get.off(const SignupScreen(), arguments: {
                "userModel": userModel,
                "type": "apple",
              });
            }
          });
        }
      }
    });
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;

      if (!_googleSignInInitialized) {
        await googleSignIn.initialize(
          serverClientId: DefaultFirebaseOptions.googleSignInWebClientId,
        );
        _googleSignInInitialized = true;
      }

      // Clears Credential Manager cache — fixes "[16] Account reauth failed" on Play builds.
      await googleSignIn.signOut();

      final GoogleSignInAccount googleUser = await googleSignIn.authenticate(
        scopeHint: _googleScopes,
      );
      if (googleUser.id.isEmpty) return null;

      final email = googleUser.email;

      UserModel? userModel = await FireStoreUtils.getUserByEmail(email);

      if (userModel?.provider != "google" && userModel?.provider != "apple" && userModel?.provider != null) {
        ShowToastDialog.showToast("The account already exists for that email.");
        return null;
      }

      if ((userModel?.provider == "google" || userModel?.provider == "apple") && userModel?.role != Constant.userRoleDriver) {
        ShowToastDialog.showToast("The account already exists for that email.");
        return null;
      }

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
        debugPrint('Google Sign-In Error: idToken is null — check serverClientId and Firebase SHA-1 fingerprints.');
        ShowToastDialog.showToast("Google sign-in configuration error. Please try again later.");
        return null;
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      return userCredential;
    } on GoogleSignInException catch (e) {
      debugPrint("Google Sign-In Error: $e");
      if (e.code != GoogleSignInExceptionCode.canceled) {
        ShowToastDialog.showToast("Google sign-in failed. Please try again.");
      } else if (e.toString().contains('Account reauth failed')) {
        // ApiException 16 — almost always Play App Signing SHA-1 missing in Firebase/GCP.
        ShowToastDialog.showToast("Google sign-in failed. App signing certificate may not be registered in Firebase.");
      }
      return null;
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      return null;
    }
  }

  String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<Map<String, dynamic>?> signInWithApple() async {
    try {
      final rawNonce = generateNonce();
      final nonce = sha256ofString(rawNonce);

      // Request credential for the currently signed in Apple account.
      AuthorizationCredentialAppleID appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
        // webAuthenticationOptions: WebAuthenticationOptions(clientId: clientID, redirectUri: Uri.parse(redirectURL)),
      );

      final email = appleCredential.email;

      if (email != null) {
        UserModel? userModel = await FireStoreUtils.getUserByEmail(email);

        if (userModel?.provider != "google" && userModel?.provider != "apple" && userModel?.provider != null) {
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast("The account already exists for that email.");
          return null;
        }

        if ((userModel?.provider == "google" || userModel?.provider == "apple") && userModel?.role != Constant.userRoleDriver) {
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast("The account already exists for that email.");
          return null;
        }
      }

      // Create an `OAuthCredential` from the credential returned by Apple.
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in the user with Firebase. If the nonce we generated earlier does
      // not match the nonce in `appleCredential.identityToken`, sign in will fail.
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      return {"appleCredential": appleCredential, "userCredential": userCredential};
    } catch (e) {
      debugPrint(e.toString());
    }
    return null;
  }
}
