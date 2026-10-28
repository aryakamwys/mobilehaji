import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/rupiah.dart';
import '../../core/string_ext.dart';
import '../../core/widgets/labeled_row.dart';
import '../../models/models.dart';
import '../../providers/admin_providers.dart';

/// Daftar seluruh anggota + jaringannya, paginasi 20 per halaman.
class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  int _halaman = 1;

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(adminMembersPageProvider(_halaman));
    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminMembersPageProvider(_halaman).future),
      child: page.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(padding: const EdgeInsets.all(16), children: [
          const SizedBox(height: 24),
          Text(pesanError(e),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          FilledButton.tonal(
              onPressed: () =>
                  ref.invalidate(adminMembersPageProvider(_halaman)),
              child: const Text('Coba Lagi')),
        ]),
        data: (p) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Pengguna dan Jaringan',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (p.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Belum ada anggota',
                    style: Theme.of(context).textTheme.bodySmall),
              )
            else
              ...p.items.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MemberCard(member: m),
                  )),
            const SizedBox(height: 8),
            Row(children: [
              OutlinedButton(
                onPressed:
                    _halaman <= 1 ? null : () => setState(() => _halaman--),
                child: const Text('Sebelumnya'),
              ),
              Expanded(
                child: Text(
                  'Halaman $_halaman/${p.totalPages < 1 ? 1 : p.totalPages}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              OutlinedButton(
                onPressed: _halaman >= p.totalPages
                    ? null
                    : () => setState(() => _halaman++),
                child: const Text('Berikutnya'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(member.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: member.isAdmin
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                      : Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(member.role.kapital,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                            color: member.isAdmin
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer)),
              ),
            ]),
            const SizedBox(height: 2),
            Text(member.email, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            LabeledRow('Saldo', member.balance.rupiah),
            LabeledRow('Kode', member.referralCode),
            LabeledRow('Downline', '${member.downlines}'),
          ],
        ),
      ),
    );
  }
}
