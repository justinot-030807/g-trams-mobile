/// Lightweight bilingual (English / Filipino-Tagalog) strings for G-TRAMS Mobile.
/// Strictly uses Office of the Municipal Vice Mayor (OVM) — LLSA I (never "BPLO").
class AppStrings {
  const AppStrings(this.lang);

  final String lang;
  bool get isFil => lang == 'fil';

  String pick(String en, String fil) => isFil ? fil : en;

  // Brand & Splash
  String get appName => 'G-TRAMS';
  String get appFullTitle =>
      'Gasan Tricycle Records & Application Management System';
  String get municipalityCaption => 'MUNICIPALITY OF GASAN • MARINDUQUE';
  String get wakingServer => pick(
        'Connecting to Gasan Municipal Server...',
        'Kumokonekta sa Municipal Server ng Gasan...',
      );
  String get verifyingSession => pick(
        'Checking your account session...',
        'Sinusuri ang iyong account session...',
      );

  // Onboarding
  String get skip => pick('Skip', 'Laktawan');
  String get next => pick('Next', 'Susunod');
  String get getStarted => pick('Get Started', 'Magsimula');
  String get onboard1Title => pick(
        'Your Digital MTOP & Operator ID',
        'Digital na MTOP at Operator ID',
      );
  String get onboard1Body => pick(
        'Track your tricycle franchise applications, view your official E-Copy, and show your scannable LGU QR ID anytime — even offline.',
        'Subaybayan ang iyong aplikasyon ng prangkisa, tingnan ang opisyal na E-Copy, at ipakita ang LGU QR ID kahit walang internet.',
      );
  String get onboard2Title => pick(
        'Smart Document Scanning & Auto-Fill',
        'Mabilis na Document Scanner at Auto-Fill',
      );
  String get onboard2Body => pick(
        'Capture clear photos of your LTO OR/CR, Driver\'s License, and Cedula directly from your phone for faster OVM / LLSA I verification.',
        'Kunan ng malinaw na litrato ang OR/CR, Driver\'s License, at Cedula gamit ang cellphone para mas mabilis ang beripikasyon ng OVM / LLSA I.',
      );
  String get onboard3Title => pick(
        'Built for Operators & TODA Presidents',
        'Para sa mga Operator at TODA President',
      );
  String get onboard3Body => pick(
        'Manage accredited TODA rosters, receive renewal and status alerts, and message G-TRAMS Support directly in real time.',
        'Pamahalaan ang listahan ng miyembro ng TODA, tumanggap ng paalala sa renewal, at makipag-ugnayan sa G-TRAMS Support nang real-time.',
      );

  // Login
  String get welcomeBack => pick('Welcome back', 'Maligayang pagbabalik');
  String get loginSubtitle => pick(
        'Sign in with your Operator or TODA President account.',
        'Mag-sign in gamit ang iyong Operator o TODA President account.',
      );
  String get contactLabel =>
      pick('Email or Mobile Number', 'Email o Numero ng Cellphone');
  String get contactHint => pick(
        'e.g. operator@email.com or 09171234567',
        'hal. operator@email.com o 09171234567',
      );
  String get passwordLabel => pick('Password', 'Password');
  String get passwordHint =>
      pick('Enter your password', 'Ilagay ang iyong password');
  String get forgotPassword =>
      pick('Forgot password?', 'Nakalimutan ang password?');
  String get signIn => pick('Sign In', 'Mag-sign In');
  String get orContinueWith =>
      pick('OR CONTINUE WITH', 'O MAGPATULOY GAMIT ANG');
  String get continueWithGoogle =>
      pick('Continue with Google', 'Magpatuloy gamit ang Google');
  String get biometricUnlock => pick(
        'Unlock with Biometrics',
        'Buksan gamit ang Fingerprint / Face',
      );
  String get noAccountYet =>
      pick('New tricycle operator? ', 'Bagong tricycle operator? ');
  String get createAccount => pick('Create Account', 'Gumawa ng Account');
  String get staffPortalNoticeTitle => pick(
        'Municipal Web Portal Required',
        'Gamitin ang Municipal Web Portal',
      );
  String get openWebPortal =>
      pick('Open G-TRAMS Web Portal', 'Buksan ang Web Portal');

