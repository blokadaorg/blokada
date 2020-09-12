use std::net::{IpAddr, SocketAddr};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use tokio::net::UdpSocket;
use tokio::runtime::Builder;

use doh_dns::DnsHttpsServer;
use trust_dns_client::rr::Name;
use trust_dns_server::authority::Catalog;
#[cfg(feature = "dns-over-tls")]
use trust_dns_server::server::ServerFuture;

use blocka_dns::authority::*;
use blocka_dns::runtime::Resolver;
use util;

pub enum DNSMode {
  CLEAR,
  TLS,
  HTTPS,
}

fn main() {
  util::logger(&format!(
    "doh_dns={level},named={level},trust_dns_client={level},trust_dns_server={level},trust_dns_proto={level},trust_dns_https={level},trust_dns_resolver={level},engine={level},blocka_api={level},blocka_dns={level}",
    level = "debug"
  ));

  let listen_addr = "127.0.0.1:5999".parse::<SocketAddr>().unwrap();
  let mut runtime = Builder::new()
    .threaded_scheduler()
    .core_threads(1)
    .enable_all()
    .build()
    .unwrap();

  let dns_name = "cloudflare-dns.com";
  let dns_ips: Vec<IpAddr> = vec![
    "1.1.1.1".parse().unwrap(),
    "2606:4700:4700::1111".parse().unwrap(),
  ];
  let dns_mode = DNSMode::HTTPS;

  let ns = match dns_mode {
    DNSMode::HTTPS => vec![DnsHttpsServer::new(
      dns_name.into(),
      "dns-query".into(),
      dns_ips,
      Duration::from_secs(10),
    )],
    DNSMode::CLEAR => todo!(),
    DNSMode::TLS => todo!(),
  };

  let blocklist: Box<dyn Blocklist> = Box::new(with_cache(
    FileList::new("src/test-data/hosts.txt", ListType::Blacklist).unwrap(),
    250,
  ));
  let resolver = Resolver::new(ns, runtime.handle()).unwrap();
  runtime.block_on(resolver.toggle(Some(true)));

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

  let h = runtime.spawn(async move {
    server.register_socket(udp_socket);
    match server.block_until_done().await {
      Err(e) => {
        println!("server error: {:?}", e);
      }
      Ok(_) => (),
    }
  });

  runtime.block_on(h).unwrap();
}
