use std::{
  ffi::CString,
  future::Future,
  io,
  net::{IpAddr, SocketAddr},
  pin::Pin,
  task::{self, Poll},
  time::Duration,
};

use hyper::client::{connect::dns::Name, Client};
use hyper::service::Service;
use hyper::Uri;
use hyper_tls::HttpsConnector;
use socket2::*;
use tokio::net::TcpStream;
use tokio::time::timeout;
use tokio_io_timeout::TimeoutStream;

use doh_dns::client::{HyperDnsClient, StaticResolver};
use doh_dns::{Dns, DnsHttpsServer};

use crate::network;

pub(crate) fn new_default(servers: Vec<DnsHttpsServer>) -> Dns {
  Dns::new(
    HyperDnsClient::builder()
      .pool_max_idle_per_host(1)
      .with_servers(servers)
      .build(),
  )
}

pub(crate) fn new_tunneled(servers: Vec<DnsHttpsServer>) -> TunneledHyperClient {
  let connector = TunnelTransport::new(StaticResolver::new(&servers));
  let mut connector =
    HttpsConnector::from((connector, native_tls::TlsConnector::new().unwrap().into()));
  connector.https_only(true);

  let client = Client::builder().pool_max_idle_per_host(0).build(connector);
  HyperDnsClient::new(client, servers)
}

pub(crate) type TunneledHyperClient = HyperDnsClient<HttpsConnector<TunnelTransport>>;

#[derive(Clone)]
pub(crate) struct TunnelTransport {
  resolver: StaticResolver,
}

impl Service<Uri> for TunnelTransport {
  type Response = TcpStream;
  type Error = std::io::Error;
  // We can't "name" an `async` generated future.
  type Future = Pin<Box<dyn Future<Output = Result<Self::Response, Self::Error>> + Send>>;

  fn poll_ready(&mut self, _: &mut task::Context<'_>) -> Poll<Result<(), Self::Error>> {
    // This connector is always ready, but others might not be.
    Poll::Ready(Ok(()))
  }

  fn call(&mut self, dst: Uri) -> Self::Future {
    let mut self_ = self.clone();
    Box::pin(async move { self_.call_async(dst).await })
  }
}

impl TunnelTransport {
  fn new(resolver: StaticResolver) -> TunnelTransport {
    TunnelTransport { resolver }
  }

  async fn call_async(&mut self, dst: Uri) -> Result<TcpStream, io::Error> {
    if dst.scheme().is_none() {
      return Err(io::Error::new(io::ErrorKind::InvalidData, "no scheme"));
    }

    let host = match dst.host() {
      Some(s) => s,
      None => return Err(io::Error::new(io::ErrorKind::InvalidData, "missing host")),
    };
    let port = match dst.port() {
      Some(port) => port.as_u16(),
      None => 443,
    };

    let addrs = resolve(
      &mut self.resolver,
      match host.parse() {
        Ok(h) => h,
        Err(e) => return Err(io::Error::new(io::ErrorKind::InvalidInput, e)),
      },
    )
    .await?;
    let addrs: Vec<SocketAddr> = addrs.map(|addr| SocketAddr::new(addr, port)).collect();

    debug!("connect to {}", &addrs[0]);
    let socket = tunnel_socket(&addrs[0])?;
    let stream = timeout(
      Duration::from_secs(10),
      TcpStream::connect_std(socket.into(), &addrs[0]),
    )
    .await?;
    let mut stream = TimeoutStream::new(stream?);
    // Work around for avoiding stalled connections when switching source IPs.
    stream.set_read_timeout(Some(Duration::from_secs(10)));
    stream.set_write_timeout(Some(Duration::from_secs(10)));
    Ok(stream.into_inner())
  }
}

fn tunnel_socket(addr: &SocketAddr) -> Result<Socket, io::Error> {
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
    Some((_, Some(_))) => (),
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

  // socket.connect(&addr.into())?;
  // TcpStream::from_std(socket.into_tcp_stream())
  Ok(socket)
}

async fn resolve<R>(resolver: &mut R, name: Name) -> Result<R::Response, R::Error>
where
  R: Service<Name>,
{
  futures_util::future::poll_fn(|cx| resolver.poll_ready(cx)).await?;
  resolver.call(name).await
}
