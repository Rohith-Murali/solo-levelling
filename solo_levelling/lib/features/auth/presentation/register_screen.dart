import 'package:material_ui/material_ui.dart';

import '../application/auth_controller.dart';
import 'widgets/auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    required this.controller,
    required this.errorMessage,
    required this.onShowLogin,
    super.key,
  });

  final AuthController controller;
  final String? errorMessage;
  final VoidCallback onShowLogin;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await widget.controller.register(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      children: [
        const AuthBrandHeader(
          title: 'CREATE ACCOUNT',
          subtitle: 'Begin your path to becoming stronger.',
        ),
        const SizedBox(height: 28),
        AuthPanel(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  fieldKey: const ValueKey('register-email'),
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.alternate_email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: validateEmail,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  fieldKey: const ValueKey('register-password'),
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  textInputAction: TextInputAction.next,
                  obscureText: _hidePassword,
                  validator: validatePassword,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  suffixIcon: IconButton(
                    tooltip: _hidePassword ? 'Show password' : 'Hide password',
                    onPressed: () {
                      setState(() => _hidePassword = !_hidePassword);
                    },
                    icon: Icon(
                      _hidePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  fieldKey: const ValueKey('register-confirm-password'),
                  controller: _confirmPasswordController,
                  label: 'Confirm password',
                  icon: Icons.lock_outline,
                  textInputAction: TextInputAction.done,
                  obscureText: _hidePassword,
                  validator: (value) => value != _passwordController.text
                      ? 'Passwords do not match.'
                      : null,
                  onSubmitted: (_) => _submit(),
                ),
                AuthErrorMessage(message: widget.errorMessage),
                const SizedBox(height: 20),
                AuthSubmitButton(
                  label: 'Create account',
                  isBusy: widget.controller.state.isBusy,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Column(
          children: [
            const Text('Already have an account?'),
            TextButton(
              onPressed: widget.controller.state.isBusy
                  ? null
                  : widget.onShowLogin,
              child: const Text('Sign in'),
            ),
          ],
        ),
      ],
    );
  }
}
