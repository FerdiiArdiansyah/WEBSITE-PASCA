import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/theme.dart';

/// Kartu statistik berwarna dengan ikon gradien.
class StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final String? sub;
  final VoidCallback? onTap;
  const StatCard({super.key, required this.label, required this.value, required this.icon, this.color = AppColors.primary, this.sub, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(children: [
          Positioned(right: -18, top: -18, child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .07)))),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: LinearGradient(colors: [color, color.withValues(alpha: .7)]),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: .3), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(label.toUpperCase(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: .5)),
                  const SizedBox(height: 3),
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                  if (sub != null) Text(sub!, style: const TextStyle(fontSize: 11, color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Banner sambutan bergradien di atas dashboard.
class WelcomeBanner extends StatelessWidget {
  final String title, subtitle;
  final List<(IconData, String)> pills;
  final IconData icon;
  final List<Widget>? actions;
  const WelcomeBanner({super.key, required this.title, required this.subtitle, this.pills = const [], this.icon = Icons.school_rounded, this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: AppColors.gradPrimary, borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 10))]),
      child: Stack(children: [
        Positioned(right: -30, top: -40, child: Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .1)))),
        Positioned(right: 10, bottom: -10, child: Icon(icon, size: 90, color: Colors.white.withValues(alpha: .18))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (pills.isNotEmpty)
            Wrap(spacing: 6, runSpacing: 6, children: pills.map((p) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(50), border: Border.all(color: Colors.white.withValues(alpha: .3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(p.$1, size: 12, color: Colors.white), const SizedBox(width: 5), Text(p.$2, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))]),
            )).toList()),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 13)),
          if (actions != null) ...[const SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, children: actions!)],
        ]),
      ]),
    );
  }
}

class BannerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool outlined;
  const BannerButton(this.label, this.icon, this.onTap, {super.key, this.outlined = false});
  @override
  Widget build(BuildContext context) => Material(
        color: outlined ? Colors.transparent : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: outlined ? Border.all(color: Colors.white.withValues(alpha: .6)) : null),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: outlined ? Colors.white : AppColors.primary), const SizedBox(width: 6),
              Text(label, style: TextStyle(color: outlined ? Colors.white : AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        ),
      );
}

/// Kartu seksi dengan judul bergaris aksen.
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;
  const SectionCard({super.key, required this.title, required this.child, this.trailing, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) => Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(children: [
              Container(width: 4, height: 18, decoration: BoxDecoration(gradient: AppColors.gradPrimary, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              if (trailing != null) trailing!,
            ]),
          ),
          const Divider(height: 1),
          Padding(padding: padding, child: child),
        ]),
      );
}

class StatusBadge extends StatelessWidget {
  final String? status;
  const StatusBadge(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.status(status);
    final s = status ?? '-';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(50)),
      child: Text(s.isEmpty ? '-' : s[0].toUpperCase() + s.substring(1), style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyState(this.message, {super.key, this.icon = Icons.inbox_rounded});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(children: [Icon(icon, size: 44, color: AppColors.muted.withValues(alpha: .5)), const SizedBox(height: 8), Text(message, style: const TextStyle(color: AppColors.muted), textAlign: TextAlign.center)]),
      );
}

/// Pemuat data generik dengan tarik-untuk-muat-ulang & penanganan error.
class AsyncView<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, Future<void> Function() reload) builder;
  const AsyncView({super.key, required this.load, required this.builder});
  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _f;
  @override
  void initState() {
    super.initState();
    _f = widget.load();
  }

  Future<void> _reload() async {
    setState(() => _f = widget.load());
    await _f.catchError((_) => null as T);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
          if (s.hasError) {
            final e = s.error;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.danger),
                  const SizedBox(height: 10),
                  Text(e is ApiException ? e.message : 'Tidak dapat terhubung ke server.\n$e', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: const Text('Coba lagi'), style: OutlinedButton.styleFrom(minimumSize: const Size(160, 44))),
                ]),
              ),
            );
          }
          return RefreshIndicator(onRefresh: _reload, child: widget.builder(c, s.data as T, _reload));
        },
      );
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;
  const InfoRow(this.label, this.value, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
          Expanded(child: trailing ?? Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
      );
}

class ListTileCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading, trailing;
  final VoidCallback? onTap;
  const ListTileCard({super.key, required this.title, this.subtitle, this.leading, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          onTap: onTap, leading: leading,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          trailing: trailing, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      );
}

class IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  const IconBox(this.icon, {super.key, this.color = AppColors.primary});
  @override
  Widget build(BuildContext context) => Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      );
}

class ProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  const ProgressBar(this.value, {super.key, this.color});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(value: value.clamp(0, 1), minHeight: 8, backgroundColor: const Color(0xFFE9EBF5), color: color ?? AppColors.primary),
      );
}

class Avatar extends StatelessWidget {
  final String text;
  final double size;
  const Avatar(this.text, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size, alignment: Alignment.center,
        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.gradGold),
        child: Text(text, style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800, fontSize: size * .42)),
      );
}

/// Baris filter chip horizontal.
class FilterChips extends StatelessWidget {
  final List<(String, String)> items; // (value, label)
  final String? selected;
  final ValueChanged<String?> onChanged;
  const FilterChips({super.key, required this.items, required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: items.map((i) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(i.$2), selected: selected == i.$1, onSelected: (_) => onChanged(i.$1),
            selectedColor: AppColors.primary, labelStyle: TextStyle(color: selected == i.$1 ? Colors.white : AppColors.text, fontWeight: FontWeight.w600, fontSize: 12),
            backgroundColor: Colors.white, side: const BorderSide(color: Color(0xFFE3E6F0)),
          ),
        )).toList()),
      );
}
