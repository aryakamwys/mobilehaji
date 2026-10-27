import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/store_provider.dart';
import '../buyer/buyer_shell.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _referral = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _referral.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 400));
    try {
      ref.read(storeProvider.notifier).register(
          _name.text, _email.text, _password.text, _referral.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const BuyerShell()),
          (_) => false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Buyer')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Buyer Baru',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'Nama lengkap',
                    prefixIcon: Icon(Icons.person_outline)),
                validator: (v) =>
                    (v == null || v.trim().length < 3) ? 'Nama minimal 3 karakter' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                validator: (v) => (v == null || !v.contains('@') || !v.contains('.'))
                    ? 'Email tidak valid'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                validator: (v) => (v == null || v.length < 8)
                    ? 'Password minimal 8 karakter'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _referral,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    labelText: 'Kode referral (opsional)',
                    prefixIcon: Icon(Icons.card_membership)),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Daftar & Masuk'),
              ),
              const SizedBox(height: 8),
              Text(
                'Pendaftaran dengan password — data disimpan aman di server.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
