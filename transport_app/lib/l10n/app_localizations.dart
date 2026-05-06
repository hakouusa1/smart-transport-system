import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const delegate = _AppLocalizationsDelegate();

  static const supportedLocales = [
    Locale('fr'),
    Locale('en'),
    Locale('ar'),
  ];

  String _t(String fr, String en, String ar) {
    switch (locale.languageCode) {
      case 'en':
        return en;
      case 'ar':
        return ar;
      default:
        return fr;
    }
  }

  // ── Date formatting ──────────────────────────────────────────────────────
  String formatDate(DateTime dt) =>
      DateFormat('d MMM yyyy', locale.languageCode).format(dt);

  // ── Navigation ───────────────────────────────────────────────────────────
  String get navHome => _t('Accueil', 'Home', 'الرئيسية');
  String get navAlerts => _t('Alertes', 'Alerts', 'التنبيهات');
  String get navStatistics => _t('Statistiques', 'Statistics', 'الإحصائيات');
  String get navProfile => _t('Profil', 'Profile', 'الملف الشخصي');

  // ── Common ───────────────────────────────────────────────────────────────
  String get cancel => _t('Annuler', 'Cancel', 'إلغاء');
  String get save => _t('Enregistrer', 'Save', 'حفظ');
  String get emailLabel => _t('Email', 'Email', 'البريد الإلكتروني');
  String get notProvided => _t('Non renseigné', 'Not provided', 'غير متوفر');
  String get expiredLabel => _t('Expiré', 'Expired', 'منتهية الصلاحية');
  String get expiresSoon => _t('Expire bientôt', 'Expires soon', 'ينتهي قريباً');
  String get seeAll => _t('Voir tout', 'See all', 'مشاهدة الكل');

  // ── Auth ─────────────────────────────────────────────────────────────────
  String get appTagline =>
      _t('Gérez vos bus et chauffeurs', 'Manage your buses and drivers', 'إدارة حافلاتك وسائقيك');
  String get passwordLabel => _t('Mot de passe', 'Password', 'كلمة المرور');
  String get emailRequired =>
      _t('Email requis', 'Email required', 'البريد الإلكتروني مطلوب');
  String get minSixChars =>
      _t('Min 6 caractères', 'Min 6 characters', 'الحد الأدنى 6 أحرف');
  String get signIn => _t('Se connecter', 'Sign in', 'تسجيل الدخول');
  String get noAccount => _t('Pas de compte ?', 'No account?', 'ليس لديك حساب؟');
  String get createAccount =>
      _t('Créer un compte', 'Create account', 'إنشاء حساب');
  String get alreadyHaveAccount =>
      _t('Déjà un compte ?', 'Already have an account?', 'لديك حساب بالفعل؟');
  String get signInLink => _t('Se connecter', 'Sign in', 'تسجيل الدخول');
  String get fullNameRequired =>
      _t('Nom requis', 'Name required', 'الاسم مطلوب');
  String get passwordTooShort =>
      _t('Min 6 caractères', 'Min 6 characters', 'الحد الأدنى 6 أحرف');
  String get confirmPassword =>
      _t('Confirmer le mot de passe', 'Confirm password', 'تأكيد كلمة المرور');
  String get passwordsDoNotMatch =>
      _t('Les mots de passe ne correspondent pas', 'Passwords do not match', 'كلمتا المرور غير متطابقتين');
  String get registerButton => _t('S\'inscrire', 'Register', 'إنشاء الحساب');

  // ── Social sign-in & email verification ─────────────────────────────────
  String get continueWithGoogle =>
      _t('Continuer avec Google', 'Continue with Google', 'المتابعة مع Google');
  String get continueWithApple =>
      _t('Continuer avec Apple', 'Continue with Apple', 'المتابعة مع Apple');
  String get orDivider => _t('ou', 'or', 'أو');
  String get verifyEmailTitle =>
      _t('Vérifiez votre email', 'Verify your email', 'تحقق من بريدك الإلكتروني');
  String verifyEmailBody(String email) => _t(
        'Nous avons envoyé un lien de vérification à\n$email\n\nCliquez sur le lien pour activer votre compte.',
        'We sent a verification link to\n$email\n\nClick the link to activate your account.',
        'أرسلنا رابط تحقق إلى\n$email\n\nانقر على الرابط لتفعيل حسابك.',
      );
  String get resendEmail =>
      _t('Renvoyer l\'email', 'Resend email', 'إعادة إرسال البريد');
  String resendEmailCooldown(int s) =>
      _t('Renvoyer (${s}s)', 'Resend (${s}s)', 'إعادة الإرسال ($s ث)');
  String get verificationEmailSent =>
      _t('Email de vérification envoyé !', 'Verification email sent!', 'تم إرسال بريد التحقق!');
  String get emailNotYetVerified => _t(
        'Email non encore vérifié. Vérifiez votre boîte mail.',
        'Email not yet verified. Check your inbox.',
        'لم يتم التحقق من البريد بعد. تحقق من صندوق الوارد.',
      );
  String get backToSignIn =>
      _t('Retour à la connexion', 'Back to sign in', 'العودة لتسجيل الدخول');
  String get checkVerification =>
      _t('J\'ai vérifié mon email', 'I\'ve verified my email', 'لقد تحققت من بريدي');

  // ── Dashboard ────────────────────────────────────────────────────────────
   String get manageFleetTagline =>
       _t('Gérez votre flotte en toute simplicité', 'Manage your fleet with ease', 'إدارة أسطولك بكل سهولة');
   String get ownerDashboardTitle =>
       _t('Tableau de bord propriétaire', 'Owner Dashboard', 'لوحة تحكم المالك');
   String get ownerDashboardDescription =>
       _t('Gérez vos bus, suivez les revenus et surveillez les trajets en temps réel.', 'Manage your buses, track revenue, and monitor trips in real-time.', 'إدارة حافلاتك، تتبع الإيرادات، ومراقبة الرحلات في الوقت الفعلي.');
  String get busStatus => _t('Statut des bus', 'Bus status', 'حالة الحافلات');
  String get awaitingAdminApproval => _t(
    "En attente de l'approbation de l'administrateur",
    'Awaiting administrator approval',
    'في انتظار موافقة المسؤول',
  );
  String get rejectedSuffix => _t('Rejeté', 'Rejected', 'مرفوض');
  String get fixDocuments =>
      _t('Corriger les documents', 'Fix documents', 'تصحيح المستندات');
  String get busesOnTrip =>
      _t('Bus en trajet', 'Buses on trip', 'الحافلات في الرحلة');
  String get noBusesOnTrip =>
      _t('Aucun bus en trajet', 'No buses on trip', 'لا توجد حافلات في الرحلة');
  String get recentTrips =>
      _t('Derniers Trajets', 'Recent trips', 'الرحلات الأخيرة');
  String get noRecentTrips =>
      _t('Aucun trajet récent', 'No recent trips', 'لا توجد رحلات حديثة');
  String get revenueLabel => _t('Recette', 'Revenue', 'الإيرادات');
  String get todayRevenue =>
      _t("Recette aujourd'hui", "Today's revenue", 'إيرادات اليوم');
  String get profitLabel => _t('bénéfice', 'profit', 'ربح');
  String get addLabel => _t('Ajouter', 'Add', 'إضافة');
  String get fleetLabel => _t('Flotte', 'Fleet', 'الأسطول');
  String get trackLabel => _t('Suivre', 'Track', 'تتبع');
  String get chooseSubscription =>
      _t('Choisir un abonnement', 'Choose a plan', 'اختر خطة');
  String get onTrip => _t('En trajet', 'On trip', 'في الرحلة');
  String get lineValidation =>
      _t('Validation de ligne', 'Line validation', 'تحقق الخط');
  String get insurance => _t('Assurance', 'Insurance', 'التأمين');

  String busesAwaitingValidation(int n) => _t(
    '$n bus en attente de validation',
    n == 1 ? '1 bus awaiting validation' : '$n buses awaiting validation',
    '$n حافلة في انتظار التحقق',
  );

  String kmCoveredFmt(double km) => _t(
    '${km.toStringAsFixed(1)} km parcourus',
    '${km.toStringAsFixed(1)} km covered',
    '${km.toStringAsFixed(1)} كم مقطوعة',
  );

  String tripStatsFmt(double km, int n) => _t(
    '  ·  ${km.toStringAsFixed(0)} km · $n trajets',
    '  ·  ${km.toStringAsFixed(0)} km · $n trips',
    '  ·  ${km.toStringAsFixed(0)} كم · $n رحلة',
  );

  String passengersFmt(int n) =>
      _t('$n passagers', '$n passengers', '$n ركاب');

  String freeTrialCountdownFmt(String countdown) => _t(
    'Essai gratuit — $countdown',
    'Free trial — $countdown',
    'تجربة مجانية — $countdown',
  );

  String daysHoursLeftFmt(int d, int h) => _t(
    '${d}j ${h}h restants',
    '${d}d ${h}h left',
    'متبقي ${d}ي ${h}س',
  );

  String daysHoursMinutesLeftFmt(int d, int h, int m) => _t(
    "${d}J ${h.toString().padLeft(2, '0')}H ${m.toString().padLeft(2, '0')}M",
    "${d}D ${h.toString().padLeft(2, '0')}H ${m.toString().padLeft(2, '0')}M",
    "${d}ي ${h.toString().padLeft(2, '0')}س ${m.toString().padLeft(2, '0')}د",
  );

  String hoursMinutesLeftFmt(int h, int m) => _t(
    "${h}h ${m.toString().padLeft(2, '0')}m restants",
    "${h}h ${m.toString().padLeft(2, '0')}m left",
    "متبقي ${h}س ${m.toString().padLeft(2, '0')}د",
  );

  String minutesLeftFmt(int m) => _t(
    '${m}m restantes',
    '${m}m left',
    'متبقي ${m}د',
  );

  String minutesSecondsLeftFmt(int m, int s) => _t(
    "${m}m ${s.toString().padLeft(2, '0')}s restants",
    "${m}m ${s.toString().padLeft(2, '0')}s left",
    "متبقي ${m}د ${s.toString().padLeft(2, '0')}ث",
  );

  String secondsLeftFmt(int s) =>
      _t('${s}s restantes', '${s}s left', 'متبقي ${s}ث');

  // ── Profile ──────────────────────────────────────────────────────────────
  String get myProfile => _t('Mon Profil', 'My Profile', 'ملفي الشخصي');
  String get logoutTitle => _t('Déconnexion', 'Logout', 'تسجيل الخروج');
  String get logoutConfirm => _t(
    'Voulez-vous vraiment vous déconnecter ?',
    'Are you sure you want to log out?',
    'هل تريد تسجيل الخروج؟',
  );
  String get logoutAction => _t('Déconnecter', 'Log out', 'خروج');
  String get personalInfo =>
      _t('Informations personnelles', 'Personal information', 'المعلومات الشخصية');
  String get fullName => _t('Nom complet', 'Full name', 'الاسم الكامل');
  String get phone => _t('Téléphone', 'Phone', 'الهاتف');
  String get memberSince => _t('Membre depuis', 'Member since', 'عضو منذ');
  String get currentPlan => _t('Plan actuel', 'Current plan', 'الخطة الحالية');
  String get expiration => _t('Expiration', 'Expiration', 'انتهاء الصلاحية');
  String get timeRemaining =>
      _t('Temps restant', 'Time remaining', 'الوقت المتبقي');
  String get trialEndLabel =>
      _t("Fin de l'essai", 'Trial end', 'نهاية التجربة');
  String get changePassword =>
      _t('Changer le mot de passe', 'Change password', 'تغيير كلمة المرور');
  String get testAlertNotifs => _t(
    "Tester les notifications d'alertes",
    'Test alert notifications',
    'اختبار إشعارات التنبيه',
  );
  String get notificationsSent =>
      _t('Notifications envoyées', 'Notifications sent', 'تم إرسال الإشعارات');
  String get signOut =>
      _t('Se déconnecter', 'Sign out', 'تسجيل الخروج');
  String get defaultOwnerName => _t('Propriétaire', 'Owner', 'المالك');

  // ── Status labels ────────────────────────────────────────────────────────
  String get statusActive =>
      _t('Abonnement actif', 'Active subscription', 'اشتراك نشط');
  String get statusPending => _t('En attente', 'Pending', 'قيد الانتظار');
  String get statusInactive => _t('Inactif', 'Inactive', 'غير نشط');
  String get statusExpired =>
      _t('Expiré', 'Expired', 'منتهية الصلاحية');
  String get statusFreeTrial =>
      _t('Essai gratuit', 'Free trial', 'تجربة مجانية');

  String statusLabel(String status) {
    switch (status) {
      case 'active':
        return statusActive;
      case 'pending':
        return statusPending;
      case 'inactive':
        return statusInactive;
      case 'expired':
        return statusExpired;
      default:
        return statusFreeTrial;
    }
  }

  // ── Settings / Language picker ───────────────────────────────────────────
  String get settingsSection =>
      _t('Paramètres', 'Settings', 'الإعدادات');
  String get languageLabel => _t('Langue', 'Language', 'اللغة');
  String get langFrench => _t('Français', 'French', 'الفرنسية');
  String get langEnglish => _t('Anglais', 'English', 'الإنجليزية');
  String get langArabic => _t('Arabe', 'Arabic', 'العربية');

  String currentLanguageName(String code) {
    switch (code) {
      case 'en':
        return langEnglish;
      case 'ar':
        return langArabic;
      default:
        return langFrench;
    }
  }

  // ── Parameterized ────────────────────────────────────────────────────────
  String editFieldTitle(String title) =>
      _t('Modifier $title', 'Edit $title', 'تعديل $title');
  String fieldUpdatedFmt(String title) =>
      _t('$title mis à jour', '$title updated', 'تم تحديث $title');
  String daysFmt(int n) => _t('$n jours', '$n days', '$n أيام');
  String hoursFmt(int n) => _t('$n heures', '$n hours', '$n ساعات');
  String minutesFmt(int n) => _t('$n minutes', '$n minutes', '$n دقائق');
  String passwordResetSentFmt(String email) => _t(
    'Email de réinitialisation envoyé à $email',
    'Password reset email sent to $email',
    'تم إرسال بريد إعادة التعيين إلى $email',
  );
  String errorFmt(String msg) => _t('Erreur: $msg', 'Error: $msg', 'خطأ: $msg');

  // ── Alerts screen ────────────────────────────────────────────────────────
  String get alertsTitle => _t('Alertes', 'Alerts', 'التنبيهات');
  String get alertsSubtitle => _t(
    'Assurances, vidanges et salaires — du plus urgent au moins urgent',
    'Insurance, oil changes and salaries — most urgent first',
    'التأمين، تغيير الزيت والرواتب — من الأكثر إلحاحاً',
  );
  String get chipInsuranceLabel => _t('Assurances', 'Insurance', 'التأمين');
  String get chipOilChangeLabel => _t('Vidanges', 'Oil changes', 'تغيير الزيت');
  String get chipSalariesLabel => _t('Salaires', 'Salaries', 'الرواتب');
  String get addBusesForAlerts => _t(
    'Ajoutez des bus pour voir leurs alertes.',
    'Add buses to see their alerts.',
    'أضف حافلات لرؤية تنبيهاتها.',
  );
  String get noBusesFound => _t(
    'Aucun bus trouvé',
    'No buses found',
    'لم يتم العثور على حافلات',
  );
  String get addBusAction => _t(
    'Ajoutez un bus pour commencer à suivre vos alertes.',
    'Add a bus to start tracking your alerts.',
    'أضف حافلة لبدء متابعة تنبيهاتك.',
  );
  String get allBusesHealthy => _t(
    'Tous les bus sont en bon état !',
    'All buses are healthy!',
    'جميع الحافلات في حالة جيدة!',
  );
  String get noAlertsMessage => _t(
    'Aucune alerte urgente pour le moment. Votre flotte fonctionne parfaitement.',
    'No urgent alerts right now. Your fleet is running smoothly.',
    'لا توجد تنبيهات عاجلة حالياً. أسطولك يعمل بشكل ممتاز.',
  );

  // Insurance card
  String get insuranceDateUnknown => _t(
    "Date d'expiration non renseignée", 'Expiration date not set', 'تاريخ الانتهاء غير محدد');
  String get insuranceBadgeUnknown => _t('Inconnue', 'Unknown', 'غير معروف');
  String insuranceExpiredSinceFmt(int days) => _t(
    'Expirée depuis $days jour${days > 1 ? 's' : ''}',
    'Expired $days day${days > 1 ? 's' : ''} ago',
    'منتهية منذ $days يوم',
  );
  String get insuranceBadgeExpired => _t('Expirée', 'Expired', 'منتهية');
  String get insuranceExpiresToday => _t("Expire aujourd'hui !", 'Expires today!', 'تنتهي اليوم!');
  String get badgeToday => _t("Aujourd'hui", 'Today', 'اليوم');
  String insuranceExpiresFmt(String date, int days) => _t(
    'Expire le $date · dans $days j',
    'Expires $date · in ${days}d',
    'تنتهي $date · خلال $days ي',
  );
  String daysBadgeFmt(int days) => _t('$days j', '${days}d', '$days ي');
  String get insuranceLabel => _t('Assurance', 'Insurance', 'التأمين');

  // Oil change card
  String get oilChangeMileageUnknown => _t('Kilométrage non renseigné', 'Mileage not set', 'الكيلومتراج غير محدد');
  String get oilChangeBadgeUnknown => _t('Inconnu', 'Unknown', 'غير معروف');
  String oilChangeExceededFmt(int km) =>
      _t('Dépassé de $km km !', 'Exceeded by $km km!', 'تجاوز بمقدار $km كم!');
  String oilChangeExceededBadgeFmt(int km) => '+$km km';
  String get oilChangeRequiredNow =>
      _t('Vidange requise maintenant', 'Oil change required now', 'تغيير الزيت مطلوب الآن');
  String oilChangeRemainingFmt(int km) => _t(
    'Prochaine vidange dans $km km',
    'Next oil change in $km km',
    'تغيير الزيت التالي خلال $km كم',
  );
  String get oilChangeLabel => _t('Vidange', 'Oil change', 'تغيير الزيت');

  // Salary card
  String get salaryDateUnknown => _t('Date inconnue', 'Unknown date', 'تاريخ غير معروف');
  String get salaryBadgeUnknown => _t('Inconnu', 'Unknown', 'غير معروف');
  String get salaryDueToday =>
      _t("Salaire à verser aujourd'hui !", 'Salary due today!', 'الراتب مستحق اليوم!');
  String salaryScheduledFmt(String date, int days) => _t(
    'Prévu le $date · dans $days j',
    'Scheduled $date · in ${days}d',
    'مقرر $date · خلال $days ي',
  );
  String get driverLabel => _t('Chauffeur', 'Driver', 'سائق');
  String get collectorLabel => _t('Receveur', 'Collector', 'محصّل');
  String salaryLabelFmt(String positions) =>
      _t('Salaires: $positions', 'Salaries: $positions', 'الرواتب: $positions');

  // ── Statistics screen ────────────────────────────────────────────────────
  String get statisticsTitle =>
      _t('Statistiques', 'Statistics', 'الإحصائيات');
  String get filterByBus =>
      _t('Filtrer par bus:', 'Filter by bus:', 'تصفية حسب الحافلة:');
  String get allBuses => _t('Tous les bus', 'All buses', 'جميع الحافلات');
  String get totalRevenue =>
      _t('Recette totale', 'Total revenue', 'إجمالي الإيرادات');
  String get netProfit => _t('Bénéfice net', 'Net profit', 'صافي الربح');
  String get totalTrips => _t('Trajets', 'Trips', 'الرحلات');
  String get distanceLabel => _t('Distance', 'Distance', 'المسافة');
  String get fuelLabel => _t('Carburant', 'Fuel', 'الوقود');
  String tripDetailsFmt(int n) => _t(
    'Détail des trajets ($n)', 'Trip details ($n)', 'تفاصيل الرحلات ($n)');
  String get noTripsForPeriod => _t(
    'Aucun trajet pour cette période',
    'No trips for this period',
    'لا توجد رحلات لهذه الفترة',
  );
  String get loadMore => _t('Charger plus', 'Load more', 'تحميل المزيد');
  String get noMoreTrips => _t(
    'Tous les trajets sont affichés',
    'All trips displayed',
    'تم عرض جميع الرحلات',
  );
  String get loading => _t('Chargement…', 'Loading…', 'جارٍ التحميل…');
  String driverSalaryMonthlyFmt(int n) => _t(
    'Salaire chauffeur (÷30 / $n)',
    'Driver salary (÷30 / $n)',
    'راتب السائق (÷30 / $n)',
  );
  String get driverSalaryPerTrip => _t(
    'Salaire chauffeur (par trajet)',
    'Driver salary (per trip)',
    'راتب السائق (لكل رحلة)',
  );
  String collectorSalaryMonthlyFmt(int n) => _t(
    'Salaire receveur (÷30 / $n)',
    'Collector salary (÷30 / $n)',
    'راتب المحصّل (÷30 / $n)',
  );
  String get collectorSalaryPerTrip => _t(
    'Salaire receveur (par trajet)',
    'Collector salary (per trip)',
    'راتب المحصّل (لكل رحلة)',
  );
  String get estimatedFuel =>
      _t('Carburant estimé', 'Estimated fuel', 'الوقود المقدر');
  String get totalKm => _t('Kilomètres', 'Kilometres', 'الكيلومترات');
  String get totalProfit => _t('Bénéfice', 'Profit', 'الربح');
  String get perBusStats => _t('Par bus', 'Per bus', 'لكل حافلة');
  String get weekly => _t('Semaine', 'Week', 'الأسبوع');
  String get monthly => _t('Mois', 'Month', 'الشهر');

  // ── Bus list / Add bus ───────────────────────────────────────────────────
  String get myFleet => _t('Ma Flotte', 'My Fleet', 'أسطولي');
  String get addBus => _t('Ajouter un bus', 'Add a bus', 'إضافة حافلة');
  String get busName => _t('Nom du bus', 'Bus name', 'اسم الحافلة');
  String get busNumber => _t('Numéro', 'Number', 'الرقم');
  String get noBuses =>
      _t('Aucun bus enregistré', 'No buses registered', 'لا توجد حافلات مسجلة');
  String get validationPending =>
      _t('En attente de validation', 'Awaiting validation', 'في انتظار التحقق');
  String get validationApproved =>
      _t('Approuvé', 'Approved', 'مُعتمد');
  String get validationRejected =>
      _t('Rejeté', 'Rejected', 'مرفوض');
  String planLimitExceededFmt(int current, int limit, String plan) => _t(
    'Vous avez $current bus, mais le plan $plan permet $limit maximum.',
    'You have $current buses, but the $plan plan allows $limit maximum.',
    'لديك $current حافلة، لكن خطة $plan تسمح بـ $limit كحد أقصى.',
  );
  String get planLimitExceededAction => _t(
    'Passez à un forfait supérieur pour continuer à gérer tous vos bus.',
    'Upgrade your plan to continue managing all your buses.',
    'قم بترقية خطتك لمتابعة إدارة جميع حافلاتك.',
  );

  // ── Subscription / Pending ───────────────────────────────────────────────
  String get subscriptionTitle =>
      _t('Abonnement', 'Subscription', 'الاشتراك');
  String get pendingApproval =>
      _t('En attente d\'approbation', 'Pending approval', 'في انتظار الموافقة');
  String get subscribeNow =>
      _t('S\'abonner maintenant', 'Subscribe now', 'اشترك الآن');
  String get perMonth => _t('/ mois', '/ month', '/ شهر');

  // ── General form ─────────────────────────────────────────────────────────
  String get fieldRequired => _t('Champ requis', 'Required', 'مطلوب');
  String get invalidNumber => _t('Nombre invalide', 'Invalid number', 'رقم غير صالح');
  String get invalidEmail => _t('Email invalide', 'Invalid email', 'بريد إلكتروني غير صالح');
  String get retry => _t('Réessayer', 'Retry', 'إعادة المحاولة');
  String get copied => _t('Copié !', 'Copied!', 'تم النسخ!');
  String get perMonthLabel => _t('Par mois', 'Per month', 'شهرياً');
  String get perTripLabel => _t('Par trajet', 'Per trip', 'لكل رحلة');
  String get unknownBus => _t('Bus inconnu', 'Unknown bus', 'حافلة غير معروفة');

  // ── Add / Edit bus screen ────────────────────────────────────────────────
  String get editBus => _t('Modifier le bus', 'Edit bus', 'تعديل الحافلة');
  String get busInfoSection =>
      _t('Informations du bus', 'Bus information', 'معلومات الحافلة');
  String get busNameHint => _t('Ex: Bus A1', 'e.g. Bus A1', 'مثال: Bus A1');
  String get busNumberHint =>
      _t('Ex: 00125-114-16', 'e.g. 00125-114-16', 'مثال: 00125-114-16');
  String get dailyTripsSection =>
      _t('Trajets journaliers', 'Daily trips', 'الرحلات اليومية');
  String tripsPerDayFmt(int n) => _t(
    '$n trajet${n > 1 ? "s" : ""} / jour',
    '$n trip${n > 1 ? "s" : ""} / day',
    '$n رحلة / يوم',
  );
  String tripScheduleRowFmt(int n, String time) => _t(
    'Trajet $n — $time',
    'Trip $n — $time',
    'الرحلة $n — $time',
  );
  String get tripTimeNotSet => _t('Non définie', 'Not set', 'غير محددة');
  String get busActiveSwitchTitle =>
      _t('Bus actif', 'Bus active', 'الحافلة نشطة');
  String get busActiveSubtitle =>
      _t('Le bus est en service', 'Bus in service', 'الحافلة في الخدمة');
  String get busInactiveSubtitle =>
      _t('Le bus est hors service', 'Bus out of service', 'الحافلة خارج الخدمة');
  String get currentKmLabel =>
      _t('Kilométrage actuel du bus', 'Current bus mileage', 'الكيلومتراج الحالي للحافلة');
  String get currentKmHint => _t('Ex: 142000', 'e.g. 142000', 'مثال: 142000');
  String get busWeightLabel =>
      _t('Poids du bus (kg)', 'Bus weight (kg)', 'وزن الحافلة (كغ)');
  String get busWeightHint => _t('Ex: 12000', 'e.g. 12000', 'مثال: 12000');
  String get routeSectionTitle => _t('Trajet', 'Route', 'المسار');
  String get routeSectionSubtitle => _t(
    "Wilaya de départ et d'arrivée",
    'Departure and arrival wilaya',
    'ولاية المغادرة والوصول',
  );
  String get departureWilaya =>
      _t('Wilaya de départ', 'Departure wilaya', 'ولاية المغادرة');
  String get arrivalWilaya =>
      _t("Wilaya d'arrivée", 'Arrival wilaya', 'ولاية الوصول');
  String get chooseDepartureWilaya =>
      _t('Choisir la wilaya de départ', 'Choose departure wilaya', 'اختر ولاية المغادرة');
  String get chooseArrivalWilaya =>
      _t("Choisir la wilaya d'arrivée", 'Choose arrival wilaya', 'اختر ولاية الوصول');
  String get searchWilayaHint =>
      _t('Rechercher une wilaya...', 'Search wilaya...', 'البحث عن ولاية...');
  String get driverAccountSection =>
      _t('Compte chauffeur', 'Driver account', 'حساب السائق');
  String get driverAccountSubtitle => _t(
    'Le chauffeur utilisera ces identifiants pour se connecter',
    'The driver will use these credentials to sign in',
    'سيستخدم السائق هذه البيانات لتسجيل الدخول',
  );
  String get driverEmailFieldLabel =>
      _t('Email du chauffeur *', 'Driver email *', 'بريد السائق الإلكتروني *');
  String get driverEmailHint => _t(
    'Ex: chauffeur1@transport.com',
    'e.g. driver1@transport.com',
    'مثال: chauffeur1@transport.com',
  );
  String get driverPasswordFieldLabel =>
      _t('Mot de passe du chauffeur *', 'Driver password *', 'كلمة مرور السائق *');
  String get driverSalarySection =>
      _t('Salaire du chauffeur', 'Driver salary', 'راتب السائق');
  String get chauffeurSalaryMonthlyFieldLabel => _t(
    'Salaire du chauffeur (par mois)',
    'Driver salary (per month)',
    'راتب السائق (شهرياً)',
  );
  String get chauffeurSalaryPerTripFieldLabel => _t(
    'Salaire du chauffeur (par trajet)',
    'Driver salary (per trip)',
    'راتب السائق (لكل رحلة)',
  );
  String get salaryHint => _t('Ex: 50000', 'e.g. 50000', 'مثال: 50000');
  String get collectorShareSection =>
      _t('Part du receveur', "Collector's share", 'حصة المحصّل');
  String get collectorShareMonthlyLabel => _t(
    'Part du receveur (par mois)',
    'Collector share (per month)',
    'حصة المحصّل (شهرياً)',
  );
  String get collectorSharePerTripLabel => _t(
    'Part du receveur (par trajet)',
    'Collector share (per trip)',
    'حصة المحصّل (لكل رحلة)',
  );
  String get collectorShareHint =>
      _t('Ex: 15000', 'e.g. 15000', 'مثال: 15000');
  String get shareCredentialsWithDriver => _t(
    'Communiquez cet email et mot de passe au chauffeur.',
    'Share this email and password with the driver.',
    'أرسل هذا البريد الإلكتروني وكلمة المرور إلى السائق.',
  );
  String get requiredDocsSection =>
      _t('Documents obligatoires', 'Required documents', 'الوثائق الإلزامية');
  String get requiredDocsSectionSubtitle => _t(
    "Ces documents seront vérifiés par l'administrateur",
    'These documents will be verified by the administrator',
    'ستتحقق الإدارة من هذه الوثائق',
  );
  String get selectSourceTitle =>
      _t('Sélectionner une source', 'Select a source', 'اختر المصدر');
  String get takePhotoOption =>
      _t('Prendre une photo', 'Take a photo', 'التقاط صورة');
  String get selectFromGalleryOption =>
      _t('Sélectionner depuis la galerie', 'Select from gallery', 'اختر من المعرض');
  String get documentPickerHint => _t(
    'Appuyez pour prendre une photo ou sélectionner depuis la galerie',
    'Tap to take a photo or select from gallery',
    'اضغط لالتقاط صورة أو الاختيار من المعرض',
  );
  String get insuranceExpiryOptional => _t(
    "Date d'expiration de l'assurance (optionnel)",
    'Insurance expiry date (optional)',
    'تاريخ انتهاء التأمين (اختياري)',
  );
  String insuranceExpirySelectedFmt(String date) => _t(
    'Expiration assurance : $date',
    'Insurance expiry: $date',
    'انتهاء التأمين: $date',
  );
  String get lastOilChangeSectionTitle => _t(
    'Dernière vidange (optionnel)',
    'Last oil change (optional)',
    'آخر تغيير زيت (اختياري)',
  );
  String get oilChangeDateHint =>
      _t('Choisir la date de vidange', 'Choose oil change date', 'اختر تاريخ تغيير الزيت');
  String get oilChangeKmLabel =>
      _t('Kilométrage à la vidange', 'Mileage at oil change', 'الكيلومتراج عند تغيير الزيت');
  String get oilChangeKmHint =>
      _t('Ex: 125000', 'e.g. 125000', 'مثال: 125000');
  String get uploadingLabel => _t('Upload en cours...', 'Uploading...', 'جارٍ الرفع...');
  String get creatingBusLabel => _t('Création...', 'Creating...', 'جارٍ الإنشاء...');
  String get saveChangesButton =>
      _t('Enregistrer les modifications', 'Save changes', 'حفظ التعديلات');
  String get createBusAndDriverButton => _t(
    'Créer le bus et le compte chauffeur',
    'Create bus and driver account',
    'إنشاء الحافلة وحساب السائق',
  );
  String get errorAtLeastOneTripSchedule => _t(
    'Veuillez définir au moins un horaire de trajet.',
    'Please set at least one trip schedule.',
    'يرجى تحديد وقت رحلة واحدة على الأقل.',
  );
  String get errorLineValidationRequired => _t(
    'La validation de ligne est requise',
    'Line validation is required',
    'التحقق من الخط مطلوب',
  );
  String get errorInsuranceRequired => _t(
    "L'assurance est requise",
    'Insurance document is required',
    'وثيقة التأمين مطلوبة',
  );
  String get successBusUpdated =>
      _t('Bus mis à jour avec succès !', 'Bus updated successfully!', 'تم تحديث الحافلة بنجاح!');
  String successBusCreatedFmt(String email) => _t(
    "Bus créé ! En attente de validation par l'administrateur.\nChauffeur: $email",
    "Bus created! Awaiting administrator validation.\nDriver: $email",
    "تم إنشاء الحافلة! في انتظار موافقة المسؤول.\nالسائق: $email",
  );
  String get errorNotLoggedIn =>
      _t("Vous n'êtes pas connecté.", 'You are not logged in.', 'أنت غير مسجل الدخول.');
  String errorBusLimitFmt(String plan, int limit) => _t(
    'Limite atteinte : le forfait $plan permet $limit bus maximum. '
        'Passez à un forfait supérieur pour ajouter plus de bus.',
    'Limit reached: the $plan plan allows $limit buses maximum. '
        'Upgrade your plan to add more buses.',
    'تم الوصول للحد الأقصى: خطة $plan تسمح بـ $limit حافلة كحد أقصى. '
        'قم بترقية خطتك لإضافة المزيد من الحافلات.',
  );
  String get errorEmailAlreadyInUse => _t(
    'Cet email est déjà utilisé.',
    'This email is already in use.',
    'هذا البريد الإلكتروني مستخدم بالفعل.',
  );
  String get errorWeakPassword =>
      _t('Mot de passe trop faible.', 'Password is too weak.', 'كلمة المرور ضعيفة جداً.');
  String errorBusCreationFmt(String msg) => _t(
    'Erreur création bus: $msg',
    'Bus creation error: $msg',
    'خطأ في إنشاء الحافلة: $msg',
  );

  // ── Subscription screen ──────────────────────────────────────────────────
  String get planIncludesLabel =>
      _t('Inclus dans votre plan :', 'Included in your plan:', 'مضمّن في خطتك:');
  String get ccpAccountLabel => _t('Compte CCP', 'CCP Account', 'حساب CCP');
  String get baridimobRipLabel =>
      _t('BaridiMob (RIP)', 'BaridiMob (RIP)', 'BaridiMob (RIP)');
  String get sendReceiptTo =>
      _t('Envoyez le reçu à', 'Send receipt to', 'أرسل الإيصال إلى');
  String get iSentReceipt =>
      _t("J'ai envoyé le reçu", 'I sent the receipt', 'لقد أرسلت الإيصال');
  String get confirmDialogTitle => _t('Confirmer', 'Confirm', 'تأكيد');
  String get confirmReceiptSentQuestion => _t(
    'Avez-vous bien envoyé le reçu de paiement par email ?',
    'Have you sent the payment receipt by email?',
    'هل أرسلت إيصال الدفع بالبريد الإلكتروني؟',
  );
  String get notYetButton => _t('Non, pas encore', 'Not yet', 'ليس بعد');
  String get yesSentButton =>
      _t("Oui, j'ai envoyé", "Yes, I've sent it", 'نعم، لقد أرسلته');
  String planNameFmt(String name) => _t('Plan $name', 'Plan $name', 'خطة $name');
  String get pendingVerificationTitle =>
      _t('En attente de vérification', 'Awaiting verification', 'في انتظار التحقق');
  String get pendingVerificationBody => _t(
    'Votre paiement est en cours de vérification.\nCela peut prendre entre 1 et 3 jours.',
    'Your payment is being verified.\nThis may take 1 to 3 days.',
    'جارٍ التحقق من دفعتك.\nقد يستغرق ذلك من 1 إلى 3 أيام.',
  );
  String get pendingVerificationChangePlanBody => _t(
    'Votre demande de changement de plan est en cours de vérification.\nVous pouvez continuer à utiliser votre plan actuel en attendant.\nL\'administrateur approuvera votre abonnement dans 1 à 3 jours.',
    'Your plan change request is being verified.\nYou can continue using your current plan in the meantime.\nThe admin will approve your subscription within 1 to 3 days.',
    'جارٍ التحقق من طلب تغيير خطتك.\nيمكنك الاستمرار في استخدام خطتك الحالية في هذه الأثناء.\nسيوافق المسؤول على اشتراكك خلال 1 إلى 3 أيام.',
  );
  String get goToHome => _t('Retour à l\'accueil', 'Go to home', 'العودة للرئيسية');
  String get checkStatusButton =>
      _t('Vérifier le statut', 'Check status', 'التحقق من الحالة');
  String get paymentRejectedTitle =>
      _t('Paiement rejeté', 'Payment rejected', 'تم رفض الدفعة');
  String get paymentRejectedBody => _t(
    'Votre paiement a été rejeté.\nVeuillez réessayer avec un nouveau reçu.',
    'Your payment was rejected.\nPlease try again with a new receipt.',
    'تم رفض دفعتك.\nيرجى المحاولة مجدداً بإيصال جديد.',
  );
  String get rejectionReasonLabel => _t(
    'Motif du rejet :',
    'Reason for rejection:',
    'سبب الرفض:',
  );
  String get rejectionReasonFallback => _t(
    'Aucune raison spécifique fournie. Veuillez contacter le support pour plus de détails.',
    'No specific reason provided. Please contact support for details.',
    'لم يُذكر سبب محدد. يرجى التواصل مع الدعم للمزيد.',
  );

  // ── Change Plan ──────────────────────────────────────────────────────────
  String get changePlan => _t('Changer de plan', 'Change Plan', 'تغيير الخطة');
  String get changePlanSubtitle => _t(
    'Sélectionnez votre nouveau plan',
    'Select your new plan',
    'اختر خطتك الجديدة',
  );
  String get changePlanInfo => _t(
    'Votre plan actuel reste actif jusqu\'à l\'approbation du nouveau paiement.',
    'Your current plan stays active until the new payment is approved.',
    'تظل خطتك الحالية نشطة حتى الموافقة على الدفع الجديد.',
  );
  String get selectThisPlan => _t('Choisir ce plan', 'Select this plan', 'اختر هذه الخطة');
  String get recommendedLabel => _t('Recommandé', 'Recommended', 'موصى به');

  // ── Subscription History ──────────────────────────────────────────────────
  String get subscriptionHistory => _t('Historique des abonnements', 'Subscription History', 'سجل الاشتراكات');
  String get noHistoryFound => _t('Aucun historique trouvé.', 'No history found.', 'لم يتم العثور على سجل.');
  String get paymentStatusPending => _t('En attente', 'Pending', 'قيد الانتظار');
  String get paymentStatusApproved => _t('Approuvé', 'Approved', 'مقبول');
  String get paymentStatusRejected => _t('Rejeté', 'Rejected', 'مرفوض');
  String refNumberLabel(String ref) => _t('Réf: $ref', 'Ref: $ref', 'مرجع: $ref');
  String requestedOn(String date) => _t('Demandé le $date', 'Requested on $date', 'طلب في $date');

  // ── Receipt upload ──────────────────────────────────────────────────────
  String get uploadReceipt => _t(
    'Téléverser le reçu',
    'Upload Receipt',
    'رفع الإيصال',
  );
  String get selectReceiptImage => _t(
    'Sélectionner le reçu',
    'Select Receipt',
    'اختيار الإيصال',
  );
  String get receiptSelected => _t(
    'Reçu sélectionné',
    'Receipt selected',
    'تم اختيار الإيصال',
  );
  String get uploadReceiptRequired => _t(
    'Un reçu est requis',
    'Upload receipt required',
    'إيصال الدفع مطلوب',
  );
  String get refNumberHint => _t(
    'N° de transaction ou de référence',
    'Transaction or reference number',
    'رقم المعاملة أو المرجع',
  );
  String get tooManyRequests => _t(
    'Trop de demandes soumises. Veuillez contacter le support.',
    'Too many requests submitted. Please contact support.',
    'تم تقديم طلبات كثيرة جدًا. يرجى الاتصال بالدعم.',
  );
  String get receiptUploaded => _t(
    'Reçu téléversé avec succès',
    'Receipt uploaded successfully',
    'تم رفع الإيصال بنجاح',
  );
  String get uploadingReceipt => _t(
    'Téléversement du reçu en cours...',
    'Uploading receipt...',
    'جارٍ رفع الإيصال...',
  );
  String get uploadError => _t(
    'Erreur lors du téléversement du reçu',
    'Error uploading receipt',
    'خطأ في رفع الإيصال',
  );
  String get tapToChangeReceipt => _t(
    'Appuyez pour changer',
    'Tap to change',
    'اضغط للتغيير',
  );
  String get confirmReceiptUploadQuestion => _t(
    'Avez-vous bien effectué le paiement ? Le reçu sera envoyé automatiquement.',
    'Have you completed the payment? The receipt will be sent automatically.',
    'هل أتممت الدفع؟ سيتم إرسال الإيصال تلقائياً.',
  );

  // ── Dashboard — trip detail labels ───────────────────────────────────────
  String get tripDetailHour => _t('Heure', 'Time', 'الوقت');
  String get tripDetailBus => _t('Bus', 'Bus', 'الحافلة');
  String get tripDetailDuration => _t('Durée', 'Duration', 'المدة');
  String get tripDetailRoute => _t('Trajet', 'Route', 'المسار');

  // ── Owner Management ─────────────────────────────────────────────────────
  String get ownerManagementSection => _t('Gestion Propriétaire', 'Owner Management', 'إدارة المالك');
  String get ownerManagementSubtitle => _t('Mettre à jour les identifiants du chauffeur', 'Update driver credentials', 'تحديث بيانات السائق');
  String get updateCredentialsButton => _t('Mettre à jour les identifiants', 'Update credentials', 'تحديث البيانات');
  String get reassignConfirmTitle => _t('Confirmer le changement', 'Confirm change', 'تأكيد التغيير');
  String get reassignConfirmMessage => _t(
    'Cela changera les identifiants de connexion pour ce bus. Le chauffeur précédent perdra l\'accès. Continuer ?', 
    'This will change the login credentials for this bus. The previous driver will lose access. Continue?', 
    'سيؤدي هذا إلى تغيير بيانات تسجيل الدخول لهذه الحافلة. سيفقد السائق السابق إمكانية الوصول. هل تريد الاستمرار؟'
  );
  String get successCredentialsUpdated => _t('Identifiants mis à jour avec succès', 'Credentials updated successfully', 'تم تحديث البيانات بنجاح');

  // ── Bus creation success dialog ──────────────────────────────────────────
  String get busCreatedSuccess => _t(
    'Bus créé avec succès !',
    'Bus created successfully!',
    'تم إنشاء الحافلة بنجاح!',
  );
  String get busCreatedDialogSubtitle => _t(
    'En attente de validation par l\'administrateur. Partagez ces identifiants avec le chauffeur.',
    'Awaiting administrator validation. Share these credentials with the driver.',
    'في انتظار موافقة المسؤول. شارك هذه البيانات مع السائق.',
  );
  String get driverEmailDialogLabel => _t('Email du chauffeur', 'Driver Email', 'بريد السائق');
  String get temporaryPasswordLabel => _t('Mot de passe temporaire', 'Temporary Password', 'كلمة المرور المؤقتة');
  String get busIdDialogLabel => _t('Nom du bus', 'Bus Name', 'اسم الحافلة');
  String get copyCredentials => _t(
    'Copier les identifiants',
    'Copy Credentials',
    'نسخ البيانات',
  );
  String get credentialsCopied => _t(
    'Identifiants copiés dans le presse-papier !',
    'Credentials copied to clipboard!',
    'تم نسخ البيانات إلى الحافظة!',
  );
  String get closeLabel => _t('Fermer', 'Close', 'إغلاق');

  // ── Trip detail screen ───────────────────────────────────────────────────
  String get tripDetailTitle =>
      _t('Détail du trajet', 'Trip detail', 'تفاصيل الرحلة');
  String get revenueEnteredByDriver => _t(
    'Cette recette a été saisie par le chauffeur à la fin du trajet.',
    'This revenue was entered by the driver at the end of the trip.',
    'تم إدخال هذا الإيراد من قِبل السائق عند انتهاء الرحلة.',
  );
  String get tripDetailDriverName =>
      _t('Nom du chauffeur', 'Driver name', 'اسم السائق');
  String get tripDetailDriverId =>
      _t('Identifiant', 'Identifier', 'المعرّف');
  String get loadingLabel => _t('Chargement…', 'Loading…', 'جارٍ التحميل…');
  String get unknownDriver =>
      _t('Chauffeur inconnu', 'Unknown driver', 'سائق غير معروف');
  String get tripDetailTimeSection =>
      _t('Horaires', 'Schedule', 'المواعيد');
  String get tripDetailDeparture =>
      _t('Heure de départ', 'Departure time', 'وقت المغادرة');
  String get tripDetailArrival =>
      _t('Heure d\'arrivée', 'Arrival time', 'وقت الوصول');
  String get tripDetailRouteSection =>
      _t('Itinéraire', 'Route', 'المسار');
  String get tripDetailFuelCost =>
      _t('Coût carburant', 'Fuel cost', 'تكلفة الوقود');
  String get tripDetailFuelLiters =>
      _t('Consommation', 'Consumption', 'الاستهلاك');

  // ── Delete bus confirmation dialog ────────────────────────────────────────
  String deleteBusConfirmTitle(String busName) => _t(
    'Supprimer "$busName" ?',
    'Delete "$busName"?',
    'حذف "$busName"؟',
  );
  String get deleteBusWarning => _t(
    'Cette action est irréversible. Tout l\'historique des trajets associé à ce bus sera supprimé.',
    'This action cannot be undone. All trip history associated with this bus will be deleted.',
    'لا يمكن التراجع عن هذا الإجراء. سيتم حذف كل سجل الرحلات المرتبط بهذه الحافلة.',
  );
  String get deleteLabel => _t('Supprimer', 'Delete', 'حذف');
  String busDeletedFmt(String busName) => _t(
    '"$busName" a été supprimé',
    '"$busName" has been deleted',
    'تم حذف "$busName"',
  );

  // ── App Settings (Fleet Economics) ───────────────────────────────────────
  String get appSettingsTitle =>
      _t('Économie du transport', 'Fleet Economics', 'اقتصاديات الأسطول');
  String get fuelPriceLabel =>
      _t('Prix carburant (DA/L)', 'Fuel price (DA/L)', 'سعر الوقود (دج/ل)');
  String get vidangeIntervalLabel =>
      _t('Intervalle vidange (km)', 'Oil change interval (km)', 'فاصل تغيير الزيت (كم)');
  String get fuelConsumptionLabel =>
      _t('Consommation (L/100km)', 'Consumption (L/100km)', 'الاستهلاك (ل/100كم)');
  String get settingsSaved =>
      _t('Paramètre mis à jour', 'Setting updated', 'تم تحديث الإعداد');
  String get editSettingTitle =>
      _t('Modifier', 'Edit', 'تعديل');

  // ── Plan bus-limit warning (before selecting a plan) ─────────────────────
  String get planBusLimitWarningTitle => _t(
    'Limite de bus dépassée',
    'Bus limit exceeded',
    'تجاوز حد الحافلات',
  );
  String planBusLimitWarningBody(int current, int max, int excess) => _t(
    'Vous avez $current bus, mais ce plan n\'en autorise que $max. '
    'Vous devrez supprimer $excess bus${excess > 1 ? '' : ''} pour accéder à l\'application.',
    'You have $current buses, but this plan only allows $max. '
    'You will need to delete ${excess > 1 ? '$excess buses' : '1 bus'} to access the app.',
    'لديك $current حافلة، لكن هذه الخطة تسمح بـ $max فقط. '
    'ستحتاج إلى حذف $excess حافلة للمتابعة.',
  );
  String get continueAnyway => _t(
    'Continuer quand même',
    'Continue anyway',
    'المتابعة على أي حال',
  );

  // ── Reduce buses screen ───────────────────────────────────────────────────
  String reduceBusesTitle(String planName, int limit) => _t(
    'Plan $planName — max $limit bus',
    '$planName plan — max $limit ${limit > 1 ? 'buses' : 'bus'}',
    'خطة $planName — الحد الأقصى $limit حافلة',
  );
  String reduceBusesSubtitle(int excess) => _t(
    'Supprimez $excess bus${excess > 1 ? '' : ''} pour accéder à l\'application.',
    'Delete ${excess > 1 ? '$excess buses' : '1 bus'} to access the app.',
    'احذف $excess حافلة للوصول إلى التطبيق.',
  );
  String get reduceBusesCompleted => _t(
    'Flotte conforme — vous pouvez continuer !',
    'Fleet compliant — you can continue!',
    'الأسطول ممتثل — يمكنك المتابعة!',
  );
  String get continueToApp => _t(
    "Accéder à l'application",
    'Continue to app',
    'الدخول إلى التطبيق',
  );
  String busesToRemoveFmt(int n) => _t(
    '$n bus à supprimer',
    n == 1 ? '1 bus to remove' : '$n buses to remove',
    '$n حافلة للحذف',
  );
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['fr', 'en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
