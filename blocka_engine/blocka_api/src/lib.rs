pub mod client;
pub mod ffi;
pub use client::Client;
pub(crate) mod parser;

#[macro_use]
extern crate log;

#[macro_use]
extern crate lazy_static;

#[cfg(test)]
mod test {
  use std::time::Duration;

  #[cfg(feature = "integration-test")]
  #[tokio::test]
  async fn request() {
    let client = reqwest::Client::builder()
      .user_agent("blokada/dev (iOS)")
      .timeout(Duration::new(10, 0))
      .use_rustls_tls()
      .http2_prior_knowledge()
      .build()
      .unwrap();
    client
      .get("https://api.blocka.net/v1/gateway")
      .send()
      .await
      .unwrap()
      .text()
      .await
      .unwrap();
    client
      .get("https://api.blocka.net/v2/gateway")
      .send()
      .await
      .unwrap();
  }
}
