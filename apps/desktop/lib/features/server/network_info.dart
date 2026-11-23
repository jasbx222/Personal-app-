import 'dart:io';

class LanAddress {
  const LanAddress(this.ip, this.interfaceName);
  final String ip;
  final String interfaceName;
}

final _virtual = RegExp(r'docker|veth|vbox|vmnet|vmware|virtual|vEthernet|br-|tun|tap|utun|awdl|llw|bridge', caseSensitive: false);

bool _isPrivate(String ip) =>
    ip.startsWith('192.168.') ||
    ip.startsWith('10.') ||
    RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip);

/// Non-loopback IPv4 addresses, most likely LAN address first.
Future<List<LanAddress>> lanAddresses() async {
  final out = <(LanAddress, int)>[];
  for (final nic in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
    for (final a in nic.addresses) {
      final ip = a.address;
      if (a.isLoopback || ip.startsWith('169.254.')) continue;
      var score = 0;
      if (_isPrivate(ip)) score += 2;
      if (!_virtual.hasMatch(nic.name)) score += 4;
      out.add((LanAddress(ip, nic.name), score));
    }
  }
  out.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final e in out) e.$1];
}
