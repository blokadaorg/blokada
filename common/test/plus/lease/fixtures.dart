import 'package:common/custom/json.dart';
import 'package:common/plus/lease/json.dart';

const fixtureLeaseEndpoint = '''
{
   "leases":[
      {
         "account_id":"mockedmocked",
         "public_key":"6fJ02Kot2groEpWk5c2onSHm0as3K2GJ2ljE9f70TFk=",
         "gateway_id":"sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4=",
         "expires":"2023-06-08T06:46:36.023583Z",
         "vip4":"10.143.0.142",
         "vip6":"fdad:b10c:a::a8f:8e",
         "alias":"Solar quokka",
         "devicetag":""
      }
   ]
}
''';

final fixtureLeaseEntries = [
  JsonLease(
    accountId: "mockedmocked",
    publicKey: "6fJ02Kot2groEpWk5c2onSHm0as3K2GJ2ljE9f70TFk=",
    gatewayId: "sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4=",
    expires: "2023-06-08T06:46:36.023583Z",
    vip4: "10.143.0.142",
    vip6: "fdad:b10c:a::a8f:8e",
    alias: "Solar quokka",
  ),
  JsonLease(
    accountId: "mockedmocked",
    publicKey: "aaJ02Kot2groEpWk5c2onSHm0as3K2GJ2ljE9f70TFk=",
    gatewayId: "hO25cJ88KQ8uQZ0Tn71ibz7wUbnvFecmHWgqXzr7IAc=",
    expires: "2023-06-08T06:46:36.023583Z",
    vip4: "10.143.0.143",
    vip6: "fdad:b10c:a::a8f:8c",
    alias: "device2",
  ),
  JsonLease(
    accountId: "mockedmocked",
    publicKey: "bbJ02Kot2groEpWk5c2onSHm0as3K2GJ2ljE9f70TFk=",
    gatewayId: "H1TTLm88Zm+fLF3drKPO+wPHG8/d5FkuuOOt+PHVJ3g=",
    expires: "2023-06-08T06:46:36.023583Z",
    vip4: "10.143.0.144",
    vip6: "fdad:b10c:a::a8f:8f",
    alias: "device3",
  )
];
