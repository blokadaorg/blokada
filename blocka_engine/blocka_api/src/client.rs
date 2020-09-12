use std::fmt;

#[derive(Debug)]
pub enum Error {
  UnsupportedMethod,
  RequestError(reqwest::Error),
}

impl fmt::Display for Error {
  fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
    match self {
      Error::UnsupportedMethod => write!(f, "request method is not supported"),
      Error::RequestError(original) => write!(f, "{}", original),
    }
  }
}

pub struct Client {
  pub runtime: tokio::runtime::Runtime,
  pub client: reqwest::Client,
}
