use std::fmt::Display;
use std::io;
use std::io::Write;

use chrono::Utc;
use env_logger;
use env_logger::fmt::Formatter;
use log;

pub fn logger(config: &str) {
  let mut builder = env_logger::Builder::new();

  let log_formatter = plain_formatter;

  builder.format(log_formatter);
  builder.parse_filters(config);
  builder.target(env_logger::Target::Stdout);
  builder.init();
}

fn plain_formatter(fmt: &mut Formatter, record: &log::Record) -> io::Result<()> {
  format(
    fmt,
    "ENGINE",
    match record.level() {
      log::Level::Debug => " ",
      log::Level::Error => "E",
      log::Level::Info => " ",
      log::Level::Trace => " ",
      log::Level::Warn => "W",
    },
    record.module_path().unwrap_or("None"),
    record.line().unwrap_or(0),
    record.args(),
  )
}

fn format<L, M, LN, A>(
  fmt: &mut Formatter,
  tag: &str,
  level: L,
  module: M,
  line: LN,
  args: A,
) -> io::Result<()>
where
  L: Display,
  M: Display,
  LN: Display,
  A: Display,
{
  let now = Utc::now().format("%H:%M:%S%.3f");
  writeln!(
    fmt,
    "{} {} {:<10} {}:{} {}",
    now, level, tag, module, line, args
  )
}

#[cfg(test)]
mod test {
  use super::*;
  use log::debug;

  #[test]
  fn logging() {
    logger("debug");
    debug!("logging format test");
  }
}
