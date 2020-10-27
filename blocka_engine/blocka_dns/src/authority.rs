use std::collections::HashMap;
use std::fs::File;
use std::io;
use std::io::{Seek, SeekFrom};
use std::net::{Ipv4Addr, Ipv6Addr};
use std::pin::Pin;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant, SystemTime};

use futures::{future, Future};

use trust_dns_client::op::ResponseCode;
use trust_dns_client::op::{LowerQuery, Query};
use trust_dns_client::rr::dnssec::SupportedAlgorithms;
use trust_dns_client::rr::{LowerName, Name, Record, RecordType};
use trust_dns_proto::rr::RData;
use trust_dns_resolver::error::{ResolveError, ResolveErrorKind};
use trust_dns_resolver::lookup::Lookup;
use trust_dns_server::authority::{
    Authority, LookupError, LookupObject, MessageRequest, UpdateResult, ZoneType,
};

use grep_matcher::Matcher;
use grep_regex::RegexMatcherBuilder;
use grep_searcher::sinks::UTF8;
use grep_searcher::Searcher;
use lru::LruCache;
use regex;

use crate::runtime::Resolver;

/// An authority that will forward resolutions to upstream resolvers.
///
/// This uses the trust-dns-resolver for resolving requests.
pub struct BlockaAuthority<T: Blocklist> {
    origin: LowerName,
    resolver: Arc<Resolver>,
    blocker: Arc<Mutex<T>>,
}

impl<T> BlockaAuthority<T>
where
    T: Blocklist,
{
    pub fn new(origin: Name, resolver: Arc<Resolver>, blocker: Arc<Mutex<T>>) -> Self {
        BlockaAuthority {
            origin: origin.into(),
            blocker,
            resolver,
        }
    }
}

impl<T> Authority for BlockaAuthority<T>
where
    T: Blocklist,
    T: Send + 'static, // because we also check lookup replies
{
    type Lookup = ForwardLookup;
    type LookupFuture = Pin<Box<dyn Future<Output = Result<Self::Lookup, LookupError>> + Send>>;

    /// Always Forward
    fn zone_type(&self) -> ZoneType {
        ZoneType::Forward
    }

    /// Always false for Forward zones
    fn is_axfr_allowed(&self) -> bool {
        false
    }

    fn update(&mut self, _update: &MessageRequest) -> UpdateResult<bool> {
        Err(ResponseCode::NotImp)
    }

    /// Get the origin of this zone, i.e. example.com is the origin for www.example.com
    ///
    /// In the context of a forwarder, this is either a zone which this forwarder is associated,
    ///   or `.`, the root zone for all zones. If this is not the root zone, then it will only forward
    ///   for lookups which match the given zone name.
    fn origin(&self) -> &LowerName {
        &self.origin
    }

    /// Forwards a lookup given the resolver configuration for this Forwarded zone
    fn lookup(
        &self,
        name: &LowerName,
        rtype: RecordType,
        _is_secure: bool,
        _supported_algorithms: SupportedAlgorithms,
    ) -> Pin<Box<dyn Future<Output = Result<Self::Lookup, LookupError>> + Send>> {
        // TODO: make this an error?
        assert!(self.origin.zone_of(name));

        debug!("forwarding lookup: {} {}", name, rtype);

        let name: LowerName = name.clone();
        let blocker = Arc::clone(&self.blocker);
        let resolver = Arc::clone(&self.resolver);
        Box::pin(ForwardLookup::new(name, rtype, resolver, blocker))
    }

    fn search(
        &self,
        query: &LowerQuery,
        is_secure: bool,
        supported_algorithms: SupportedAlgorithms,
    ) -> Pin<Box<dyn Future<Output = Result<Self::Lookup, LookupError>> + Send>> {
        debug!("searching query: {}", query.name());

        let mut blocker = self.blocker.lock().unwrap();
        match blocker.next_action(&[query.original().name()]) {
            BlocklistAction::Deny(name) => {
                info!("blocking egress {}", name);
                let query = query.original().clone();
                return Box::pin(async {
                    match blocked_lookup(query) {
                        Err(e) => return Err(e),
                        Ok(reply) => Ok(ForwardLookup(reply)),
                    }
                });
            }
            _ => (),
        }
        Box::pin(self.lookup(
            query.name(),
            query.query_type(),
            is_secure,
            supported_algorithms,
        ))
    }

    #[allow(clippy::unimplemented)]
    fn get_nsec_records(
        &self,
        _name: &LowerName,
        _is_secure: bool,
        _supported_algorithms: SupportedAlgorithms,
    ) -> Pin<Box<dyn Future<Output = Result<Self::Lookup, LookupError>> + Send>> {
        Box::pin(future::err(LookupError::from(io::Error::new(
            io::ErrorKind::Other,
            "Getting NSEC records is unimplemented for the forwarder",
        ))))
    }
}

