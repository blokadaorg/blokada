use std::ffi::CString;
use std::io;
use std::net::{IpAddr, SocketAddr};
use std::time::Duration;

use trust_dns_client::rr::{LowerName, RecordType};
use trust_dns_proto::xfer::DnsRequestOptions;
use trust_dns_proto::{iocompat::AsyncIo02As03, tcp::Connect, TokioTime};
use trust_dns_resolver::config::{NameServerConfigGroup, ResolverConfig, ResolverOpts};
use trust_dns_resolver::error::{ResolveError, ResolveErrorKind};
use trust_dns_resolver::lookup::Lookup;
use trust_dns_resolver::name_server::{
  GenericConnection, GenericConnectionProvider, RuntimeProvider, TokioRuntime,
};
use trust_dns_resolver::AsyncResolver;

use tokio::net::{TcpStream, UdpSocket};
use tokio::runtime::Handle;
use tokio::sync::{RwLock, Semaphore};
use tokio::task;
use tokio::time::timeout;
use tokio_io_timeout::TimeoutStream;

use async_trait::async_trait;
use socket2::*;

use crate::network;

enum ResolverSelection {
  DefaultRoute(AsyncResolver<GenericConnection, GenericConnectionProvider<TokioRuntime>>),
  Tunneled(AsyncResolver<GenericConnection, GenericConnectionProvider<TunnelRuntime>>),
}

pub struct Resolver {
  limit: Semaphore,
  inner_resolver: RwLock<ResolverSelection>,
  runtime: tokio::runtime::Handle,
  config: ResolverConfig,
  options: ResolverOpts,
}

impl Resolver {
  pub async fn lookup(
    &self,
    name: LowerName,
    rtype: RecordType,
    options: DnsRequestOptions,
  ) -> Result<Lookup, ResolveError> {
    debug!("resolver waiting for permit");
    let _permit = self.limit.acquire().await;

    debug!("resolver waiting for read lock");
    let res = match &*self.inner_resolver.read().await {
      ResolverSelection::Tunneled(resolver) => {
        debug!("resolver performing tunneled lookup");
        timeout(
          Duration::from_millis(15000),
          resolver.lookup(name, rtype, options),
        )
        .await
      }
      ResolverSelection::DefaultRoute(resolver) => {
        debug!("resolver performing default lookup");
        timeout(
          Duration::from_millis(15000),
          resolver.lookup(name, rtype, options),
        )
        .await
      }
    };

    match res {
      Ok(res) => res,
      Err(_) => Err(ResolveError::from(ResolveErrorKind::Timeout).into()),
    }
  }

  pub async fn toggle(&self, tunneled: bool) {
    info!("toggle waiting for read lock");
    let needs_update = match &*self.inner_resolver.read().await {
      ResolverSelection::Tunneled(_) => !tunneled,
      ResolverSelection::DefaultRoute(_) => tunneled,
    };
    if !needs_update {
      info!("toggle noop");
      return;
    }

    info!("toggle waiting for write lock");
    let selected = &mut *self.inner_resolver.write().await;
    *selected = if tunneled {
      info!("toggle tunneled DNS");
      ResolverSelection::Tunneled(
        AsyncResolver::new(self.config.clone(), self.options, self.runtime.clone()).unwrap(),
      )
    } else {
      info!("toggle default DNS");
      ResolverSelection::DefaultRoute(
        AsyncResolver::new(self.config.clone(), self.options, self.runtime.clone()).unwrap(),
      )
    }
  }
}

pub fn new_resolver(
  name_servers: NameServerConfigGroup,
  runtime: &Handle,
) -> Result<Resolver, ResolveError> {
  let config = ResolverConfig::from_parts(None, vec![], name_servers);
  let options = ResolverOpts {
    preserve_intermediates: true,
    ..ResolverOpts::default()
  };
  Ok(Resolver {
    limit: Semaphore::new(50),
    inner_resolver: RwLock::new(ResolverSelection::DefaultRoute(AsyncResolver::new(
      config.clone(),
      options,
      runtime.clone(),
    )?)),
    runtime: runtime.clone(),
    options,
    config,
  })
}

#[derive(Clone)]
pub struct TunnelRuntime;

impl RuntimeProvider for TunnelRuntime {
  type Handle = Handle;
  type Tcp = TunneledConnection;
  type Timer = TokioTime;
  // TODO: wrap UdpSocket for custom socket binding if we use CLEAR queries.
  type Udp = UdpSocket;
}

pub struct TunneledConnection {}

#[async_trait]
impl Connect for TunneledConnection {
  type Transport = AsyncIo02As03<TimeoutStream<TcpStream>>;

