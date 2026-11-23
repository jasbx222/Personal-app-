import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/settings_controller.dart';

const _en = <String, String>{
  'appName': 'Phone2PC',
  'history': 'Received',
  'settings': 'Settings',
  'pair': 'Pair phone',
  'emptyTitle': 'Nothing received yet',
  'emptyBody': 'Send text, links or files from your phone and they will show up here.',
  'serverRunning': 'Listening on {addr}',
  'serverStopped': 'Server stopped',
  'serverError': 'Server error: {err}',
  'copy': 'Copy',
  'copied': 'Copied',
  'pathCopied': 'File path copied',
  'open': 'Open',
  'openInBrowser': 'Open in browser',
  'showInFolder': 'Show in folder',
  'delete': 'Delete',
  'cancel': 'Cancel',
  'removeFromList': 'Remove from list',
  'deleteFileToo': 'Delete file too',
  'deleteTitle': 'Delete this item?',
  'fileMissing': 'The file no longer exists.',
  'badLink': 'This link is not a valid web address.',
  'saveFolder': 'Save folder',
  'chooseFolder': 'Choose…',
  'autoCopy': 'Copy received text to clipboard',
  'autoCopySub': 'Text and links are copied as soon as they arrive.',
  'port': 'Port',
  'apply': 'Apply',
  'portInvalid': 'Enter a port between 1024 and 65535.',
  'portApplied': 'Port changed to {port}. Your phone will find the new port automatically.',
  'launchAtStartup': 'Launch at startup',
  'startMinimized': 'Start minimized to tray',
  'deviceName': 'Device name',
  'language': 'Language',
  'theme': 'Theme',
  'system': 'System',
  'light': 'Light',
  'dark': 'Dark',
  'english': 'English',
  'arabic': 'العربية',
  'showQr': 'Show pairing QR code',
  'revoke': 'Revoke / re-pair',
  'revokeTitle': 'Revoke pairing?',
  'revokeBody': 'The current phone will be disconnected immediately. You can pair again with the new QR code.',
  'revokeConfirm': 'Revoke',
  'pairTitle': 'Pair your phone',
  'pairHelp': 'Open Phone2PC on your phone, tap “Scan QR”, and point it at this code. Your phone and PC must be on the same Wi-Fi.',
  'manualDetails': 'Manual details',
  'address': 'Address',
  'token': 'Token',
  'noNetwork': 'No network connection found. Connect to Wi-Fi and reopen this screen.',
  'newCodeCreated': 'Pairing revoked. A new code was created.',
  'firewallTitle': 'Allow connections through the firewall',
  'firewallBody': 'Windows Firewall may block your phone from reaching this PC. Add an inbound rule for port {port} (administrator approval required), or run this command yourself in an admin terminal:',
  'firewallAdd': 'Add rule',
  'firewallLater': 'Not now',
  'firewallDone': 'Done',
  'quit': 'Quit',
  'show': 'Show window',
  'received': 'Received from phone',
  'file': 'File',
  'image': 'Image',
  'video': 'Video',
  'text': 'Text',
  'link': 'Link',
};

const _ar = <String, String>{
  'appName': 'Phone2PC',
  'history': 'المستلَم',
  'settings': 'الإعدادات',
  'pair': 'ربط الهاتف',
  'emptyTitle': 'لم يصل شيء بعد',
  'emptyBody': 'أرسل نصوصاً أو روابط أو ملفات من هاتفك وستظهر هنا.',
  'serverRunning': 'يستمع على {addr}',
  'serverStopped': 'الخادم متوقف',
  'serverError': 'خطأ في الخادم: {err}',
  'copy': 'نسخ',
  'copied': 'تم النسخ',
  'pathCopied': 'تم نسخ مسار الملف',
  'open': 'فتح',
  'openInBrowser': 'فتح في المتصفح',
  'showInFolder': 'إظهار في المجلد',
  'delete': 'حذف',
  'cancel': 'إلغاء',
  'removeFromList': 'إزالة من القائمة',
  'deleteFileToo': 'حذف الملف أيضاً',
  'deleteTitle': 'حذف هذا العنصر؟',
  'fileMissing': 'الملف لم يعد موجوداً.',
  'badLink': 'هذا الرابط ليس عنوان ويب صالحاً.',
  'saveFolder': 'مجلد الحفظ',
  'chooseFolder': 'اختيار…',
  'autoCopy': 'نسخ النص المستلَم إلى الحافظة',
  'autoCopySub': 'يُنسخ النص والروابط فور وصولها.',
  'port': 'المنفذ',
  'apply': 'تطبيق',
  'portInvalid': 'أدخل منفذاً بين 1024 و 65535.',
  'portApplied': 'تم تغيير المنفذ إلى {port}. سيجد هاتفك المنفذ الجديد تلقائياً.',
  'launchAtStartup': 'التشغيل عند بدء النظام',
  'startMinimized': 'البدء مصغّراً في شريط النظام',
  'deviceName': 'اسم الجهاز',
  'language': 'اللغة',
  'theme': 'المظهر',
  'system': 'النظام',
  'light': 'فاتح',
  'dark': 'داكن',
  'english': 'English',
  'arabic': 'العربية',
  'showQr': 'عرض رمز QR للربط',
  'revoke': 'إلغاء الربط / إعادة الربط',
  'revokeTitle': 'إلغاء الربط؟',
  'revokeBody': 'سيتم فصل الهاتف الحالي فوراً. يمكنك الربط مجدداً بالرمز الجديد.',
  'revokeConfirm': 'إلغاء الربط',
  'pairTitle': 'اربط هاتفك',
  'pairHelp': 'افتح Phone2PC على هاتفك، واضغط «مسح QR»، ووجّه الكاميرا نحو هذا الرمز. يجب أن يكون الهاتف والحاسوب على نفس شبكة Wi-Fi.',
  'manualDetails': 'التفاصيل اليدوية',
  'address': 'العنوان',
  'token': 'الرمز السري',
  'noNetwork': 'لا يوجد اتصال بالشبكة. اتصل بشبكة Wi-Fi ثم أعد فتح هذه الشاشة.',
  'newCodeCreated': 'تم إلغاء الربط وإنشاء رمز جديد.',
  'firewallTitle': 'السماح بالاتصال عبر جدار الحماية',
  'firewallBody': 'قد يمنع جدار حماية Windows هاتفك من الوصول إلى هذا الحاسوب. أضف قاعدة واردة للمنفذ {port} (تتطلب موافقة المسؤول)، أو نفّذ هذا الأمر بنفسك في موجه أوامر بصلاحيات المسؤول:',
  'firewallAdd': 'إضافة القاعدة',
  'firewallLater': 'ليس الآن',
  'firewallDone': 'تم',
  'quit': 'خروج',
  'show': 'إظهار النافذة',
  'received': 'وصل من الهاتف',
  'file': 'ملف',
  'image': 'صورة',
  'video': 'فيديو',
  'text': 'نص',
  'link': 'رابط',
};

class Strings {
  const Strings(this.lang);

  final String lang; // 'en' | 'ar'

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
  final setting = ref.watch(settingsProvider.select((s) => s.language));
  return Strings(resolveLanguage(setting));
});
