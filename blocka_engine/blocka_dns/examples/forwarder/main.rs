use std::net::{IpAddr, SocketAddr};
use std::sync::{Arc, Mutex};

use tokio::net::UdpSocket;
use tokio::runtime::Builder;

#[cfg(feature = "resolver")]
use blocka_dns::authority::*;
use blocka_dns::runtime::new_resolver;
use trust_dns_client::client::{Client, SyncClient};
use trust_dns_client::rr::{DNSClass, Name, RecordType};
use trust_dns_client::udp::UdpClientConnection;
use trust_dns_resolver::config::NameServerConfigGroup;
use trust_dns_server::authority::Catalog;
#[cfg(feature = "dns-over-tls")]
use trust_dns_server::server::ServerFuture;

pub enum DNSMode {
  CLEAR,
  TLS,
  HTTPS,
}

fn main() {
  let listen_addr = "127.0.0.1:5999".parse::<SocketAddr>().unwrap();
  let mut runtime = Builder::new()
    .threaded_scheduler()
    .core_threads(1)
    .enable_all()
    .build()
    .unwrap();

  let dns_name = "cloudflare-dns.com";
  let dns_ips: Vec<IpAddr> = vec!["1.1.1.1".parse().unwrap()];
  let dns_mode = DNSMode::TLS;

  let ns = match dns_mode {
    DNSMode::CLEAR => NameServerConfigGroup::from_ips_clear(&dns_ips, 53),
    DNSMode::HTTPS => todo!(), // NameServerConfigGroup::from_ips_https(&dns_ips, 443, dns_name.to_string()),
    DNSMode::TLS => NameServerConfigGroup::from_ips_tls(&dns_ips, 853, dns_name.to_string()),
  };

  let blocklist: Box<dyn Blocklist> = Box::new(with_cache(
    FileList::new("src/test-data/hosts.txt", ListType::Blacklist).unwrap(),
    250,
  ));
  let resolver = new_resolver(ns, runtime.handle()).unwrap();
  let resolver = Arc::new(resolver);
  let blocka_forwarder = BlockaAuthority::new(
    Name::root(),
    Arc::clone(&resolver),
    Arc::new(Mutex::new(blocklist)),
  );

  let blocka_forwarder = Box::new(blocka_forwarder);
  let mut catalog: Catalog = Catalog::new();
  catalog.upsert(Name::root().into(), blocka_forwarder);

  let mut server = ServerFuture::new(catalog);

  let udp_socket = runtime.block_on(UdpSocket::bind(listen_addr)).unwrap();

  server.register_socket(udp_socket, &runtime);

  let h = runtime.spawn(async move {
    match server.block_until_done().await {
      Err(e) => {
        println!("server error: {:?}", e);
      }
      Ok(_) => (),
    }
  });

  // Client test loop part
  let conn = UdpClientConnection::new(listen_addr).unwrap();
  let client = SyncClient::new(conn);

  // Specify the name, note the final '.' which specifies it's an FQDN
  // let name: Name = "www.example.com.".parse().unwrap();

  for n in 0..200 {
    let name: Name = format!("{}.zendesk.com.", n).parse().unwrap();
    client.query(&name, DNSClass::IN, RecordType::A).unwrap();
  }

  runtime.block_on(h).unwrap();
}
