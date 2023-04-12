import 'package:common/custom/json.dart';

const fixtureCustomEndpoint = '''
{
   "customlist":[
      {
         "domain_name":"bad.actor.is.bad.com",
         "wildcard":false,
         "action":"block"
      },
      {
         "domain_name":"another.bad.com",
         "wildcard":false,
         "action":"block"
      },
      {
         "domain_name":"8ed21ffb-dnsotls-ds.metric.gstatic.com",
         "wildcard":false,
         "action":"block"
      },
      {
         "domain_name":"events.ocdn.eu",
         "wildcard":false,
         "action":"allow"
      },
      {
         "domain_name":"something.good.eu",
         "wildcard":false,
         "action":"allow"
      }
   ]
}
''';

final fixtureCustomEntries = [
  JsonCustomEntry(domainName: "example.com", action: "allow"),
  JsonCustomEntry(domainName: "abc.example.com", action: "fallthrough"),
  JsonCustomEntry(domainName: "cde.example.com", action: "fallthrough"),
  JsonCustomEntry(domainName: "sth.io", action: "block"),
  JsonCustomEntry(domainName: "abc.sth.io", action: "block"),
  JsonCustomEntry(domainName: "cde.sth.io", action: "block"),
  JsonCustomEntry(domainName: "efg.sth.io", action: "block"),
];