pub struct ForwardLookup(pub Lookup);

impl ForwardLookup {
    pub async fn new<T: Blocklist>(
        name: LowerName,
        rtype: RecordType,
        resolver: Arc<Resolver>,
        blocker: Arc<Mutex<T>>,
    ) -> Result<ForwardLookup, LookupError> {
        match resolver.lookup(name, rtype).await {
            Ok(records) => {
                // Block CNAME cloaking
                let cnames = records
                    .iter()
                    .filter_map(|r| match r {
                        RData::CNAME(name) => Some(name),
                        _ => None,
                    })
                    .collect::<Vec<&Name>>();

                let mut blocker = blocker.lock().unwrap();
                match blocker.next_action(&cnames) {
                    BlocklistAction::Deny(name) => {
                        info!("blocking ingress {}", name);
                        let query = records.query().clone();
                        match blocked_lookup(query) {
                            Ok(reply) => Ok(ForwardLookup(reply)),
                            Err(e) => Err(e),
                        }
                    }
                    _ => Ok(ForwardLookup(records)),
                }
            }
            Err(e) => match e.kind() {
                &ResolveErrorKind::NoRecordsFound {
                    query: _,
                    valid_until: _,
                } => {
                    debug!("return NXDomain");
                    Err(LookupError::ResponseCode(ResponseCode::NXDomain))
                }
                &ResolveErrorKind::Proto(ref err) => {
                    debug!("lookup failed: {}", err);
                    Err(e.into())
                }
                &ResolveErrorKind::Timeout => {
                    info!("lookup failed: timed out");
                    Err(e.into())
                }
                _ => {
                    error!("lookup failed: {:?}", e);
                    Err(e.into())
                }
            },
        }
    }
}

fn blocked_lookup(query: Query) -> Result<Lookup, LookupError> {
    // Lower TTL to be able to react faster on pausing.
    let ttl: u32 = 10;
    let valid_until = Instant::now() + Duration::from_secs(ttl.into());

    let rdata = match query.query_type() {
        RecordType::A => RData::A(Ipv4Addr::UNSPECIFIED),
        RecordType::AAAA => RData::AAAA(Ipv6Addr::UNSPECIFIED),
        _ => return Err(LookupError::ResolveError(ResolveError::from("blocked"))),
    };
    let record = Record::from_rdata(query.name().clone(), ttl, rdata);

    Ok(Lookup::new_with_deadline(
        query,
        Arc::new(vec![record]),
        valid_until,
    ))
}

impl LookupObject for ForwardLookup {
    fn is_empty(&self) -> bool {
        self.0.is_empty()
    }

    fn iter<'a>(&'a self) -> Box<dyn Iterator<Item = &'a Record> + Send + 'a> {
        Box::new(self.0.record_iter())
    }

    fn take_additionals(&mut self) -> Option<Box<dyn LookupObject>> {
        None
    }
}

pub trait Blocklist: Send {
    fn next_action(&mut self, names: &[&Name]) -> BlocklistAction;
}

impl Blocklist for Box<dyn Blocklist> {
    fn next_action(&mut self, names: &[&Name]) -> BlocklistAction {
        (**self).next_action(names)
    }
}

#[derive(Debug, PartialEq, Clone)]
pub enum BlocklistAction {
    Allow,
    Deny(String),
    None,
}

// Dummy blocklist with static action
impl Blocklist for BlocklistAction {
    fn next_action(&mut self, _: &[&Name]) -> BlocklistAction {
        self.clone()
    }
}

impl Blocklist for [Box<dyn Blocklist>; 2] {
    fn next_action(&mut self, names: &[&Name]) -> BlocklistAction {
        let first_action = self[0].next_action(names);
        if first_action != BlocklistAction::None {
            return first_action;
        }

        self[1].next_action(names)
    }
}

pub enum ListType {
    Whitelist,
    Blacklist,
}

#[derive(Copy, Clone)]
pub struct Count {
    pub denied: u64,
    pub allowed: u64,
}

pub struct CachedList<T>
where
    T: Blocklist,
{
    counter: Count,
    cache: LruCache<String, (BlocklistAction, Timestamp, Requests)>,
    wrapped_list: T,
}

type Timestamp = u64;
type Requests = u64;

pub fn with_cache<T: Blocklist>(wrapped_list: T, cap: usize) -> CachedList<T> {
    CachedList {
        cache: LruCache::new(cap),
        counter: Count {
            allowed: 0,
            denied: 0,
        },
        wrapped_list,
    }
}

impl<T> CachedList<T>
where
    T: Blocklist,
{
    // snapshot will return a cloned key value map from current cache entries.
    pub fn snapshot(&self) -> HashMap<String, (BlocklistAction, Timestamp, Requests)> {
        self.cache
            .iter()
            .map(|(key, value)| (key.clone(), value.clone()))
            .collect()
    }

    pub fn total(&self) -> Count {
        self.counter
    }
}

