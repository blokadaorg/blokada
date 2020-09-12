use std::net::IpAddr;
use std::sync::{Arc, Mutex};
use std::time::Duration;

#[macro_use]
extern crate log;

use tokio::runtime::Builder;

use doh_dns::DnsHttpsServer;

use trust_dns_client::op::{LowerQuery, Query};
use trust_dns_client::rr::dnssec::SupportedAlgorithms;
use trust_dns_client::rr::Name;
use trust_dns_server::authority::Authority;

use rand::distributions::Alphanumeric;
use rand::{thread_rng, Rng};

use blocka_dns::authority::*;
use blocka_dns::runtime::Resolver;
use util;

fn main() {
  util::logger(&format!(
    "named={level},trust_dns_client={level},trust_dns_server={level},trust_dns_proto={level},trust_dns_https={level},trust_dns_resolver={level},engine={level},blocka_api={level},blocka_dns={level}",
    level = "debug"
  ));
  let mut runtime = Builder::new()
    .basic_scheduler()
    .enable_all()
    .build()
    .unwrap();

  let dns_name = "cloudflare-dns.com";
  let dns_ips: Vec<IpAddr> = vec!["1.1.1.1".parse().unwrap()];
  let ns = vec![DnsHttpsServer::new(
    dns_name.into(),
    "dns-query".into(),
    dns_ips,
    Duration::from_secs(10),
  )];
  let resolver = Arc::new(Resolver::new(ns, runtime.handle()).unwrap());
  let blocklist = FileList::new(
    "/Users/johnny/Documents/Blocka/fem/blocka_engine/blocka_dns/src/test-data/hosts.txt",
    ListType::Blacklist,
  )
  .unwrap();
  let cached_list = Arc::new(Mutex::new(with_cache(blocklist, 250)));
  let blocka_forwarder =
    BlockaAuthority::new(Name::root(), Arc::clone(&resolver), cached_list.clone());

  runtime.block_on(async {
    for _ in 0..2 {
      let rand_string: String = thread_rng().sample_iter(&Alphanumeric).take(40).collect();

      let mut query = Query::default();
      query.set_name(format!("{}.ipleak.net.", rand_string).parse().unwrap());
      let lookup = blocka_forwarder.search(
        &LowerQuery::from(query),
        false,
        SupportedAlgorithms::default(),
      );
      lookup.await.unwrap();
      resolver.toggle(Some(true)).await;
      resolver.toggle(Some(false)).await;
    }
  });

  info!("all done");
}
