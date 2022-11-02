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

async fn resolve<R>(resolver: &mut R, name: Name) -> Result<R::Response, R::Error>
where
  R: Service<Name>,
{
  futures_util::future::poll_fn(|cx| resolver.poll_ready(cx)).await?;
  resolver.call(name).await
}