  // Register (3 Steps)
  String get registerTitle =>
      pick('Operator Registration', 'Rehistrasyon ng Operator');
  String get step1Title =>
      pick('Identity & TODA Roster', 'Pagkakakilanlan at TODA');
  String get step2Title => pick('Account Security', 'Seguridad ng Account');
  String get step3Title => pick('Verify OTP Code', 'Beripikasyon ng OTP');
  String get fullNameLabel => pick('Full Legal Name', 'Buong Pangalan');
  String get fullNameHint => pick('Juan Dela Cruz', 'Juan Dela Cruz');
  String get barangayLabel =>
      pick('Barangay Residence (Gasan)', 'Barangay sa Gasan');
  String get selectBarangay =>
      pick('Select your Barangay', 'Piliin ang iyong Barangay');
  String get todaLabel =>
      pick('Accredited TODA Association', 'Akreditadong TODA');
  String get selectToda => pick('Select your TODA', 'Piliin ang iyong TODA');
  String get bodyNumberLabel =>
      pick('Assigned Body Number', 'Itinalagang Body Number');
  String get bodyNumberHint => pick('e.g. 001 or B-12', 'hal. 001 o B-12');
  String get confirmPasswordLabel =>
      pick('Confirm Password', 'Kumpirmahin ang Password');
  String get acceptTerms => pick(
        'I agree to the G-TRAMS Terms of Service & Data Privacy Notice (RA 10173).',
        'Sumasang-ayon ako sa Mga Tuntunin at Data Privacy Notice (RA 10173) ng G-TRAMS.',
      );
  String get sendOtp =>
      pick('Send Verification Code', 'Magpadala ng OTP Code');
  String get verifyAndContinue =>
      pick('Verify & Continue', 'I-verify at Magpatuloy');
  String get resendCode => pick('Resend Code', 'Ipadala Muli ang Code');
  String get alreadyHaveAccount =>
      pick('Already registered? ', 'May account ka na? ');

  // Forgot Password
  String get resetPasswordTitle => pick('Reset Password', 'I-reset ang Password');
  String get resetPasswordSubtitle => pick(
        'Enter your registered email or mobile number to receive a 6-digit recovery code.',
        'Ilagay ang iyong email o numero ng cellphone upang makatanggap ng 6-digit recovery code.',
      );

  // Navigation Tabs
  String get navHome => pick('Home', 'Tahanan');
  String get navToda => pick('TODA', 'TODA');
  String get navApply => pick('Apply', 'Mag-apply');
  String get navSettings => pick('Settings', 'Settings');

  // Phase 2 — Operator Garage Dashboard
  String get garageTitle => pick('My Franchise Garage', 'Aking Garage ng Prangkisa');
  String get garageSubtitle => pick(
        'Registered tricycle units & live OVM / LLSA I status',
        'Mga rehistradong tricycle at status sa OVM / LLSA I',
      );
  String get digitalWalletButton => pick('Digital ID', 'Digital ID');
  String get digitalWalletTitle =>
      pick('Offline Digital Wallet', 'Offline Digital Wallet');
  String get unitQuotaTitle => pick('UNIT QUOTA ALLOCATION', 'LIMITASYON NG UNIT');
  String get slotsFull => pick('Quota Full', 'Puno na ang Slot');
  String slotsAvailable(int remaining) => pick(
        '$remaining slot${remaining == 1 ? '' : 's'} available',
        '$remaining slot pa ang bakante',
      );
  String get franchiseFeeLabel => pick('FRANCHISE FEE', 'BAYAD SA PRANGKISA');
  String get lastSyncedLabel => pick('Last synced', 'Huling na-sync');
  String get offlineModeBannerTitle =>
      pick('Offline Mode — Cached Wallet Active', 'Offline Mode — Gamit ang Naka-save na Data');
  String get offlineModeBannerBody => pick(
        'Showing your last synced franchises, Digital Operator ID, and MTOP E-Copy. Pull down to refresh once signal returns.',
        'Ipinapakita ang huling naka-sync na prangkisa, Digital Operator ID, at MTOP E-Copy. Mag-pull down kapag may signal na.',
      );
  String get retry => pick('Retry', 'Subukan Muli');

