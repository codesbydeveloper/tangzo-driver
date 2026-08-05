import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/bank_details_controller.dart';
import 'package:driver/themes/responsive.dart';

import 'package:driver/widget/translated_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/text_field_widget.dart';
import 'package:driver/utils/dark_theme_provider.dart';

class BankDetailsScreen extends StatelessWidget {
  const BankDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX(
        init: BankDetailsController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: themeChange.getThem() ? AppThemeData.surfaceDark : AppThemeData.surface,
            appBar: AppBar(
              backgroundColor: themeChange.getThem() ? AppThemeData.surfaceDark : AppThemeData.surface,
              centerTitle: false,
              title: TranslatedText(
                "Bank Setup",
                style: TextStyle(color: themeChange.getThem() ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 18, fontFamily: AppThemeData.medium),
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextFieldWidget(
                      title: 'Bank Name',
                      controller: controller.bankNameController.value,
                      hintText: 'Enter Bank Name',
                    ),
                    TextFieldWidget(
                      title: 'Branch Name',
                      controller: controller.branchNameController.value,
                      hintText: 'Enter Branch Name',
                    ),
                    TextFieldWidget(
                      title: 'Holder Name',
                      controller: controller.holderNameController.value,
                      hintText: 'Enter Holder Name',
                    ),
                    TextFieldWidget(
                      title: 'Account Number',
                      controller: controller.accountNoController.value,
                      hintText: 'Enter Account Number',
                    ),
                    TextFieldWidget(
                      title: 'Other Information',
                      controller: controller.otherInfoController.value,
                      hintText: 'Enter Other Information',
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: InkWell(
              onTap: () {
                if (controller.bankNameController.value.text.isEmpty) {
                  ShowToastDialog.showToast("Please enter bank name");
                } else if (controller.branchNameController.value.text.isEmpty) {
                  ShowToastDialog.showToast("Please enter branch name");
                } else if (controller.holderNameController.value.text.isEmpty) {
                  ShowToastDialog.showToast("Please enter holder name");
                } else if (controller.accountNoController.value.text.isEmpty) {
                  ShowToastDialog.showToast("Please enter account number");
                } else {
                  controller.saveBank();
                }
              },
              child: Container(
                color: AppThemeData.driverApp300,
                width: Responsive.width(100, context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: TranslatedText(
                    "Save Details",
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
          );
        });
  }
}
