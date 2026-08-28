import 'package:flutter/material.dart';

import '../data/app_info.dart';
import '../design/icons.dart';
import '../design/theme.dart';
import '../l10n/strings.dart';
import '../widgets/chips.dart';
import '../widgets/scaffold.dart';

/// What leaves the phone, stated plainly.
///
/// Spy asks the server two things - is there a newer build, and what packs are
/// on offer - and downloads a pack when somebody taps Get. That is the whole
/// of it: no accounts, no analytics, nothing typed or played ever uploaded.
/// It belongs here because it is also the answer to "is it safe to hand this
/// app my friend's phone".
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.spy;
    final t = context.type;
    final s = SpyStrings.of(context);

    return SpyScaffold(
      title: s.aboutTitle,
      onBack: () => Navigator.of(context).pop(),
      body: SpyBody(
        scrollable: true,
        gap: SpyPrimitives.s6,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: SpyPrimitives.s6),
              // The mark: a brass redaction bar with the ascender of a hidden
              // letter escaping above it. Never crimson - the app is not the
              // spy.
              SpyMark(color: c.accent, size: 64),
              const SizedBox(height: SpyPrimitives.s5),
              Text(
                t.uppercases ? s.appName.toUpperCase() : s.appName,
                style: t.wordmark.copyWith(color: c.text, fontSize: 34),
              ),
              const SizedBox(height: SpyPrimitives.s3),
              Text(
                t.uppercases ? s.appTagline.toUpperCase() : s.appTagline,
                style: t.file.copyWith(color: c.textFaint, fontSize: 10),
              ),
              const SizedBox(height: SpyPrimitives.s2),
              Text(
                // The build number is beside the version because it is the
                // number the server and a bug report both talk in.
                '${s.aboutVersion(AppInfo.version)} · ${s.aboutBuild(AppInfo.build)}',
                style: t.caption.copyWith(color: c.textFaint),
              ),
            ],
          ),
          SpyBanner(
            title: s.aboutNetwork,
            body: s.aboutNetworkBody,
          ),
        ],
      ),
    );
  }
}