  // Filter Tabs
  String get filterAll => pick('All', 'Lahat');
  String get filterActive => pick('Active', 'Aktibo');
  String get filterInProgress => pick('In-Progress', 'Pinoproseso');
  String get filterPastArchived => pick('Past & Archived', 'Luma at Nakansela');

  // 5-Stage LGU Pipeline Stepper
  String get pipelineHeader =>
      pick('LGU FRANCHISE PIPELINE (5 STAGES)', '5 YUGTO NG PROSESO SA LGU');
  String get stagePending => pick('Pending', 'Nakabinbin');
  String get stageForPayment => pick('For Payment', 'Magbayad');
  String get stageForSigning => pick('For Signing', 'Pipirmahan');
  String get stageReadyPickup => pick('Pickup', 'Kukunin');
  String get stageActive => pick('Active', 'Aktibo');

  // Unit Card Fields & Actions
  String get plateNumberLabel => pick('PLATE NO.', 'PLAKA');
  String get mtopNumberLabel => pick('MTOP NO.', 'MTOP #');
  String get bodyNumberShort => pick('BODY #', 'BODY #');
  String get zoneLabel => pick('ZONE', 'SONA');
  String get motorNumberLabel => pick('MOTOR NO.', 'MOTOR #');
  String get chassisNumberLabel => pick('CHASSIS NO.', 'CHASSIS #');
  String get validUntilLabel => pick('VALID UNTIL', 'BALIDO HANGGANG');
  String daysLeftText(int days) => pick(
        '$days day${days == 1 ? '' : 's'} remaining',
        '$days araw na natitira',
      );
  String overdueDaysText(int days) => pick(
        'Expired $days day${days == 1 ? '' : 's'} ago',
        'Nag-expire $days araw na ang nakalipas',
      );
  String get renewalWindowOpen =>
      pick('Renewal Window Open', 'Bukas na ang Renewal');
  String get viewECopyAction => pick('MTOP E-Copy', 'MTOP E-Copy');
  String get violationsAction => pick('Violations', 'Mga Paglabag');
  String get detailsAction => pick('Details', 'Detalye');
  String get withdrawAction => pick('Withdraw', 'I-withdraw');
  String get requestCancelAction =>
      pick('Request Cancel', 'Kanselahin');
  String get fixReapplyAction => pick('Fix & Reapply', 'Ayusin at Isumite');
  String get renewAction => pick('Renew Franchise', 'I-renew ang Prangkisa');
  String get applyNewAction => pick('Apply New Franchise', 'Mag-apply ng Bago');

  // Empty & Error States
  String get emptyGarageTitle =>
      pick('No Tricycle Franchises Yet', 'Wala Pang Nakarehistrong Prangkisa');
  String get emptyGarageBody => pick(
        'Register your first tricycle unit with the Office of the Municipal Vice Mayor (OVM) — LLSA I to track approval and unlock your digital MTOP.',
        'Irehistro ang iyong tricycle sa Office of the Municipal Vice Mayor (OVM) — LLSA I upang masubaybayan ang aplikasyon at makuha ang digital MTOP.',
      );
  String get emptyFilterTitle =>
      pick('No Units in This Category', 'Walang Unit sa Kategoryang Ito');
  String get emptyFilterBody => pick(
        'Switch to another filter tab or view All units in your garage.',
        'Lumipat sa ibang filter tab o piliin ang Lahat upang makita ang iba pang unit.',
      );
  String get showAllUnits => pick('Show All Units', 'Ipakita Lahat');
  String get loadErrorTitle =>
      pick('Unable to Load Your Garage', 'Hindi Ma-load ang Iyong Garage');

