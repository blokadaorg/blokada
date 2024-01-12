import 'package:common/fsm/filter/json.dart';
import 'package:flutter_test/flutter_test.dart';

const fixtureListEndpoint = '''
{
   "lists":[
      {
         "id":"03489ad60c13b83a55203c804a1567df",
         "name":"mirror/v5/1hosts/litea/hosts.txt",
         "managed":true,
         "is_allowlist":false
      },
      {
         "id":"03c351a2112a6633572fd2783f8ec48a",
         "name":"mirror/v5/1hosts/lite (wildcards)/hosts.txt",
         "managed":true,
         "is_allowlist":false
      },
      {
         "id":"03e5eb8609122f03dbb25ffd7dcffad3",
         "name":"mirror/v5/goodbyeads/spotify/hosts.txt",
         "managed":true,
         "is_allowlist":false
      },
      {
         "id":"06247a106b4f2a8d61425bd1bb26c753",
         "name":"mirror/v5/developerdan/hate and junk/hosts.txt",
         "managed":true,
         "is_allowlist":false
      },
      {
         "id":"0c8219b05b5acce612330cb184280d56",
         "name":"mirror/v5/1hosts/lite/hosts.txt",
         "managed":true,
         "is_allowlist":false
      },
      {
         "id":"13dce58452a4f348753210babe2a5d63",
         "name":"mirror/v5/cpbl/mini/hosts.txt",
         "managed":true,
         "is_allowlist":false
      },
      {
         "id":"1ad38ab1248b187d8fefafe95b666044",
         "name":"mirror/v5/stevenblack/adult/hosts.txt",
         "managed":true,
         "is_allowlist":false
      },
      {
         "id":"2034b164ce8e64953de05746a2aa836a",
         "name":"mirror/v5/oisd/light/hosts.txt",
         "managed":true,
         "is_allowlist":false
      },
      {
         "id":"269fd419e7b5093a60fe14f3288085ad",
         "name":"mirror/v5/1hosts/proa/hosts.txt",
         "managed":true,
         "is_allowlist":false
      },
      {
         "id":"27fe756366ce4e2a5b2f13b958b61861",
         "name":"mirror/v5/energized/basic/hosts.txt",
         "managed":true,
         "is_allowlist":false
      },
      {
         "id":"2f4f20d4006019029c19585c218df65d",
         "name":"mirror/v5/blocklist/youtube/hosts.txt",
         "managed":true,
         "is_allowlist":false
      },
      {
         "id":"3309fb926cecf32de027dce2e4871a6e",
         "name":"mirror/v5/blocklist/phishing/hosts.txt",
         "managed":true,
         "is_allowlist":false
      },
      {
         "id":"33b3bc8d3a16d5642c1c45ec38979d7c",
         "name":"mirror/v5/blacklist/adservers/hosts.txt",
         "managed":true,
         "is_allowlist":false
      },
      {
         "id":"3697b5b5691b532b20394c5e922fee3e",
         "name":"mirror/v5/goodbyeads/xiaomi/hosts.txt",
         "managed":true,
         "is_allowlist":false
      }
   ]
}
''';

final fixtureListItems = [
  JsonListItem(
    id: "1",
    path: "mirror/v5/1hosts/litea/hosts.txt",
    vendor: "1hosts",
    variant: "litea",
    managed: true,
    allowlist: false,
  ),
  JsonListItem(
    id: "2",
    path: "mirror/v5/1hosts/lite (wildcards)/hosts.txt",
    vendor: "1hosts",
    variant: "lite (wildcards)",
    managed: true,
    allowlist: false,
  ),
  JsonListItem(
    id: "3",
    path: "mirror/v5/goodbyeads/spotify/hosts.txt",
    vendor: "goodbyeads",
    variant: "spotify",
    managed: true,
    allowlist: false,
  ),
  JsonListItem(
    id: "4",
    path: "mirror/v5/developerdan/hate and junk/hosts.txt",
    vendor: "developerdan",
    variant: "hate and junk",
    managed: true,
    allowlist: false,
  ),
  JsonListItem(
    id: "5",
    path: "mirror/v5/1hosts/lite/hosts.txt",
    vendor: "1hosts",
    variant: "lite",
    managed: true,
    allowlist: false,
  ),
  JsonListItem(
    id: "6",
    path: "mirror/v5/cpbl/mini/hosts.txt",
    vendor: "cpbl",
    variant: "mini",
    managed: true,
    allowlist: false,
  )
];
