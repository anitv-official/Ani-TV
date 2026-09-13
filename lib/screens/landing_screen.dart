import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_branding.dart';
import 'auth_choice_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final AnimationController _entrance;
  bool _accepted = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_accepted || _loading) return;
    setState(() => _loading = true);
    Timer(const Duration(seconds: 3), () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_policy_accepted', true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthChoiceScreen()));
    });
  }

  TextSpan _policyLink(BuildContext context) => TextSpan(
    text: 'سياسة الخصوصية والأمان',
    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700),
    recognizer: TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse('https://anitv-manga-lord.vercel.app/privacy'), mode: LaunchMode.externalApplication),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _entrance, curve: Curves.easeOut),
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 30),
            children: [
              const AuthBranding(),
              const SizedBox(height: 24),
              Text('أهلاً ومرحباً بك في AniTV', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 30, height: 1.2, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              const Text('تطبيقك الأول لعالم الترفيه', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.primaryColor, fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              const Text('أفلام، مسلسلات، أنمي، مانجا، مانهوا، دراما...\nالكل موجود هنا.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 16, height: 1.65)),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: AppTheme.surfaceColor.withOpacity(.78), borderRadius: BorderRadius.circular(22), border: Border.all(color: AppTheme.borderColor)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('المزيد عنا', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  const Text('سياسة الاستخدام – منصة AniTV\n\nتاريخ آخر تحديث: 13 سبتمبر 2026\n\nمقدمة\n\nتُرحّب AniTV بجميع مستخدميها الكرام، وتضع بين أيديهم هذه الوثيقة التي تهدف إلى بيان طبيعة الخدمة المقدَّمة، وتوضيح حدود مسؤولية المنصة، والإطار الذي تعمل بموجبه تجاه المحتوى المعروض من خلالها. إن استخدامكم لتطبيق أو موقع AniTV، بأي شكل من الأشكال، يُعدّ إقرارًا صريحًا منكم بالاطلاع على هذه السياسة والموافقة الكاملة على جميع بنودها؛ فإن كنتم لا توافقون على أي بند منها، فيُرجى التوقف عن استخدام الخدمة فورًا.\n\nأولًا: طبيعة المنصة ودورها\n\nتُعرِّف AniTV نفسها بوصفها منصةً إلكترونية لتجميع وفهرسة المحتوى الترفيهي، من أفلام ومسلسلات أنمي وأعمال مشابهة، وليست بأي حال من الأحوال جهة إنتاج أو ناشرًا أو موزعًا رسميًا لهذه الأعمال. فالمنصة لا تقوم بتصوير أو إنتاج أو ترجمة أو استضافة أي ملفات فيديو أو وسائط على خوادمها الخاصة. وكل ما يظهر من محتوى داخل التطبيق أو الموقع هو في الأصل محتوى منشور ومتاح مسبقًا للعموم عبر مصادر خارجية متعددة منتشرة على شبكة الإنترنت. ويقتصر دور AniTV على تجميع الروابط والبيانات الوصفية المرتبطة بهذا المحتوى، كالعناوين والملخصات والصور المصغرة وعدد الحلقات أو الفصول والتصنيفات، وعرضها للمستخدم ضمن واجهة واحدة منظمة وسهلة التصفح، تيسيرًا للوصول إلى ما هو متاح أصلًا على الشبكة، لا أكثر ولا أقل.', textDirection: TextDirection.rtl, style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13, height: 1.7)),
                  const SizedBox(height: 16),
                  InkWell(onTap: () => _scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOut), child: RichText(textAlign: TextAlign.right, text: TextSpan(style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13), children: [const TextSpan(text: 'للمتابعة برجاء الموافقة على '), _policyLink(context)]))),
                ]),
              ),
              const SizedBox(height: 14),
              CheckboxListTile(
                value: _accepted,
                onChanged: _loading ? null : (value) => setState(() => _accepted = value ?? false),
                activeColor: AppTheme.primaryColor,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('أوافق وأتحمل كامل المسؤولية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: _accepted ? SizedBox(key: const ValueKey('continue'), height: 52, child: ElevatedButton(onPressed: _loading ? null : _continue, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('متابعة', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))) : const SizedBox.shrink(key: ValueKey('hidden'))),
            ],
          ),
        ),
      ),
    );
  }
}