impl<T> Blocklist for CachedList<T>
where
    T: Blocklist,
{
    fn next_action(&mut self, names: &[&Name]) -> BlocklistAction {
        if names.len() == 0 {
            debug!("0 names");
        }
        let unix_time: Timestamp = match SystemTime::now().duration_since(SystemTime::UNIX_EPOCH) {
            Ok(n) => n.as_secs(),
            Err(_) => 0,
        };
        for name in names {
            let s = name.to_ascii();
            let (action, requests) = match self.cache.get(&s) {
                Some((action, _, requests)) => (action.clone(), *requests),
                None => {
                    let action = self.wrapped_list.next_action(names);
                    (action, 0)
                }
            };
            // always update the timestamp and number of requests
            self.cache.put(s, (action.clone(), unix_time, requests + 1));

            if let BlocklistAction::Deny(_) = action {
                self.counter.denied += 1;
                return action;
            }
        }
        self.counter.allowed += 1;
        BlocklistAction::Allow
    }
}

pub struct FileList {
    blocklist: File,
    list_type: ListType,
    searcher: Searcher,
}

impl FileList {
    pub fn new(blocklist: &str, list_type: ListType) -> Result<FileList, io::Error> {
        let blocklist = File::open(blocklist)?;
        Ok(FileList {
            blocklist: blocklist,
            searcher: Searcher::new(),
            list_type,
        })
    }

    fn find(&mut self, matcher: impl Matcher) -> Option<String> {
        let mut found = None;
        if let Err(e) = self.blocklist.seek(SeekFrom::Start(0)) {
            error!("could not seek blocklist: {}", e);
            return None;
        }

        if let Err(e) = self.searcher.search_file(
            matcher,
            &self.blocklist,
            UTF8(|_, name| {
                let mut name = String::from(name);
                // Remove newline.
                name.truncate(name.len() - 1);
                found = Some(name);
                Ok(false)
            }),
        ) {
            error!("could not search file: {}", e);
        }

        return found;
    }
}

pub struct AcceptAllDummy {}

impl Blocklist for AcceptAllDummy {
    fn next_action(&mut self, _: &[&Name]) -> BlocklistAction {
        BlocklistAction::Allow
    }
}

impl Blocklist for FileList {
    fn next_action(&mut self, names: &[&Name]) -> BlocklistAction {
        debug!("FileList search name");
        let s = names
            .iter()
            .map(|name| name.to_ascii())
            .map(|mut name| {
                // Remove trailing dot
                name.truncate(name.len() - 1);
                name
            })
            .map(|name| regex::escape(&name))
            .collect::<Vec<String>>()
            .join("|");

        let s = format!(r"^({})$", &s);
        let matcher = match RegexMatcherBuilder::new()
            .case_insensitive(true)
            .line_terminator(Some(b'\n'))
            .build(&s)
        {
            Ok(m) => m,
            Err(e) => {
                error!("could not create matcher: {}", e);
                return BlocklistAction::None;
            }
        };

        let found = self.find(&matcher);
        debug!("FileList search done");

        match found {
            Some(name) => match self.list_type {
                ListType::Blacklist => BlocklistAction::Deny(name),
                ListType::Whitelist => BlocklistAction::Allow,
            },
            None => BlocklistAction::None,
        }
    }
}

#[cfg(test)]
mod test {
    use super::*;
    // use test::Bencher;

    #[test]
    fn load_blocklist() {
        let mut list = FileList::new("src/test-data/hosts.txt", ListType::Blacklist).unwrap();
        // Actually 317663 lines but this is a unique
        let blocked_name = "xmr-ru1.nanopool.org.".parse().unwrap();
        assert_eq!(
            list.next_action(&[&blocked_name]),
            BlocklistAction::Deny(String::from("xmr-ru1.nanopool.org")),
            "nanopool should be denied",
        );
        assert_eq!(
            list.next_action(&[&"www.google.com.".parse::<Name>().unwrap()]),
            BlocklistAction::None,
            "google should be allowed",
        );
        // Make sure we're reading the file again
        assert_eq!(
            list.next_action(&[&blocked_name]),
            BlocklistAction::Deny(String::from("xmr-ru1.nanopool.org")),
            "nanopool should be denied a second time",
        );
    }

    // #[bench]
    // fn bench_blocklist_contains(b: &mut Bencher) {
    //     let list = super::load_blocklist("src/test-data/hosts.txt").unwrap();
    //     let lookup = "xmr-ru1.nanopool.org".parse::<LowerName>().unwrap();
    //     b.iter(|| list.next_action(&lookup));
    // }
}