  // Offline Digital Operator ID & MTOP Wallet
  String get tapCardToFlip => pick('Tap card to flip', 'I-tap upang baliktarin');
  String get flipCard => pick('Flip ID Card', 'Baliktarin ang ID');
  String get officialQrTitle =>
      pick('OFFICIAL LGU VERIFICATION QR', 'OPISYAL NA LGU VERIFICATION QR');
  String get officialQrSubtitle => pick(
        'Enforcers & TODA Presidents can scan to verify credentials',
        'Ipa-scan sa enforcer o TODA President para sa beripikasyon',
      );
  String get emergencyContactLabel =>
      pick('IN CASE OF EMERGENCY', 'TAWAGAN SA ORAS NG EMERHENSIYA');
  String get notProvided => pick('Not Provided', 'Hindi Nakalagay');
  String get mtopECopyTab => pick('MTOP E-Copy', 'MTOP E-Copy');
  String get paymentReceiptTab => pick('Payment E-Receipt', 'E-Resibo (OR#)');
  String get offlineReadyLabel => pick('OFFLINE READY', 'HANDA KAHIT OFFLINE');

  // Violations & 3-Tier Sanctions
  String get violationsSheetTitle =>
      pick('Violations & Sanctions History', 'Kasaysayan ng Paglabag at Parusa');
  String get cleanStandingTitle =>
      pick('Good Standing — No Violations', 'Malinis ang Rekord — Walang Paglabag');
  String get cleanStandingBody => pick(
        'This tricycle unit has zero recorded municipal ordinance infractions.',
        'Walang naitalang paglabag sa ordinansa ang tricycle unit na ito.',
      );
  String get threeTierPolicyTitle =>
      pick('3-TIER PROGRESSIVE SANCTIONS', '3-ANTAS NA PARUSA NG MUNISIPYO');

  // Withdraw & Voluntary Cancellation
  String get withdrawSheetTitle =>
      pick('Withdraw Pending Application', 'I-withdraw ang Nakabinbing Aplikasyon');
  String get withdrawAdvisory => pick(
        'Only unpaid pending applications may be withdrawn. Your reason will be logged for the Office of the Municipal Vice Mayor (OVM) — LLSA I.',
        'Ang mga hindi pa nabayarang aplikasyon lamang ang maaaring i-withdraw. Itatala ang iyong dahilan sa Office of the Municipal Vice Mayor (OVM) — LLSA I.',
      );
  String get confirmWithdraw => pick('Confirm Withdrawal', 'Kumpirmahin ang Pag-withdraw');
  String get voluntaryCancelTitle =>
      pick('Voluntary Franchise Cancellation', 'Kusang Pagkansela ng Prangkisa');
  String get voluntaryCancelNotice => pick(
        'Submitting this formal surrender sets your franchise to "Cancellation Requested" for review by the Office of the Municipal Vice Mayor (OVM) — LLSA I. No Municipal Cashier payment is required.',
        'Ilalagay nito ang iyong prangkisa sa "Cancellation Requested" para sa pagsusuri ng Office of the Municipal Vice Mayor (OVM) — LLSA I. Walang bayarin sa Municipal Cashier.',
      );
  String get typeLetterMode => pick('Type Formal Letter', 'Isulat ang Liham');
  String get uploadLetterMode => pick('Upload Photo / PDF', 'Mag-upload ng File');
  String get resetTemplate => pick('Sync Template', 'Ibalik ang Template');
  String get submitCancellationRequest =>
      pick('Submit Cancellation Request', 'Isumite ang Kahilingan');
  String get close => pick('Close', 'Isara');
  String get cancel => pick('Cancel', 'Kanselahin');

  // Phase 3 — 5-Step Apply & Renew Franchise Wizard
  String get wizardNewTitle =>
      pick('New Franchise Application', 'Bagong Aplikasyon ng Prangkisa');
  String get wizardFixTitle =>
      pick('Fix & Reapply Application', 'Ayusin at Isumite Muli');
  String get wizardRenewTitle =>
      pick('Renew Tricycle Franchise', 'I-renew ang Prangkisa ng Tricycle');
  String get wizardStep1 => pick('Operator', 'Operator');
  String get wizardStep2 => pick('Vehicle', 'Sasakyan');
  String get wizardStep3 => pick('License', 'Lisensya');
  String get wizardStep4 => pick('Cedula', 'Cedula');
  String get wizardStep5 => pick('Review', 'Buod');
  String get draftAutoSavedLabel =>
      pick('Draft auto-saved offline', 'Awtomatikong naka-save ang draft');
  String get discardDraft => pick('Discard Draft', 'Burahin ang Draft');
  String get backStep => pick('Back', 'Bumalik');
  String get nextStep => pick('Continue', 'Magpatuloy');
  String get submitApplication =>
      pick('Submit Application', 'Isumite ang Aplikasyon');
  String get resubmitApplication =>
      pick('Resubmit Corrected Application', 'Isumite Muli ang Aplikasyon');
  String get submitRenewal =>
      pick('Submit Franchise Renewal', 'Isumite ang Renewal');
  String get backToGarage =>
      pick('Go to My Garage', 'Pumunta sa Aking Garage');