  async fn connect(addr: SocketAddr) -> Result<AsyncIo02As03<TimeoutStream<TcpStream>>, io::Error> {
    let stream = timeout(Duration::from_secs(5), connect_tunnel(addr)).await?;
    let mut stream = TimeoutStream::new(stream?);
    // Work around for avoiding stalled connections when switching source IPs.
    stream.set_read_timeout(Some(Duration::from_secs(5)));
    stream.set_write_timeout(Some(Duration::from_secs(5)));
    Ok(AsyncIo02As03(stream))
  }
}

async fn connect_tunnel(addr: SocketAddr) -> Result<TcpStream, io::Error> {
  task::spawn_blocking(move || {
    // Only bind if we're not connecting to a DNS server on a private network.
    let is_private = match addr.ip() {
      IpAddr::V4(ip) => ip.is_private(),
      IpAddr::V6(_) => false, // uncommon, assume it's not.
    };

    // Figure out which tunnel interface to bind on.
    let nics = network::IfAddrs::get()?;
    let tunnel = nics
      .iter()
      .filter(|nic| nic.name().contains("tun"))
      .find(|nic| match nic.addr() {
        Some(IpAddr::V4(ip)) => !ip.is_loopback(),
        Some(IpAddr::V6(_)) => false,
        None => false,
      })
      .map(|nic| (nic.name(), nic.addr()));

    match tunnel {
      Some((name, Some(addr))) => info!("binding nameserver connection to {} ({})", name, addr),
      Some((name, None)) => warn!("binding nameserver connection to {} (no addr set?)", name),
      None => warn!("couldn't figure out a tun interface to bind on"),
    }

    let index = |name| {
      let name = CString::new(name)?;
      let index = unsafe { libc::if_nametoindex(name.as_ptr()) };
      if index == 0 {
        Err(io::Error::new(
          io::ErrorKind::NotFound,
          "interface was not found",
        ))
      } else {
        Ok(index)
      }
    };

    let socket = if addr.is_ipv4() {
      let s = Socket::new(Domain::IPV4, Type::STREAM, None)?;
      // Only bind to tunnel interface if we're not targeting a private network.
      if !is_private {
        if let Some((name, _)) = tunnel {
          s.set_bound_interface(index(name)?)?;
        }
      }
      s
    } else {
      let s = Socket::new(Domain::IPV6, Type::STREAM, None)?;
      // TODO: check if private network.
      if let Some((name, _)) = tunnel {
        s.set_bound_interface_v6(index(name)?)?;
      }
      s
    };

    socket.connect(&addr.into())?;
    TcpStream::from_std(socket.into_tcp_stream())
  })
  .await?
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
    let cloudflare_malware = (
      "cloudflare malware",
      Some(DnsHttpsServer::new(
        "cloudflare-dns.com".into(),
        "dns-query".into(),
        vec![
          "1.1.1.2".parse().unwrap(),
          "2606:4700:4700::1112".parse().unwrap(),
        ],
        Duration::from_secs(1),
      )),
    );
    let cloudflare_adult = (
      "cloudflare adult",
      Some(DnsHttpsServer::new(
        "cloudflare-dns.com".into(),
        "dns-query".into(),
        vec![
          "1.1.1.3".parse().unwrap(),
          "2606:4700:4700::1113".parse().unwrap(),
        ],
        Duration::from_secs(1),
      )),
    );
    let gesellschaft = (
      "gesellschaft",
      Some(DnsHttpsServer::new(
        "dns.digitale-gesellschaft.ch".into(),
        "dns-query".into(),
        vec![
          "185.95.218.42".parse().unwrap(),
          "2a05:fc84::4".parse().unwrap(),
        ],
        Duration::from_secs(1),
      )),
    );
    let opendns = (
      "opendns",
      Some(DnsHttpsServer::new(
        "doh.opendns.com".into(),
        "dns-query".into(),
        vec!["208.67.220.220".parse().unwrap()],
        Duration::from_secs(5),
      )),
    );
    let opendns_family = (
      "opendns family",
      Some(DnsHttpsServer::new(
        "doh.opendns.com".into(),
        "dns-query".into(),
        vec!["208.67.222.123".parse().unwrap()],
        Duration::from_secs(5),
      )),
    );
    let opennic_usa = (
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
    let opennic_eu = (
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
      cloudflare,
      cloudflare_malware,
      cloudflare_adult,
      gesellschaft,
      // opendns,
      // opendns_family,
      opennic_eu,
      opennic_usa,
    ];
    for server in &mut servers {
      println!("using: {}", server.0);
      let resolver = Dns::with_servers(vec![server.1.take().unwrap()]).unwrap();
      let res = resolver.resolve_a("google.com").await.unwrap();
      assert_ne!(0, res.len())
    }
  }
}
