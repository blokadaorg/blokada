// use std::ffi::CString;
// use std::io;
// use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::str::FromStr;
use std::sync::Arc;
use std::time::{Duration, Instant};

use trust_dns_client::op::Query;
use trust_dns_client::rr::{LowerName, Name, RecordType};
use trust_dns_proto::rr::domain::Name as DomainName;
use trust_dns_proto::{
  rr::rdata::mx, rr::rdata::soa, rr::rdata::srv, rr::rdata::txt, rr::RData, rr::Record,
};
// use trust_dns_resolver::config::NameServerConfigGroup;
use trust_dns_resolver::error::{ResolveError, ResolveErrorKind};
use trust_dns_resolver::lookup::Lookup;

use doh_dns::{client::DnsClient, error::DnsError, status::RCode, Dns, DnsAnswer, DnsHttpsServer};

use tokio::runtime::Handle;
use tokio::sync::{RwLock, Semaphore};

use crate::connector::{new_default, new_tunneled, TunneledHyperClient};

enum ResolverSelection {
  DefaultRoute(Dns),
  Tunneled(Dns<TunneledHyperClient>),
  None,
}

pub struct Resolver {
  name_servers: Vec<DnsHttpsServer>,
  inner: RwLock<ResolverSelection>,
  permit: Semaphore,
}

impl Resolver {
  pub fn new(
    name_servers: Vec<DnsHttpsServer>,
    _runtime: &Handle,
  ) -> Result<Resolver, ResolveError> {
    Ok(Resolver {
      inner: RwLock::new(ResolverSelection::DefaultRoute(new_default(
        name_servers.clone(),
      ))),
      permit: Semaphore::new(50),
      name_servers,
    })
  }

  pub async fn lookup(&self, name: LowerName, rtype: RecordType) -> Result<Lookup, ResolveError> {
    debug!("resolver waiting for permit");
    // Avoid hitting the memory limit by throttling pending lookups.
    let _permit = self.permit.acquire();
    debug!("resolver waiting for read lock");
    let name = Name::from(name);
    let result: Result<Vec<DnsAnswer>, DnsError> = match &*self.inner.read().await {
      ResolverSelection::None => {
        error!("lookup while resolver is disabled");
        return Err(ResolveError::from(ResolveErrorKind::Message(
          "resolver is disabled",
        )));
      }
      ResolverSelection::Tunneled(resolver) => {
        debug!("resolver performing tunneled lookup");
        lookup_to_doh_resolve(resolver, name.to_ascii(), rtype).await
      }
      ResolverSelection::DefaultRoute(resolver) => {
        debug!("resolver performing default lookup");
        lookup_to_doh_resolve(resolver, name.to_ascii(), rtype).await
      }
    };

    let q = Query::query(name, rtype);
    match result {
      Ok(records) => {
        let lookup = doh_records_to_lookup(q, records)?;
        for record in lookup.record_iter() {
          debug!("return record: {:?}", record);
        }
        Ok(lookup)
      }
      Err(e) => match e {
        DnsError::Status(RCode::NXDomain) => {
          Err(ResolveError::from(ResolveErrorKind::NoRecordsFound {
            query: q,
            valid_until: None,
          }))
        }
        _ => Err(ResolveError::from(ResolveErrorKind::Msg(format!(
          "error resolving: {}",
          e
        )))),
      },
    }
  }

  pub async fn toggle(&self, tunneled: Option<bool>) {
    info!("toggle waiting for read lock");
    let needs_update = match &*self.inner.read().await {
      ResolverSelection::Tunneled(_) => match tunneled {
        Some(tunneled) => tunneled == false,
        None => true,
      },
      ResolverSelection::DefaultRoute(_) => match tunneled {
        Some(tunneled) => tunneled == true,
        None => true,
      },
      ResolverSelection::None => tunneled != None,
    };
    if !needs_update {
      info!("toggle noop");
      return;
    }

    info!("toggle waiting for write lock");
    let selected = &mut *self.inner.write().await;
    *selected = match tunneled {
      Some(tunneled) => {
        if tunneled {
          info!("toggle tunneled DNS");
          ResolverSelection::Tunneled(Dns::new(new_tunneled(self.name_servers.clone())))
        } else {
          info!("toggle default DNS");
          ResolverSelection::DefaultRoute(new_default(self.name_servers.clone()))
        }
      }
      None => {
        info!("toggle disabled DNS");
        ResolverSelection::None
      }
    }
  }
}

