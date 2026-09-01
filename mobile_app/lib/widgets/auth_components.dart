import 'package:flutter/material.dart';

/// Centralized Design Tokens for Authentication & App Foundation
class AppColors {
  static const primary = Color(0xFFFF8F00); // Saffron Accent
  static const secondary = Color(0xFF3949AB); // Deep Indigo
  static const background = Color(0xFFF8FAFC); // Slate 50 Background
  static const surface = Color(0xFFFFFFFF); // Pure White Surface
  static const inputFill = Color(0xFFF8FAFC); // Slate 50 Input Fill
  static const border = Color(0xFFE5E7EB); // Gray 200 Border
  static const borderFocused = Color(0xFFFF8F00); // Saffron Focus Border
  static const textPrimary = Color(0xFF0F172A); // Slate 900 Title Text
  static const textSecondary = Color(0xFF64748B); // Slate 500 Subtitle Text
  static const textMuted = Color(0xFF94A3B8); // Slate 400 Placeholder Text
  
  // Status Banners
  static const errorBackground = Color(0xFFFEF2F2);
  static const errorText = Color(0xFF991B1B);
  static const errorBorder = Color(0xFFFCA5A5);
  static const successBackground = Color(0xFFF0FDF4);
  static const successText = Color(0xFF166534);
  static const successBorder = Color(0xFF86EFAC);
}

class AppRadius {
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 22.0;
  static const double xl = 24.0;
  static const double sheet = 28.0;
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

class AppShadows {
  static const surface = [
    BoxShadow(
      color: Color(0x050F172A),
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];

  static const logo = [
    BoxShadow(
      color: Color(0x0C0F172A),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static const primaryButton = [
    BoxShadow(
      color: Color(0x38FF8F00),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  static const roleIndigo = [
    BoxShadow(
      color: Color(0x333949AB),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];

  static const roleSaffron = [
    BoxShadow(
      color: Color(0x33FF8F00),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];
}

class AppAnimation {
  static const duration = Duration(milliseconds: 200);
  static const curve = Curves.easeInOut;
}

/// 1. Shared Authentication Header (Logo + Title + Subtitle)
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.logo,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/logo.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md + 4),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// 2. Pure Typography Section Card (No decorative icon badges)
class AuthSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const AuthSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pure Typography Header (No Decorative Icon Box)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg - 2),
          ...children,
        ],
      ),
    );
  }
}

/// 3. Filled Material 3 Text Field (No Decorative Prefix Icons)
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.readOnly = false,
    this.onTap,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      readOnly: readOnly,
      onTap: onTap,
      validator: validator,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        hintText: hintText,
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textMuted,
          fontSize: 14,
        ),
        prefixIcon: null, // NO DECORATIVE PREFIX ICON
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.borderFocused, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
    );
  }
}

/// 4. Password Field (With Functional Eye Toggle Suffix Icon)
class AuthPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final VoidCallback onToggleObscure;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;

  const AuthPasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.onToggleObscure,
    this.textInputAction = TextInputAction.done,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        prefixIcon: null, // NO DECORATIVE PREFIX ICON
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.textMuted,
            size: 20,
          ),
          onPressed: onToggleObscure,
        ),
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.borderFocused, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
    );
  }
}

/// 5. Shared Primary Saffron Button (56px Height)
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: AnimatedContainer(
        duration: AppAnimation.duration,
        curve: AppAnimation.curve,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: isLoading ? null : AppShadows.primaryButton,
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
        ),
      ),
    );
  }
}

/// 6. Shared Secondary Text Link Button
class AuthTextButton extends StatelessWidget {
  final String leadingText;
  final String actionText;
  final VoidCallback onTap;
  final Color actionColor;

  const AuthTextButton({
    super.key,
    required this.leadingText,
    required this.actionText,
    required this.onTap,
    this.actionColor = AppColors.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          leadingText,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            actionText,
            style: TextStyle(
              fontFamily: 'Inter',
              color: actionColor,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// 7. Segmented Role Selector Chips (No Decorative Icons)
class AuthRoleSelector extends StatelessWidget {
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;

  const AuthRoleSelector({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFolk = selectedRole == 'folk_boy';
    final isResidency = selectedRole == 'residency';

    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: AppAnimation.duration,
            curve: AppAnimation.curve,
            decoration: BoxDecoration(
              color: isFolk ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isFolk ? AppColors.primary : AppColors.border,
                width: 1,
              ),
              boxShadow: isFolk ? AppShadows.roleSaffron : null,
            ),
            child: InkWell(
              onTap: () => onRoleChanged('folk_boy'),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Text(
                  'Folk Boy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: isFolk ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                    color: isFolk ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: AnimatedContainer(
            duration: AppAnimation.duration,
            curve: AppAnimation.curve,
            decoration: BoxDecoration(
              color: isResidency ? AppColors.secondary : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isResidency ? AppColors.secondary : AppColors.border,
                width: 1,
              ),
              boxShadow: isResidency ? AppShadows.roleIndigo : null,
            ),
            child: InkWell(
              onTap: () => onRoleChanged('residency'),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Text(
                  'Residency',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: isResidency ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                    color: isResidency ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 8. Assigned Preacher Dropdown Selector Tile
class AuthDropdownTile extends StatelessWidget {
  final Map<String, dynamic>? selectedPreacher;
  final VoidCallback onTap;

  const AuthDropdownTile({
    super.key,
    required this.selectedPreacher,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedPreacher != null;

    return AnimatedContainer(
      duration: AppAnimation.duration,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        border: Border.all(
          color: hasSelection ? AppColors.primary : AppColors.border,
          width: hasSelection ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              hasSelection
                  ? Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: selectedPreacher!['photo_url'] != null
                              ? NetworkImage(selectedPreacher!['photo_url'])
                              : null,
                          backgroundColor: const Color(0xFFFEF3C7),
                          child: selectedPreacher!['photo_url'] == null
                              ? Text(
                                  selectedPreacher!['name'][0].toUpperCase(),
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          selectedPreacher!['name'] ?? '',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Click to select your preacher...',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 9. Status Banner (Error & Success)
class AuthStatusBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const AuthStatusBanner({
    super.key,
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppAnimation.duration,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isError ? AppColors.errorBackground : AppColors.successBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isError ? AppColors.errorBorder : AppColors.successBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Inter',
                color: isError ? AppColors.errorText : AppColors.successText,
                fontSize: 13,
                fontWeight: isError ? FontWeight.w400 : FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
