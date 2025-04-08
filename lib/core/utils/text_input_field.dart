import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:flutter/services.dart';

class TextInputField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType keyboardType;
  final IconData? prefixIcon; // Make the prefixIcon optional
  final IconData? suffixIcon; // Make the suffixIcon optional (now IconData)
  final String? Function(String?)? validator; // Validator function
  final String? errorText; // Optional error text for external error handling
  final bool
      isPhoneNumber; // Flag to indicate if this is for phone number input
  final bool isDateField; // Flag to indicate if this is a date picker field
  final bool isLowercase; // Flag to indicate lowercase input

  const TextInputField({
    Key? key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon, // Now it's nullable
    this.suffixIcon, // Now it's nullable
    this.validator,
    this.errorText,
    this.isPhoneNumber = false, // Check if this is a phone number input
    this.isDateField = false, // Check if this is a date picker input
    this.isLowercase = false, // Default is false
  }) : super(key: key);

  @override
  State<TextInputField> createState() => _TextInputFieldState();
}

class _TextInputFieldState extends State<TextInputField> {
  late bool _isObscured;
  late FocusNode _focusNode;
  late ValueNotifier<bool> _isFocusedNotifier;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;
    _focusNode = FocusNode();
    _isFocusedNotifier = ValueNotifier<bool>(false);
    _phoneController = widget.controller; // Phone controller from parent

    _focusNode.addListener(() {
      _isFocusedNotifier.value = _focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _isFocusedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    String _formattedPhoneNumber = ''; // To store the formatted phone number

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: _isFocusedNotifier,
          builder: (context, isFocused, child) {
            return Container(
              decoration: BoxDecoration(
                color: isFocused
                    ? primaryColor.withOpacity(0.1)
                    : isDarkMode
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: widget.isPhoneNumber
                  ? InternationalPhoneNumberInput(
                      onInputChanged: (PhoneNumber number) {
                        // Capture formatted phone number
                        _formattedPhoneNumber = number.phoneNumber ?? '';
                        print('Formatted phone number: $_formattedPhoneNumber');
                      },
                      initialValue:
                          PhoneNumber(isoCode: 'US'), // Default country code
                      textFieldController: _phoneController,
                      selectorConfig: SelectorConfig(
                        selectorType: PhoneInputSelectorType.DIALOG,
                        showFlags: true,
                        setSelectorButtonAsPrefixIcon: true,
                        leadingPadding: 10,
                      ),
                      formatInput:
                          true, // Allow input to be formatted automatically
                      inputDecoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.transparent,
                        hintText: widget.hintText,
                        hintStyle: TextStyle(
                          color: isDarkMode
                              ? Colors.grey.shade500
                              : Colors.grey.shade700,
                          fontSize: 14,
                        ),
                        prefixIcon: widget.prefixIcon != null
                            ? Icon(
                                widget.prefixIcon,
                                color: isFocused
                                    ? primaryColor
                                    : isDarkMode
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade700,
                              )
                            : null,
                        suffixIcon: widget.suffixIcon != null
                            ? Icon(
                                widget.suffixIcon,
                                color: isFocused
                                    ? primaryColor
                                    : isDarkMode
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade700,
                              )
                            : (widget.obscureText
                                ? IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _isObscured = !_isObscured;
                                      });
                                    },
                                    icon: Icon(
                                      _isObscured
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: isFocused
                                          ? primaryColor
                                          : isDarkMode
                                              ? Colors.grey.shade500
                                              : Colors.grey.shade700,
                                    ),
                                  )
                                : null),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                      ),
                      cursorColor: primaryColor,
                    )
                  : TextField(
                      controller: widget.controller,
                      obscureText: _isObscured,
                      keyboardType: widget.isDateField
                          ? TextInputType.datetime
                          : widget.keyboardType,
                      focusNode: _focusNode,
                      readOnly: widget.isDateField,
                      onTap: widget.isDateField
                          ? () async {
                              DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(1900),
                                lastDate: DateTime(2100),
                              );
                              if (pickedDate != null) {
                                widget.controller.text =
                                    DateFormat('yyyy-MM-dd').format(pickedDate);
                              }
                            }
                          : null,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontSize: 16,
                      ),
                      inputFormatters: widget.isLowercase
                          ? [
                              FilteringTextInputFormatter.allow(RegExp(
                                  r'[a-z0-9\s!@#\$%^&*(),.?":{}|<>_\-+=\\]')) // Allow lowercase letters, digits, spaces, and special characters
                            ]
                          : [],
                      onChanged: widget.isLowercase
                          ? (value) {
                              widget.controller.text = value
                                  .toLowerCase(); // Convert input to lowercase
                              widget.controller.selection =
                                  TextSelection.collapsed(
                                      offset: value
                                          .length); // Keep cursor at the end
                            }
                          : null,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.transparent,
                        hintText: widget.hintText,
                        hintStyle: TextStyle(
                          color: isDarkMode
                              ? Colors.grey.shade500
                              : Colors.grey.shade700,
                          fontSize: 14,
                        ),
                        prefixIcon: widget.prefixIcon != null
                            ? Icon(
                                widget.prefixIcon,
                                color: isFocused
                                    ? primaryColor
                                    : isDarkMode
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade700,
                              )
                            : null,
                        suffixIcon: widget.suffixIcon != null
                            ? Icon(
                                widget.suffixIcon,
                                color: isFocused
                                    ? primaryColor
                                    : isDarkMode
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade700,
                              )
                            : (widget.obscureText
                                ? IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _isObscured = !_isObscured;
                                      });
                                    },
                                    icon: Icon(
                                      _isObscured
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: isFocused
                                          ? primaryColor
                                          : isDarkMode
                                              ? Colors.grey.shade500
                                              : Colors.grey.shade700,
                                    ),
                                  )
                                : null),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                      ),
                      cursorColor: primaryColor,
                    ),
            );
          },
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 10),
            child: Text(
              widget.errorText!,
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