async fn lookup_to_doh_resolve<C: DnsClient>(
  resolver: &Dns<C>,
  name: String,
  rtype: RecordType,
) -> Result<Vec<DnsAnswer>, DnsError> {
  match rtype {
    RecordType::A => resolver.resolve_a(&name).await,
    RecordType::AAAA => resolver.resolve_aaaa(&name).await,
    RecordType::CNAME => resolver.resolve_cname(&name).await,
    RecordType::MX => resolver.resolve_mx(&name).await,
    RecordType::NAPTR => resolver.resolve_naptr(&name).await,
    RecordType::NS => resolver.resolve_ns(&name).await,
    RecordType::PTR => resolver.resolve_ptr(&name).await,
    RecordType::SOA => resolver.resolve_soa(&name).await,
    RecordType::SRV => resolver.resolve_srv(&name).await,
    RecordType::TXT => resolver.resolve_txt(&name).await,
    RecordType::TLSA => resolver.resolve_tlsa(&name).await,
    RecordType::CAA => resolver.resolve_caa(&name).await,
    RecordType::SSHFP => resolver.resolve_sshfp(&name).await,
    // TODO: dnssec types
    // RecordType::DNSSEC(rtype) => match rtype {
    // }
    RecordType::Unknown(rtype) => {
      if rtype == 65 {
        // Reduce error log spam for this known issue on iOS 14.
        debug!("HTTPS record type not implemented");
        return Ok(vec![]);
      } else {
        error!("unknown or invalid record type: {:?}", rtype);
      }
      return Err(DnsError::InvalidRecordType);
    }
    _ => {
      info!("valid but not yet supported record type: {:?}", rtype);
      return Err(DnsError::InvalidRecordType);
    }
  }
}

