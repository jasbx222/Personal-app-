import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/connection/prefs.dart';

const _en = <String, String>{
  'appName': 'Phone2PC',
  'statusConnected': 'Connected',
  'statusSearching': 'Searching…',
  'statusOffline': 'Offline',
  'statusUnpaired': 'Not paired',
  'statusTokenInvalid': 'Pairing expired',
  'unpairedHint': 'Scan the QR code shown in the desktop app to pair.',
  'offlineHint': 'Make sure your PC is on and on the same Wi-Fi.',
  'tokenInvalidHint': 'The PC no longer accepts this phone. Pair again.',
  'scanQr': 'Scan QR code',
  'pairAgain': 'Pair again',
  'retry': 'Retry',
  'textHint': 'Type or paste text or a link…',
  'send': 'Send',
  'sendClipboard': 'Send clipboard',
  'clipboardEmpty': 'The clipboard is empty.',
  'gallery': 'Photos & videos',
  'files': 'Files',
  'camera': 'Camera',
  'transfers': 'Transfers',
  'noTransfers': 'Nothing sent yet.',
  'waiting': 'Waiting…',
  'sending': 'Sending {pct}%',
  'sent': 'Sent',
  'cancelled': 'Cancelled',
  'cancel': 'Cancel',
  'remove': 'Remove',
  'clearFinished': 'Clear finished',
  'history': 'History',
  'historyEmpty': 'No sent items yet.',
  'clearHistory': 'Clear history',
  'errNotPaired': 'Not paired with a PC yet.',
  'errUnreachable': 'Can’t reach the PC. Check that it is on and on the same Wi-Fi network.',
  'errUnauthorized': 'The PC rejected this phone (token invalid). Pair again.',
  'errInterrupted': 'The upload was interrupted. Tap retry.',
  'errServer': 'The PC returned an error: {err}',
  'errFileMissing': 'The file is no longer available.',
  'pairTitle': 'Pair with PC',
  'pairScanHelp': 'Point the camera at the QR code in the desktop app (Settings → Show pairing QR).',
  'manualEntry': 'Enter manually',
  'ip': 'IP address',
  'port': 'Port',
  'token': 'Token',
  'pair': 'Pair',
  'nearby': 'Nearby PCs',
  'searchNearby': 'Search nearby',
  'invalidQr': 'This is not a Phone2PC code.',
  'invalidInput': 'Fill in a valid IP address, port and token.',
  'paired': 'Paired with {name}',
  'cameraDenied': 'Camera permission is needed to scan. Enter the details manually instead.',
  'settings': 'Settings',
  'language': 'Language',
  'theme': 'Theme',
  'system': 'System',
  'light': 'Light',
  'dark': 'Dark',
  'english': 'English',
  'arabic': 'العربية',
  'unpair': 'Forget this PC',
  'close': 'Close',
};

const _ar = <String, String>{
  'appName': 'Phone2PC',
  'statusConnected': 'متصل',
  'statusSearching': 'جارٍ البحث…',
  'statusOffline': 'غير متصل',
  'statusUnpaired': 'غير مربوط',
  'statusTokenInvalid': 'انتهى الربط',
  'unpairedHint': 'امسح رمز QR الظاهر في تطبيق سطح المكتب للربط.',
  'offlineHint': 'تأكد من تشغيل الحاسوب واتصاله بنفس شبكة Wi-Fi.',
  'tokenInvalidHint': 'لم يعد الحاسوب يقبل هذا الهاتف. اربطه من جديد.',
  'scanQr': 'مسح رمز QR',
  'pairAgain': 'إعادة الربط',
  'retry': 'إعادة المحاولة',
  'textHint': 'اكتب أو الصق نصاً أو رابطاً…',
  'send': 'إرسال',
  'sendClipboard': 'إرسال الحافظة',
  'clipboardEmpty': 'الحافظة فارغة.',
  'gallery': 'الصور والفيديو',
  'files': 'الملفات',
  'camera': 'الكاميرا',
  'transfers': 'عمليات الإرسال',
  'noTransfers': 'لم يُرسل شيء بعد.',
  'waiting': 'في الانتظار…',
  'sending': 'جارٍ الإرسال {pct}٪',
  'sent': 'تم الإرسال',
  'cancelled': 'أُلغي',
  'cancel': 'إلغاء',
  'remove': 'إزالة',
  'clearFinished': 'مسح المنتهية',
  'history': 'السجل',
  'historyEmpty': 'لا توجد عناصر مرسلة بعد.',
  'clearHistory': 'مسح السجل',
  'errNotPaired': 'لم يتم الربط مع حاسوب بعد.',
  'errUnreachable': 'تعذّر الوصول إلى الحاسوب. تأكد من تشغيله واتصاله بنفس شبكة Wi-Fi.',
  'errUnauthorized': 'رفض الحاسوب هذا الهاتف (الرمز غير صالح). اربطه من جديد.',
  'errInterrupted': 'انقطع الإرسال. اضغط إعادة المحاولة.',
  'errServer': 'أعاد الحاسوب خطأً: {err}',
  'errFileMissing': 'الملف لم يعد متاحاً.',
  'pairTitle': 'الربط مع الحاسوب',
  'pairScanHelp': 'وجّه الكاميرا نحو رمز QR في تطبيق سطح المكتب (الإعدادات ← عرض رمز الربط).',
  'manualEntry': 'إدخال يدوي',
  'ip': 'عنوان IP',
  'port': 'المنفذ',
  'token': 'الرمز السري',
  'pair': 'ربط',
  'nearby': 'حواسيب قريبة',
  'searchNearby': 'بحث عن أجهزة قريبة',
  'invalidQr': 'هذا ليس رمز Phone2PC.',
  'invalidInput': 'أدخل عنوان IP ومنفذاً ورمزاً صالحة.',
  'paired': 'تم الربط مع {name}',
  'cameraDenied': 'يلزم إذن الكاميرا للمسح. أدخل التفاصيل يدوياً بدلاً من ذلك.',
  'settings': 'الإعدادات',
  'language': 'اللغة',
  'theme': 'المظهر',
  'system': 'النظام',
  'light': 'فاتح',
  'dark': 'داكن',
  'english': 'English',
  'arabic': 'العربية',
  'unpair': 'نسيان هذا الحاسوب',
  'close': 'إغلاق',
};

class Strings {
  const Strings(this.lang);

  final String lang;

  bool get isRtl => lang == 'ar';

  String t(String key, [Map<String, String> args = const {}]) {
    var s = (lang == 'ar' ? _ar[key] : _en[key]) ?? _en[key] ?? key;
    args.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }
}

String resolveLanguage(String setting) {
  if (setting == 'en' || setting == 'ar') return setting;
  return PlatformDispatcher.instance.locale.languageCode == 'ar' ? 'ar' : 'en';
}

final stringsProvider = Provider<Strings>((ref) {
  return Strings(resolveLanguage(ref.watch(prefsProvider.select((p) => p.language))));
});
