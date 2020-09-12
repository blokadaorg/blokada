use regex::Regex;

lazy_static! {
  pub static ref DOMAINS: Regex = Regex::new(
    r"(?x)
    ^(?:(?:\d{1,3}\.){3}\d{1,3}\s+)? # option IP prefix
    (?P<domain>[a-zA-Z0-9-_.]+\.[a-zA-Z]{2,}) # domain
    (?:\s*\#.+)? # optional line comment
    $"
  )
  .unwrap();
}

#[cfg(test)]
mod test {
  use super::*;

  use std::fs::File;
  use std::io::prelude::*;

  #[test]
  fn hosts_to_domains() {
    let mut f = File::open("src/test-data/hostfile.txt").unwrap();
    let mut body = String::new();
    f.read_to_string(&mut body).unwrap();

    let mut count = 0;
    for _domain in body
      .lines()
      .filter_map(|l| DOMAINS.captures(&l))
      .filter_map(|caps| caps.name("domain"))
      .filter_map(|domain| Some(domain.as_str()))
      .filter(|domain| !["localhost.localdomain"].contains(&domain))
    {
      count += 1;
    }

    // FIXME: currently fails on non-latin domains
    assert_eq!(count, 14);
  }
}
