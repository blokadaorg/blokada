import 'package:common/plus/module/gateway/gateway.dart';

const fixtureGatewayEndpoint = '''
{
   "gateways":[
      {
         "public_key":"hBcy2klMHBEEBkCbp1f+BCJXq5WZvqfHxTHT/wV1SU4=",
         "region":"europe-west1",
         "location":"madrid",
         "country":"ES",
         "resource_usage_percent":3,
         "ipv4":"146.70.74.94",
         "ipv6":"2001:ac8:23:81::2",
         "port":51820,
         "expires":"2023-05-31T15:55:38.28421Z",
         "tags":null
      },
      {
         "public_key":"9EkWecXwOvJQ0dMt1L4wFIDuJm354PZVySpQf6W3IxY=",
         "region":"asia-northeast1",
         "location":"tokyo",
         "country":"JP",
         "resource_usage_percent":4,
         "ipv4":"185.242.4.142",
         "ipv6":"2001:ac8:40:a::2",
         "port":51820,
         "expires":"2023-05-31T15:56:20.344893Z",
         "tags":null
      },
      {
         "public_key":"138GYchUe81EwLE5QlLTrlhLgHS2YWDMQaCC3l3amzs=",
         "region":"europe-west2",
         "location":"london",
         "country":"GB",
         "resource_usage_percent":9,
         "ipv4":"193.9.113.86",
         "ipv6":"2001:ac8:31:fb::2",
         "port":51820,
         "expires":"2023-05-31T15:57:40.249499Z",
         "tags":null
      },
      {
         "public_key":"2lwdwha+k+t/GJeefhsnAd8vpADwQs7Q6jwu3r7kPw4=",
         "region":"europe-east1",
         "location":"sofia",
         "country":"BG",
         "resource_usage_percent":1,
         "ipv4":"146.70.53.6",
         "ipv6":"2001:ac8:30:37::2",
         "port":51820,
         "expires":"2023-05-31T15:58:05.828058Z",
         "tags":null
      },
      {
         "public_key":"eJxu+kfXfJC+h/N4juXyjqxr/al9VzSoo985BQ+AjhQ=",
         "region":"europe-west1",
         "location":"frankfurt",
         "country":"DE",
         "resource_usage_percent":16,
         "ipv4":"185.130.184.90",
         "ipv6":"2001:ac8:20:ff40:ae1f:6bff:fe81:a2ca",
         "port":51820,
         "expires":"2023-05-31T15:58:06.553802Z",
         "tags":null
      },
      {
         "public_key":"BRNIq/i7USFQlqC9HkywNGwJRlYB7GZKV+Jxl1iyCWU=",
         "region":"australia-southeast1",
         "location":"sydney",
         "country":"AU",
         "resource_usage_percent":3,
         "ipv4":"103.77.232.158",
         "ipv6":"2407:a080:7000:108::1",
         "port":51820,
         "expires":"2023-05-31T15:59:09.944417Z",
         "tags":null
      },
      {
         "public_key":"+uO0A2ILMsuPkSGyduY+D2kwmTkSIHwyiGPAetOzLUU=",
         "region":"europe-west1",
         "location":"amsterdam",
         "country":"NL",
         "resource_usage_percent":10,
         "ipv4":"45.148.16.146",
         "ipv6":"2a0c:dd44:1::146",
         "port":51820,
         "expires":"2023-05-31T15:59:15.972503Z",
         "tags":null
      },
      {
         "public_key":"gnUtzlyaPJU+K2bbVBcdV9VmNtltjncLycxxl/gbN00=",
         "region":"europe-west1",
         "location":"paris",
         "country":"FR",
         "resource_usage_percent":5,
         "ipv4":"45.152.181.242",
         "ipv6":"2001:ac8:25:a3::2",
         "port":51820,
         "expires":"2023-05-31T16:01:36.556732Z",
         "tags":null
      },
      {
         "public_key":"EtuIKAia0LzTyYSeqeYmZQR0h3hFvnA2mnkE6LkM6DU=",
         "region":"asia-west1",
         "location":"dubai",
         "country":"AE",
         "resource_usage_percent":2,
         "ipv4":"176.125.231.66",
         "ipv6":"2001:ac8:81:20::2",
         "port":51820,
         "expires":"2023-05-31T16:03:37.025419Z",
         "tags":null
      },
      {
         "public_key":"knY8Eisf4LNFi+NTlaGT3jZc7QIHlUTh8WoJB2UxN28=",
         "region":"asia-southeast1",
         "location":"singapore",
         "country":"SG",
         "resource_usage_percent":3,
         "ipv4":"91.245.253.186",
         "ipv6":"2a0a:b640:1:89::2",
         "port":51820,
         "expires":"2023-05-31T16:04:03.788083Z",
         "tags":null
      },
      {
         "public_key":"cGo+taHf0LPfpZijll4rW66BF75AcgJfrS3VNcoYg18=",
         "region":"northamerica-northeast1",
         "location":"montreal",
         "country":"CA",
         "resource_usage_percent":6,
         "ipv4":"5.181.233.198",
         "ipv6":"2a0d:5600:9:b1::2",
         "port":51820,
         "expires":"2023-05-31T16:05:01.902912Z",
         "tags":null
      },
      {
         "public_key":"y/0DXfXCGVrlhSkGrkd7ArJoMhdon5DLhWit3obwIzw=",
         "region":"europe-north1",
         "location":"stockholm",
         "country":"SE",
         "resource_usage_percent":5,
         "ipv4":"46.227.65.29",
         "ipv6":"2a03:8600:0:110::29",
         "port":51820,
         "expires":"2023-05-31T16:06:58.068928Z",
         "tags":null
      },
      {
         "public_key":"Q0dRNNZRa03K2w+22Dkzky1nqvgtdwEo06DuEscxtHE=",
         "region":"europe-west1",
         "location":"milano",
         "country":"IT",
         "resource_usage_percent":2,
         "ipv4":"146.70.73.150",
         "ipv6":"2001:ac8:24:84::2",
         "port":51820,
         "expires":"2023-05-31T16:07:21.882604Z",
         "tags":null
      },
      {
         "public_key":"B7wOkgvVr9z+vVn3ysiKyftIu/Wd0aAO382BA/bJMFI=",
         "region":"europe-west1",
         "location":"zurich",
         "country":"CH",
         "resource_usage_percent":10,
         "ipv4":"45.12.222.146",
         "ipv6":"2001:ac8:28:e::2",
         "port":51820,
         "expires":"2023-05-31T16:08:49.943421Z",
         "tags":null
      },
      {
         "public_key":"5GijFa1wHQ2AusEz9vkzF5bID5VZoqn2nNBORRx+vSo=",
         "region":"us-west1",
         "location":"los-angeles",
         "country":"US",
         "resource_usage_percent":18,
         "ipv4":"38.95.110.6",
         "ipv6":"2a0d:5600:8:2d::2",
         "port":51820,
         "expires":"2023-05-31T16:09:48.355352Z",
         "tags":null
      },
      {
         "public_key":"roYqLAeSM6pJeg398E5757mFfHEiV9r0IO67dPOFFww=",
         "region":"us-central1",
         "location":"denver",
         "country":"US",
         "resource_usage_percent":4,
         "ipv4":"84.17.63.169",
         "ipv6":"2a02:6ea0:d70e::1",
         "port":51820,
         "expires":"2023-05-31T16:09:53.635191Z",
         "tags":null
      },
      {
         "public_key":"hO25cJ88KQ8uQZ0Tn71ibz7wUbnvFecmHWgqXzr7IAc=",
         "region":"us-central1",
         "location":"dallas",
         "country":"US",
         "resource_usage_percent":20,
         "ipv4":"194.110.112.230",
         "ipv6":"2001:ac8:9a:1b::2",
         "port":51820,
         "expires":"2023-05-31T16:11:49.664958Z",
         "tags":null
      },
      {
         "public_key":"H1TTLm88Zm+fLF3drKPO+wPHG8/d5FkuuOOt+PHVJ3g=",
         "region":"europe-west1",
         "location":"frankfurt",
         "country":"DE",
         "resource_usage_percent":17,
         "ipv4":"45.87.212.230",
         "ipv6":"2001:ac8:20:ff40:ae1f:6bff:fef1:16ba",
         "port":51820,
         "expires":"2023-05-31T16:13:26.950386Z",
         "tags":null
      },
      {
         "public_key":"sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4=",
         "region":"us-east1",
         "location":"new-york",
         "country":"US",
         "resource_usage_percent":29,
         "ipv4":"45.152.180.138",
         "ipv6":"2a0d:5600:24:df::2",
         "port":51820,
         "expires":"2023-05-31T16:13:49.278954Z",
         "tags":null
      }
   ]
}
''';

final fixtureGatewayEntries = [
  JsonGateway(
    publicKey: 'hO25cJ88KQ8uQZ0Tn71ibz7wUbnvFecmHWgqXzr7IAc=',
    region: 'us-central1',
    location: 'dallas',
    country: 'US',
    resourceUsagePercent: 5,
    ipv4: '194.110.112.230',
    ipv6: '2001:ac8:9a:1b::2',
    port: 51820,
  ),
  JsonGateway(
    publicKey: 'H1TTLm88Zm+fLF3drKPO+wPHG8/d5FkuuOOt+PHVJ3g=',
    region: 'europe-west1',
    location: 'frankfurt',
    country: 'DE',
    resourceUsagePercent: 1,
    ipv4: '45.87.212.230',
    ipv6: '2001:ac8:20:ff40:ae1f:6bff:fef1:16ba',
    port: 51820,
  ),
  JsonGateway(
    publicKey: 'sSYTK8M4BOzuFpEPo2QXEzTZ+TDT5XMOzhN2Xk7A5B4=',
    region: 'us-east1',
    location: 'new-york',
    country: 'US',
    resourceUsagePercent: 5,
    ipv4: '45.152.180.138',
    ipv6: '2a0d:5600:24:df::2',
    port: 51820,
  ),
];