  // Phase 4 — TODA President Governance Hub
  String get todaHubTitle =>
      pick('TODA Governance Hub', 'TODA Governance Hub');
  String get todaTabDirectory => pick('Members', 'Miyembro');
  String get todaTabRoster => pick('Roster OCR', 'Roster OCR');
  String get todaTabRemovals => pick('Removals', 'Pag-alis');
  String get todaTabQrVerify => pick('QR Verify', 'QR Verify');
  String get addMemberAction =>
      pick('Add Member', 'Magdagdag ng Miyembro');
  String get autoNextBodyNo =>
      pick('Auto-Next Body #', 'Auto-Next Body #');
  String get searchMembersHint => pick(
        'Search name, Body #, or Plate No...',
        'Maghanap ng pangalan, Body #, o Plaka...',
      );
  String get requestRemovalAction =>
      pick('Request Removal', 'Hilingin ang Pag-alis');
  String get scanRosterAction =>
      pick('Scan / Upload Roster', 'I-scan / I-upload ang Roster');
  String get submitRosterToOvm =>
      pick('Submit Roster to OVM', 'Isumite sa OVM');
  String get verifyQrTitle =>
      pick('Operator QR & MTOP Verifier', 'Beripikasyon ng Operator QR at MTOP');
  String get scanQrCameraAction =>
      pick('Scan QR with Camera', 'I-scan ang QR gamit ang Kamera');
  String get verifyNowAction => pick('Verify Now', 'I-verify Ngayon');

  // Phase 5 — Updates Hub (Live Support Chat, Announcements, Notifications)
  String get navUpdates => pick('Updates', 'Updates');
  String get updatesTabChat => pick('Support Chat', 'Live Chat');
  String get updatesTabAnnouncements => pick('Advisories', 'Anunsyo');
  String get updatesTabNotifications => pick('Alerts', 'Notipikasyon');
  String get supportDeskTitle =>
      pick('OVM — LLSA I Support Desk', 'OVM — LLSA I Support Desk');
  String get liveConnected => pick('LIVE', 'LIVE');
  String get reconnectingLabel => pick('SYNCING', 'KUMOKONEKTA');
  String get offlineStatusLabel => pick('OFFLINE', 'OFFLINE');
  String get typeMessageHint => pick(
        'Message OVM — LLSA I support...',
        'Magpadala ng mensahe sa OVM — LLSA I...',
      );
  String get markAllRead => pick('Mark All Read', 'Markahang Nabasa');
  String get clearAll => pick('Clear All', 'Burahin Lahat');
  String get loadEarlierMessages =>
      pick('Load Earlier Messages', 'Tingnan ang Mas Lumang Mensahe');

  // Phase 5 — Settings Hub (Profile, Recovery, Password, Vault, Helpdesk)
  String get editProfileTitle =>
      pick('Edit Profile & Photo', 'I-edit ang Profile at Larawan');
  String get accountRecoveryTitle =>
      pick('Account Recovery', 'Account Recovery');
  String get changePasswordTitle =>
      pick('Change Password', 'Palitan ang Password');
  String get documentVaultTitle =>
      pick('Document Vault', 'Mga Nakaimbak na Dokumento');
  String get helpdeskTitle =>
      pick('Helpdesk & LGU Hotlines', 'Helpdesk at Hotline ng LGU');
  String get submitTicketAction =>
      pick('Submit Support Ticket', 'Magpadala ng Support Ticket');
  String get saveChanges => pick('Save Changes', 'I-save ang Pagbabago');
  String get lastSynced => pick('Last synced', 'Huling sync');
  String get clearOfflineCacheTitle =>
      pick('Clear Offline Cache', 'Linisin ang Offline Cache');
}
