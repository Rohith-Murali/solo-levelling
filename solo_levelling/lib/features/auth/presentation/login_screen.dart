import 'package:material_ui/material_ui.dart';

import '../application/auth_controller.dart';
import 'widgets/auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.controller,
    required this.errorMessage,
    required this.onShowRegister,
    super.key,
  });

  final AuthController controller;
  final String? errorMessage;
  final VoidCallback onShowRegister;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await widget.controller.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      children: [
        const AuthBrandHeader(
          title: 'SYSTEM ACCESS',
          subtitle: 'Sign in to continue your journey.',
        ),
        const SizedBox(height: 28),
        AuthPanel(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  fieldKey: const ValueKey('login-email'),
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
                  fieldKey: const ValueKey('login-password'),
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  textInputAction: TextInputAction.done,
                  obscureText: _hidePassword,
                  validator: validatePassword,
                  onSubmitted: (_) => _submit(),
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
                AuthErrorMessage(message: widget.errorMessage),
                const SizedBox(height: 20),
                AuthSubmitButton(
                  label: 'Sign in',
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
            const Text("Don't have an account?"),
            TextButton(
              onPressed: widget.controller.state.isBusy
                  ? null
                  : widget.onShowRegister,
              child: const Text('Create account'),
            ),
          ],
        ),
      ],
    );
  }
}