fn doh_records_to_lookup(
  query: Query,
  doh_records: Vec<DnsAnswer>,
) -> Result<Lookup, ResolveError> {
  let parse_error = |e| format!("error parsing: {}", e);
  let rdata = |data: &str, rtype: RecordType| match rtype {
    RecordType::A => Ok(RData::A(data.parse().map_err(parse_error)?)),
    RecordType::AAAA => Ok(RData::AAAA(data.parse().map_err(parse_error)?)),
    RecordType::CNAME => Ok(RData::CNAME(DomainName::from_str(data)?)),
    RecordType::MX => {
      let mut parts = data.split_ascii_whitespace();
      if let (Some(part_1), Some(part_2)) = (parts.next(), parts.next()) {
        if let (Ok(prio), Ok(name)) = (part_1.parse::<u16>(), part_2.parse::<Name>()) {
          return Ok(RData::MX(mx::MX::new(prio, name)));
        }
      }
      Err("invalid MX data".to_string())
    }
    // RecordType::NAPTR => rr.set_rdata(RData::NAPTR(r.data.parse().unwrap())),
    RecordType::NS => Ok(RData::NS(data.parse()?)),
    RecordType::PTR => Ok(RData::PTR(data.parse()?)),
    RecordType::SOA => {
      let mut parts = data.split_ascii_whitespace();
      let mname = parts
        .next()
        .and_then(|n| n.parse::<Name>().ok())
        .ok_or("invalid mname")?;
      let rname = parts
        .next()
        .and_then(|n| n.parse::<Name>().ok())
        .ok_or("invalid rname")?;
      let serial = parts
        .next()
        .and_then(|n| n.parse::<u32>().ok())
        .ok_or("invalid serial")?;
      let refresh = parts
        .next()
        .and_then(|n| n.parse::<i32>().ok())
        .ok_or("invalid refresh")?;
      let retry = parts
        .next()
        .and_then(|n| n.parse::<i32>().ok())
        .ok_or("invalid retry")?;
      let expire = parts
        .next()
        .and_then(|n| n.parse::<i32>().ok())
        .ok_or("invalid expire")?;
      let minimum = parts
        .next()
        .and_then(|n| n.parse::<u32>().ok())
        .ok_or("invalid minimum")?;

      Ok(RData::SOA(soa::SOA::new(
        mname, rname, serial, refresh, retry, expire, minimum,
      )))
    }
    RecordType::TXT => Ok(RData::TXT(txt::TXT::new(vec![data
      .trim_matches('"')
      .to_string()]))),
    RecordType::SRV => {
      // priority: u16, weight: u16, port: u16, target: Name
      let mut parts = data.split_ascii_whitespace();
      let priority = parts
        .next()
        .and_then(|n| n.parse::<u16>().ok())
        .ok_or("invalid priority")?;
      let weight = parts
        .next()
        .and_then(|n| n.parse::<u16>().ok())
        .ok_or("invalid weight")?;
      let port = parts
        .next()
        .and_then(|n| n.parse::<u16>().ok())
        .ok_or("invalid port")?;
      let target = parts
        .next()
        .and_then(|n| n.parse::<Name>().ok())
        .ok_or("invalid target")?;

      Ok(RData::SRV(srv::SRV::new(priority, weight, port, target)))
    }
    // RecordType::TLSA => rr.set_rdata(RData::TLSA(r.data.parse().unwrap())),
    // RecordType::CAA => rr.set_rdata(RData::CAA(r.data.parse().unwrap())),
    // RecordType::SSHFP => rr.set_rdata(RData::SSHFP(r.data.parse().unwrap())),
    _ => {
      debug!("{}", data);
      Err("unsupported record type".to_string())
    }
  };

  let records: Vec<Record> = doh_records
    .iter()
    .filter_map(|r| {
      let rtype = RecordType::from(r.r#type as u16);
      let mut rr = Record::new();
      let name = match Name::from_str(&r.name) {
        Ok(name) => name,
        Err(e) => {
          debug!("could not parse domain name: {}", e);
          return None;
        }
      };
      rr.set_name(name).set_ttl(r.TTL).set_record_type(rtype);

      match rdata(&r.data, rtype) {
        Ok(rdata) => {
          rr.set_rdata(rdata);
          Some(rr)
        }
        Err(e) => {
          debug!("could not convert record data: {}", e);
          None
        }
      }
    })
    .collect();

  let ttl = match doh_records.iter().min_by_key(|r| r.TTL) {
    Some(r) => r.TTL,
    None => 10,
  };
  let valid_until = Instant::now() + Duration::from_secs(ttl.into());

  Ok(Lookup::new_with_deadline(
    query,
    Arc::new(records),
    valid_until,
  ))
}

//   async fn connect(addr: SocketAddr) -> Result<AsyncIo02As03<TimeoutStream<TcpStream>>, io::Error> {
//     let stream = timeout(Duration::from_secs(5), connect_tunnel(addr)).await?;
//     let mut stream = TimeoutStream::new(stream?);
//     // Work around for avoiding stalled connections when switching source IPs.
//     stream.set_read_timeout(Some(Duration::from_secs(5)));
//     stream.set_write_timeout(Some(Duration::from_secs(5)));
//     Ok(AsyncIo02As03(stream))
//   }
// }

// async fn connect_tunnel(addr: SocketAddr) -> Result<TcpStream, io::Error> {
//   task::spawn_blocking(move || {
//     // Only bind if we're not connecting to a DNS server on a private network.
//     let is_private = match addr.ip() {
//       IpAddr::V4(ip) => ip.is_private(),
//       IpAddr::V6(_) => false, // uncommon, assume it's not.
//     };

//     // Figure out which tunnel interface to bind on.
//     let nics = network::IfAddrs::get()?;
//     let tunnel = nics
//       .iter()
//       .filter(|nic| nic.name().contains("tun"))
//       .find(|nic| match nic.addr() {
//         Some(IpAddr::V4(ip)) => !ip.is_loopback(),
//         Some(IpAddr::V6(_)) => false,
//         None => false,
//       })
//       .map(|nic| (nic.name(), nic.addr()));

//     match tunnel {
//       Some((name, Some(addr))) => info!("binding nameserver connection to {} ({})", name, addr),
//       Some((name, None)) => warn!("binding nameserver connection to {} (no addr set?)", name),
//       None => warn!("couldn't figure out a tun interface to bind on"),
//     }

//     let index = |name| {
//       let name = CString::new(name)?;
//       let index = unsafe { libc::if_nametoindex(name.as_ptr()) };
//       if index == 0 {
//         Err(io::Error::new(
//           io::ErrorKind::NotFound,
//           "interface was not found",
//         ))
//       } else {
//         Ok(index)
//       }
//     };

//     let socket = if addr.is_ipv4() {
//       let s = Socket::new(Domain::IPV4, Type::STREAM, None)?;
//       // Only bind to tunnel interface if we're not targeting a private network.
//       if !is_private {
//         if let Some((name, _)) = tunnel {
//           s.set_bound_interface(index(name)?)?;
//         }
//       }
//       s
//     } else {
//       let s = Socket::new(Domain::IPV6, Type::STREAM, None)?;
//       // TODO: check if private network.
//       if let Some((name, _)) = tunnel {
//         s.set_bound_interface_v6(index(name)?)?;
//       }
//       s
//     };

//     socket.connect(&addr.into())?;
//     TcpStream::from_std(socket.into_tcp_stream())
//   })
//   .await?
// }

#[cfg(test)]
mod test {
  use doh_dns::{Dns, DnsHttpsServer};
  use std::time::Duration;

  #[tokio::test]
  async fn doh_servers() {
    let cloudflare = (
      "cloudflare",
      Some(DnsHttpsServer::new(
        "cloudflare-dns.com".into(),
        "dns-query".into(),
        vec![
          "1.1.1.1".parse().unwrap(),
          "2606:4700:4700::1111".parse().unwrap(),
        ],
        Duration::from_secs(1),
      )),
    );
    let google = (
      "google",
      Some(DnsHttpsServer::new(
        "dns.google".into(),
        "resolve".into(),
        vec!["8.8.8.8".parse().unwrap()],
        Duration::from_secs(1),
      )),
    );
    let _gesellschaft = (
      "gesellschaft",
      Some(DnsHttpsServer::new(
        "dns.digitale-gesellschaft.ch".into(),
        "dns-query".into(),
        vec![
          "185.95.218.42".parse().unwrap(),
          "2a05:fc84::42".parse().unwrap(),
          "185.95.218.43".parse().unwrap(),
          "2a05:fc84::43".parse().unwrap(),
        ],
        Duration::from_secs(1),
      )),
    );
    let _opendns = (
      "opendns",
      Some(DnsHttpsServer::new(
        "doh.opendns.com".into(),
        "dns-query".into(),
        vec!["208.67.220.220".parse().unwrap()],
        Duration::from_secs(5),
      )),
    );
    let _opendns_family = (
      "opendns family",
      Some(DnsHttpsServer::new(
        "doh.opendns.com".into(),
        "dns-query".into(),
        vec!["208.67.222.123".parse().unwrap()],
        Duration::from_secs(5),
      )),
    );
    let _opennic_usa = (
      "opennic usa",
      Some(DnsHttpsServer::new(
        "ns03.dns.tin-fan.com".into(),
        "dns-query".into(),
        vec![
          "155.138.240.237".parse().unwrap(),
          "2001:19f0:6401:b3d:5400:2ff:fe5a:fb9f".parse().unwrap(),
        ],
        Duration::from_secs(5),
      )),
    );
    let _opennic_eu = (
      "opennic eu",
      Some(DnsHttpsServer::new(
        "ns01.dns.tin-fan.com".into(),
        "dns-query".into(),
        vec![
          "95.217.16.205".parse().unwrap(),
          "2a01:4f9:c010:6093::3485".parse().unwrap(),
        ],
        Duration::from_secs(5),
      )),
    );

    let mut servers = [
      google,
      cloudflare,
      // TODO #927: require DoH according to RFC 8484 support
      // gesellschaft,
      // opendns,
      // opendns_family,
      // opennic_eu,
      // opennic_usa,
    ];
    for server in &mut servers {
      println!("using: {}", server.0);
      let resolver = Dns::with_servers(vec![server.1.take().unwrap()]).unwrap();
      let res = resolver.resolve_a("nic.at").await.unwrap();
      assert_ne!(0, res.len())
    }
  }

  #[tokio::test]
  async fn test_txt() {
    let resolver = Dns::default();
    let result = resolver.resolve_txt("blokada.org").await.unwrap();
    for txt in result {
      println!("txt: '{}'", txt.data);
    }
  }
}
