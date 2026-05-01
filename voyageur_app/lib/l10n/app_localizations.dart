import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LANGUAGE ENUM — used only by UI pickers for display (label, flag)
// ─────────────────────────────────────────────────────────────────────────────
enum AppLanguage {
  fr('fr', 'Français', '🇫🇷'),
  en('en', 'English', '🇬🇧'),
  ar('ar', 'العربية', '🇩🇿');

  final String code;
  final String label;
  final String flag;
  const AppLanguage(this.code, this.label, this.flag);

  static AppLanguage fromCode(String code) => AppLanguage.values.firstWhere(
        (l) => l.code == code,
        orElse: () => AppLanguage.fr,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// EXTENSION — easy access from any widget via context.tr
// ─────────────────────────────────────────────────────────────────────────────
extension AppLocalizationsX on BuildContext {
  AppLocalizations get tr => AppLocalizations.of(this);
  bool get isRtl => Localizations.localeOf(this).languageCode == 'ar';
}

// ─────────────────────────────────────────────────────────────────────────────
// APP LOCALIZATIONS
// ─────────────────────────────────────────────────────────────────────────────
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

  // ── Helpers ──────────────────────────────────────────────────────────────
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
  String formatDate(DateTime date) =>
      DateFormat('d MMM yyyy', locale.languageCode).format(date);

  // ═══════════════════════════════════════════════════
  // GENERAL
  // ═══════════════════════════════════════════════════
  String get appTitle => _t('Voyageur', 'Voyageur', 'Voyageur');
  String get cancel => _t('Annuler', 'Cancel', 'إلغاء');
  String get confirm => _t('Confirmer', 'Confirm', 'تأكيد');
  String get error => _t('Erreur', 'Error', 'خطأ');
  String get loading => _t('Chargement...', 'Loading...', 'جاري التحميل...');
  String get save => _t('Enregistrer', 'Save', 'حفظ');
  String get ok => _t('OK', 'OK', 'حسناً');

  // ═══════════════════════════════════════════════════
  // AUTH — Login
  // ═══════════════════════════════════════════════════
   String get loginSubtitle => _t(
        'Voyageur — Suivez vos bus en temps réel',
        'Voyageur — Track your buses in real time',
        'Voyageur — تتبع حافلاتك في الوقت الفعلي',
      );
   String get appTagline => _t(
        'Voyagez plus intelligemment, pas plus dur',
        'Travel smarter, not harder',
        'سافر بذكاء، لا بجهد',
      );
   String get appDescription => _t(
        'Découvrez rapidement les itinéraires disponibles, réservez votre place et déplacez-vous en toute confiance.',
        'Quickly discover available routes, reserve your spot, and move with confidence.',
        'اكتشف الطرق المتاحة بسرعة، احجز مكانك، وتحرك بثقة.',
      );
   String get email => _t('Email', 'Email', 'البريد الإلكتروني');
  String get emailHint =>
      _t('voyageur@email.com', 'voyageur@email.com', 'voyageur@email.com');
  String get emailRequired =>
      _t('Email requis', 'Email required', 'البريد الإلكتروني مطلوب');
  String get emailInvalid =>
      _t('Email invalide', 'Invalid email', 'بريد إلكتروني غير صالح');
  String get password => _t('Mot de passe', 'Password', 'كلمة المرور');
  String get passwordHint => _t('••••••', '••••••', '••••••');
  String get passwordMin6 =>
      _t('Min 6 caractères', 'Min 6 characters', '6 أحرف على الأقل');
  String get signIn => _t('Se connecter', 'Sign in', 'تسجيل الدخول');
  String get noAccount =>
      _t('Pas de compte ? ', "Don't have an account? ", 'ليس لديك حساب؟ ');
  String get createAccount =>
      _t('Créer un compte', 'Create account', 'إنشاء حساب');

  // ═══════════════════════════════════════════════════
  // AUTH — Register
  // ═══════════════════════════════════════════════════
  String get registerTitle =>
      _t('Créer un compte', 'Create account', 'إنشاء حساب');
  String get registerSubtitle => _t(
        'Rejoignez-nous pour suivre vos bus',
        'Join us to track your buses',
        'انضم إلينا لتتبع حافلاتك',
      );
  String get fullName => _t('Nom complet', 'Full name', 'الاسم الكامل');
  String get fullNameHint =>
      _t('Ex: Sara Benali', 'e.g. Sara Benali', 'مثال: سارة بن علي');
  String get nameRequired =>
      _t('Nom requis', 'Name required', 'الاسم مطلوب');
  String get confirmPassword => _t('Confirmer', 'Confirm', 'تأكيد');
  String get passwordsNoMatch => _t(
        'Les mots de passe ne correspondent pas',
        'Passwords do not match',
        'كلمات المرور غير متطابقة',
      );
  String get createMyAccount =>
      _t('Créer mon compte', 'Create my account', 'إنشاء حسابي');

  // ═══════════════════════════════════════════════════
  // AUTH — Role errors
  // ═══════════════════════════════════════════════════
  String get accountNotFound => _t(
        'Compte non trouvé. Veuillez vous inscrire.',
        'Account not found. Please register.',
        'الحساب غير موجود. يرجى التسجيل.',
      );
  String get accountVerificationError => _t(
        'Erreur de vérification du compte.',
        'Account verification error.',
        'خطأ في التحقق من الحساب.',
      );
  String roleError(String roleName) => _t(
        'Ce compte est un compte $roleName.\nVeuillez utiliser l\'application correspondante.',
        'This account is a $roleName account.\nPlease use the corresponding app.',
        'هذا الحساب هو حساب $roleName.\nيرجى استخدام التطبيق المناسب.',
      );
  String roleName(String role) {
    final map = {
      'owner': _t('propriétaire', 'owner', 'مالك'),
      'driver': _t('chauffeur', 'driver', 'سائق'),
    };
    return map[role] ?? role;
  }

  // ═══════════════════════════════════════════════════
  // BUS LINES SCREEN
  // ═══════════════════════════════════════════════════
  String get searchPlaceholder =>
      _t('Où allez-vous ?', 'Where are you going?', 'إلى أين تذهب؟');
  String get searchLabel => _t('Rechercher', 'Search', 'بحث');
  String busesActive(int count) =>
      _t('$count bus actifs', '$count active buses', '$count حافلات نشطة');
  String busesOnTrip(int count) =>
      _t('$count en trajet', '$count on trip', '$count في رحلة');
  String get onTrip => _t('En trajet', 'On trip', 'في رحلة');
  String get onTripDesc => _t('Ces bus sont actuellement en route', 'These buses are currently on the road', 'هذه الحافلات في الطريق حاليًا');
  String get online => _t('Les prochains trajets', 'Upcoming trips', 'الرحلات القادمة');
  String get onlineDesc => _t('Buses disponibles et prêts à partir', 'Buses available and ready to depart', 'الحافلات المتاحة والجاهزة للانطلاق');
  String get offline => _t('Hors ligne', 'Offline', 'غير متصل');
  String get noBusAvailable =>
      _t('Aucun bus disponible', 'No bus available', 'لا توجد حافلات متاحة');
  String get comeBackLater =>
      _t('Revenez plus tard', 'Come back later', 'عد لاحقاً');
  String get loadingError =>
      _t('Erreur de chargement', 'Loading error', 'خطأ في التحميل');

  // ═══════════════════════════════════════════════════
  // LOGOUT
  // ═══════════════════════════════════════════════════
  String get logoutTitle => _t('Déconnexion', 'Logout', 'تسجيل الخروج');
  String get logoutConfirm => _t(
        'Voulez-vous vraiment vous déconnecter ?',
        'Are you sure you want to log out?',
        'هل أنت متأكد أنك تريد تسجيل الخروج؟',
      );
  String get logoutButton => _t('Déconnecter', 'Log out', 'تسجيل الخروج');

  // ═══════════════════════════════════════════════════
  // PROFILE / USER PAGE
  // ═══════════════════════════════════════════════════
  String get profileTitle => _t('Mon Profil', 'My Profile', 'ملفي الشخصي');
  String get accountInfo =>
      _t('Informations du compte', 'Account Information', 'معلومات الحساب');
  String get nameLabel => _t('Nom', 'Name', 'الاسم');
  String get emailLabel => _t('Email', 'Email', 'البريد الإلكتروني');
  String get roleLabel => _t('Rôle', 'Role', 'الدور');
  String get memberSince => _t('Membre depuis', 'Member since', 'عضو منذ');
  String get passenger => _t('Voyageur', 'Passenger', 'مسافر');
  String get settings => _t('Paramètres', 'Settings', 'الإعدادات');
  String get language => _t('Langue', 'Language', 'اللغة');
  String get chooseLanguage =>
      _t('Choisir la langue', 'Choose language', 'اختر اللغة');
  String get theme => _t('Thème', 'Theme', 'المظهر');
  String get darkMode => _t('Mode sombre', 'Dark mode', 'الوضع الداكن');
  String get lightMode => _t('Mode clair', 'Light mode', 'الوضع الفاتح');
  String get systemMode => _t('Système', 'System', 'النظام');
  String get version => _t('Version', 'Version', 'الإصدار');
  String get about => _t('À propos', 'About', 'حول');
  String get aboutDescription => _t(
        'Massar — votre compagnon de transport intelligent.',
        'Massar — your smart transport companion.',
        'مسار — رفيقك الذكي في النقل.',
      );

  // ═══════════════════════════════════════════════════
  // AUTH ERROR MESSAGES
  // ═══════════════════════════════════════════════════
  String get errUserNotFound => _t(
        'Aucun compte trouvé avec cet email.',
        'No account found with this email.',
        'لم يتم العثور على حساب بهذا البريد.',
      );
  String get errWrongPassword =>
      _t('Mot de passe incorrect.', 'Incorrect password.', 'كلمة مرور غير صحيحة.');
  String get errInvalidEmail => _t(
        'Format d\'email invalide.',
        'Invalid email format.',
        'صيغة بريد إلكتروني غير صالحة.',
      );
  String get errUserDisabled => _t(
        'Ce compte a été désactivé.',
        'This account has been disabled.',
        'تم تعطيل هذا الحساب.',
      );
  String get errTooManyRequests => _t(
        'Trop de tentatives. Réessayez plus tard.',
        'Too many attempts. Try again later.',
        'محاولات كثيرة. حاول مرة أخرى لاحقاً.',
      );
  String get errInvalidCredential => _t(
        'Email ou mot de passe incorrect.',
        'Incorrect email or password.',
        'بريد إلكتروني أو كلمة مرور غير صحيحة.',
      );
  String get errEmailInUse => _t(
        'Cet email est déjà utilisé par un autre compte.',
        'This email is already used by another account.',
        'هذا البريد مستخدم بالفعل من حساب آخر.',
      );
  String get errWeakPassword => _t(
        'Le mot de passe est trop faible.',
        'The password is too weak.',
        'كلمة المرور ضعيفة جداً.',
      );
  String get errGeneric =>
      _t('Erreur. Veuillez réessayer.', 'Error. Please try again.', 'خطأ. يرجى المحاولة مرة أخرى.');

  // ── Map Firebase error codes → translated messages ───────────────────────
  String authError(String code) {
    switch (code) {
      case 'user-not-found':
        return errUserNotFound;
      case 'wrong-password':
        return errWrongPassword;
      case 'invalid-email':
        return errInvalidEmail;
      case 'user-disabled':
        return errUserDisabled;
      case 'too-many-requests':
        return errTooManyRequests;
      case 'invalid-credential':
        return errInvalidCredential;
      case 'email-already-in-use':
        return errEmailInUse;
      case 'weak-password':
        return errWeakPassword;
      default:
        return errGeneric;
    }
  }

  // ═══════════════════════════════════════════════════
  // BOOKINGS
  // ═══════════════════════════════════════════════════
  String get myBookings =>
      _t('Mes réservations', 'My bookings', 'حجوزاتي');
  String get noBookings =>
      _t('Aucune réservation', 'No bookings', 'لا توجد حجوزات');
  String get myReservedBus =>
      _t('Mon bus réservé', 'My reserved bus', 'حافلتي المحجوزة');
  String get myReservedBusDesc =>
      _t('Vous avez une réservation active', 'You have an active reservation', 'لديك حجز نشط');
  String get etaLabel =>
      _t('Arrivée estimée', 'Estimated arrival', 'وقت الوصول المتوقع');
  String get etaCalculating =>
      _t('Calcul en cours…', 'Calculating…', 'جاري الحساب…');
  String get etaUnavailable =>
      _t('Indisponible', 'Unavailable', 'غير متاح');
  String get etaImminent =>
      _t('Arrivée imminente', 'Arriving now', 'وصول وشيك');
  String get viewOnMap =>
      _t('Voir sur la carte', 'View on map', 'عرض على الخريطة');
  String get cancelReservation =>
      _t('Annuler', 'Cancel', 'إلغاء');
  String get reservationCancelled =>
      _t('Réservation annulée', 'Reservation cancelled', 'تم إلغاء الحجز');
  String get reservationStatus =>
      _t('Statut', 'Status', 'الحالة');

  // ═══════════════════════════════════════════════════
  // MAP
  // ═══════════════════════════════════════════════════
  String get allBusesMap => _t('Carte des bus', 'Bus map', 'خريطة الحافلات');

  // ═══════════════════════════════════════════════════
  // PRICE / FARE
  // ═══════════════════════════════════════════════════
  String get calculatePrice =>
      _t('Calculer prix', 'Calculate price', 'حساب السعر');
  String priceTitle(String lineName) => _t(
        'Calcul du prix - $lineName',
        'Price calculation - $lineName',
        'حساب السعر - $lineName',
      );
  String get departurePoint =>
      _t('Point de départ', 'Departure point', 'نقطة الانطلاق');
  String get arrivalPoint =>
      _t('Point d\'arrivée', 'Arrival point', 'نقطة الوصول');
  String get selectStop =>
      _t('Sélectionner un arrêt', 'Select a stop', 'اختر محطة');
  String get computePriceBtn =>
      _t('Calculer le prix', 'Calculate price', 'احسب السعر');
  String get totalPriceLabel =>
      _t('Prix total', 'Total price', 'السعر الإجمالي');
  String get segmentBreakdown => _t(
        'Détail des segments',
        'Segment breakdown',
        'تفاصيل المقاطع',
      );
  String get errorLoadingStops => _t(
        'Erreur lors du chargement des arrêts',
        'Error loading stops',
        'خطأ أثناء تحميل المحطات',
      );
  String get errPriceMissingSegment => _t(
        'Prix manquant pour ce trajet. Contactez l\'administrateur.',
        'Missing price for this trip. Please contact the administrator.',
        'لا يوجد سعر مسجَّل لهذا المقطع. يرجى التواصل مع المسؤول.',
      );
  String get errPriceDepartureAfterDestination => _t(
        'Le départ doit précéder la destination.',
        'Departure must come before destination.',
        'يجب أن تسبق محطة الانطلاق محطة الوصول.',
      );
  String get errPriceDepartureNotInLine => _t(
        'Arrêt de départ introuvable sur cette ligne.',
        'Departure stop not found on this line.',
        'محطة الانطلاق غير موجودة في هذا الخط.',
      );
  String get errPriceDestinationNotInLine => _t(
        'Arrêt d\'arrivée introuvable sur cette ligne.',
        'Destination stop not found on this line.',
        'محطة الوصول غير موجودة في هذا الخط.',
      );
  String get currencyDA => _t('DA', 'DA', 'دج');
  String get fromLabel => _t('De :', 'From:', 'من :');
  String get fromHint  => _t('ex. Bouira', 'e.g. Bouira', 'مثال: بويرة');
  String get toLabel   => _t('À :', 'To:', 'إلى :');
  String get toHint    => _t('ex. Alger', 'e.g. Alger', 'مثال: الجزائر');

  String get greeting         => _t('Bienvenue, bon voyage !', 'Welcome, enjoy your trip!', 'أهلاً، استمتع برحلتك');
  String get upcomingBuses    => _t('Prochains départs', 'Upcoming buses', 'الحافلات القادمة');
  String get onTime           => _t('À l\'heure', 'On-time', 'في الوقت');
  String get confirmed        => _t('Confirmée', 'Confirmed', 'مؤكدة');
  String get pending          => _t('En attente', 'Pending', 'قيد الانتظار');
  String get showOnMap        => _t('Voir sur la carte', 'Show on Map', 'عرض على الخريطة');
  String get cancelConfirmMsg => _t('Voulez-vous annuler cette réservation ?', 'Do you want to cancel this reservation?', 'هل تريد إلغاء هذا الحجز؟');
  String get estimatedArrivalDash => _t('Arrivée estimée : ----', 'Estimated Arrival: ----', 'الوصول المتوقع: ----');
  String get onTripDot        => _t('En trajet', 'On trip', 'في رحلة');
  String get upcomingDot      => _t('القادمة', 'Upcoming', 'القادمة');

  // ═══════════════════════════════════════════════════
  // TRAJET EN COURS SECTION
  // ═══════════════════════════════════════════════════
  String get onTripSectionTitle => _t('Trajet en cours', 'On Trip', 'رحلة جارية');
  String busesOnTripCount(int count) =>
      _t('$count en route', '$count on route', '$count في الطريق');
  String get trackLive => _t('Suivre en direct', 'Track live', 'تتبع مباشر');
  String get seeAll => _t('Voir tous', 'See all', 'عرض الكل');
  String get allOnTripTitle => _t('Tous les bus en trajet', 'All buses on trip', 'كل الحافلات في الطريق');
  String get allOnlineTitle => _t('Tous les bus en ligne', 'All online buses', 'كل الحافلات المتاحة');

  // ═══════════════════════════════════════════════════
  // HOME SEARCH BAR
  // ═══════════════════════════════════════════════════
  String get myPosition        => _t('Ma position', 'My location', 'موقعي');
  String get departureHint     => _t('Point de départ', 'Departure point', 'نقطة الانطلاق');
  String get destinationHint   => _t('Où allez-vous ?', 'Where are you going?', 'إلى أين تذهب؟');
  String get searchSuggest     => _t('Rechercher une destination…', 'Search a destination…', 'ابحث عن وجهة…');
  String get pickDepOnMap      => _t('Choisir le départ sur la carte', 'Pick departure on map', 'اختر نقطة الانطلاق على الخريطة');
  String get pickArrOnMap      => _t('Choisir l\'arrivée sur la carte', 'Pick arrival on map', 'اختر نقطة الوصول على الخريطة');
  String get searchBtn         => _t('Rechercher', 'Search', 'بحث');
  String get searchResultTitle => _t('Résultats de recherche', 'Search results', 'نتائج البحث');
  String get busesFound        => _t('bus trouvé', 'bus found', 'حافلة وُجدت');
  String get busesFoundPlural  => _t('bus trouvés', 'buses found', 'حافلات وُجدت');
  String get noBusFound        => _t('Aucun bus trouvé', 'No bus found', 'لا توجد حافلات');
  String get noBusFoundDesc    => _t('Aucun bus ne dessert ce trajet.\nEssayez des points plus proches.', 'No bus serves this route.\nTry closer points.', 'لا توجد حافلة لهذا المسار.\nجرب نقاطاً أقرب.');
  String get tapToSearch       => _t('Entrez votre destination', 'Enter your destination', 'أدخل وجهتك');
  String get tapToSearchDesc   => _t('Ou choisissez sur la carte', 'Or pick on the map', 'أو اختر من الخريطة');
  String get confirmPoint      => _t('Confirmer ce point', 'Confirm this point', 'تأكيد هذه النقطة');
  String get tapMapToChoose    => _t('Appuyez sur la carte pour choisir le point', 'Tap the map to choose a point', 'انقر على الخريطة لاختيار النقطة');
  String get departurePointTitle => _t('Point de départ', 'Departure point', 'نقطة الانطلاق');
  String get arrivalPointTitle   => _t('Point d\'arrivée', 'Arrival point', 'نقطة الوصول');
  String get searchErrorMsg    => _t('Erreur lors de la recherche. Veuillez réessayer.', 'Search error. Please try again.', 'خطأ في البحث. حاول مرة أخرى.');
  String get onlineDot         => _t('En ligne', 'Online', 'متصل');
  String get prochainsDepartsTitle => _t('Prochains départs', 'Next departures', 'المغادرات القادمة');
}

// ─────────────────────────────────────────────────────────────────────────────
// DELEGATE
// ─────────────────────────────────────────────────────────────────────────────
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['fr', 'en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      Future.value(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
