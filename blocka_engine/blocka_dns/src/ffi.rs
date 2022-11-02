use std::ffi::{CStr, CString};
use std::io;
use std::net::{IpAddr, SocketAddr};
use std::os::raw::c_char;
use std::panic;
use std::ptr;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use tokio::net::UdpSocket;
use tokio::runtime::Builder;
use tokio::task;

#[cfg(feature = "resolver")]
use trust_dns_client::rr::Name;
use trust_dns_server::authority::Catalog;
#[cfg(feature = "dns-over-tls")]
use trust_dns_server::server::ServerFuture;

use crate::authority::{
    with_cache, BlockaAuthority, Blocklist, BlocklistAction, CachedList, FileList, ListType,
};
use crate::runtime::Resolver;
use doh_dns::DnsHttpsServer;

pub struct Handle {
    runtime: tokio::runtime::Runtime,
    _threads: Vec<tokio::task::JoinHandle<()>>,
    cached_list: Arc<Mutex<CachedList<Box<dyn Blocklist>>>>,
    resolver: Arc<Resolver>,
}

fn blocklist_from_files(
    blocklist_filename: Option<&str>,
    whitelist_filename: Option<&str>,
) -> Result<Box<dyn Blocklist>, io::Error> {
    let mut blocklist: Box<dyn Blocklist> = match blocklist_filename {
        Some(filename) => {
            info!("loading blocklist from {}", filename);
            Box::new(FileList::new(filename, ListType::Blacklist)?)
        }
        None => {
            warn!("no blocklist specified, allow all");
            Box::new(BlocklistAction::None)
        }
    };
    // Run through whitelist before blacklist if exists.
    if let Some(filename) = whitelist_filename {
        info!("loading whitelist from {}", filename);
        let whitelist = Box::new(FileList::new(filename, ListType::Whitelist)?);
        blocklist = Box::new([whitelist, blocklist]);
    }

    Ok(Box::new(blocklist))
}

#[repr(C)]
pub enum DNSMode {
    CLEAR,
    TLS,
    HTTPS,
}

#[repr(C)]
pub struct DNSHistory {
    pub ptr: *mut DNSHistoryEntry,
    pub len: usize,
    pub allowed_requests: u64,
    pub denied_requests: u64,
}

#[repr(C)]
pub struct DNSHistoryEntry {
    pub name: *mut c_char,
    pub action: DNSHistoryAction,
    pub unix_time: u64,
    pub requests: u64,
}

#[repr(C)]
pub enum DNSHistoryAction {
    Whitelisted,
    Blocked,
    Passed,
}

impl From<&BlocklistAction> for DNSHistoryAction {
    fn from(action: &BlocklistAction) -> Self {
        match action {
            BlocklistAction::Allow => DNSHistoryAction::Whitelisted,
            BlocklistAction::None => DNSHistoryAction::Passed,
            BlocklistAction::Deny(_) => DNSHistoryAction::Blocked,
        }
    }
}

#[no_mangle]
pub extern "C" fn new_dns(
    listen_addr: *const c_char,
    blocklist_filename: *const c_char,
    whitelist_filename: *const c_char,
    dns_ips: *const c_char,
    dns_name: *const c_char,
    dns_path: *const c_char,
) -> *mut Handle {
    let c_str = unsafe { CStr::from_ptr(listen_addr) };
    let listen_addr = match c_str.to_str() {
        Err(_) => return ptr::null_mut(),
        Ok(string) => string,
    };
    let listen_addr = match listen_addr.parse::<SocketAddr>() {
        Err(_) => return ptr::null_mut(),
        Ok(addr) => addr,
    };
    let blocklist_filename = if blocklist_filename.is_null() {
        None
    } else {
        let c_str = unsafe { CStr::from_ptr(blocklist_filename) };
        match c_str.to_str() {
            Err(_) => return ptr::null_mut(),
            Ok(string) => Some(string),
        }
    };
    let whitelist_filename = if whitelist_filename.is_null() {
        None
    } else {
        let c_str = unsafe { CStr::from_ptr(whitelist_filename) };
        match c_str.to_str() {
            Err(_) => return ptr::null_mut(),
            Ok(string) => Some(string),
        }
    };

    let blocklist = match blocklist_from_files(blocklist_filename, whitelist_filename) {
        Ok(list) => list,
        Err(e) => {
            error!("could not create blocklist: {}", e);
            return ptr::null_mut();
        }
    };

    // Using one thread to avoid memory leaks in TCP based queries,
    // See https://github.com/bluejekyll/trust-dns/issues/777
    let mut runtime = match Builder::new()
        .threaded_scheduler()
        .thread_name("blocka_dns")
        .core_threads(1)
        .max_threads(25)
        .enable_all()
        .build()
    {
        Ok(b) => b,
        Err(e) => {
            error!("tokio runtime error: {:?}", e);
            return ptr::null_mut();
        }
    };

    let c_str = unsafe { CStr::from_ptr(dns_name) };
    let dns_name = match c_str.to_str() {
        Err(_) => return ptr::null_mut(),
        Ok(string) => string,
    };
    let c_str = unsafe { CStr::from_ptr(dns_path) };
    let dns_path = match c_str.to_str() {
        Err(_) => return ptr::null_mut(),
        Ok(string) => string,
    };
    let c_str = unsafe { CStr::from_ptr(dns_ips) };
    let dns_ips = match c_str.to_str() {
        Err(_) => return ptr::null_mut(),
        Ok(string) => string,
    };

    info!("new dns using {}", dns_name);

    let dns_ips: Vec<IpAddr> = dns_ips
        .split(",")
        .filter_map(|ip| ip.trim().parse().ok())
        .collect();
    let dns_mode = DNSMode::HTTPS;
    let servers = match dns_mode {
        DNSMode::HTTPS => vec![DnsHttpsServer::new(
            dns_name.into(),
            dns_path.into(),
            dns_ips,
            Duration::from_secs(10),
        )],
        DNSMode::CLEAR => {
            error!("clear DNS is not supported");
            return ptr::null_mut();
        }
        DNSMode::TLS => {
            error!("DoT is not supported");
            return ptr::null_mut();
        }
    };

    let resolver = match Resolver::new(servers, runtime.handle()) {
        Ok(r) => r,
        Err(e) => {
            error!("failed creating resolver: {:?}", e);
            return ptr::null_mut();
        }
    };
    let resolver = Arc::new(resolver);
    let cached_list = Arc::new(Mutex::new(with_cache(blocklist, 250)));
    let blocka_forwarder =
        BlockaAuthority::new(Name::root(), Arc::clone(&resolver), cached_list.clone());
    let mut catalog: Catalog = Catalog::new();
    catalog.upsert(Name::root().into(), Box::new(blocka_forwarder));

    let udp_socket = runtime
        .block_on(UdpSocket::bind(listen_addr))
        .unwrap_or_else(|_| panic!("could not bind to udp: {}", listen_addr));

    let mut server = ServerFuture::new(catalog);

    let join_handle: task::JoinHandle<_> = runtime.spawn(async move {
        // Process each socket concurrently.
        server.register_socket(udp_socket);
        match server.block_until_done().await {
            Err(e) => {
                error!("server error: {:?}", e);
            }
            Ok(_) => info!("server has stopped"),
        }
    });
    let h = Handle {
        _threads: vec![join_handle],
        runtime,
        resolver,
        cached_list,
    };

    Box::into_raw(Box::new(h))
}

#[no_mangle]
pub extern "C" fn dns_use_lists(
    h: *mut Handle,
    blocklist_filename: *const c_char,
    whitelist_filename: *const c_char,
) -> bool {
    let blocklist_filename = if blocklist_filename.is_null() {
        None
    } else {
        let c_str = unsafe { CStr::from_ptr(blocklist_filename) };
        match c_str.to_str() {
            Err(_) => return false,
            Ok(string) => Some(string),
        }
    };
    let whitelist_filename = if whitelist_filename.is_null() {
        None
    } else {
        let c_str = unsafe { CStr::from_ptr(whitelist_filename) };
        match c_str.to_str() {
            Err(_) => return false,
            Ok(string) => Some(string),
        }
    };

    let blocklist = match blocklist_from_files(blocklist_filename, whitelist_filename) {
        Ok(list) => list,
        Err(e) => {
            error!("could not create blocklist: {}", e);
            return false;
        }
    };

    // We create a new cache since the new blocklist might not block
    // the same records as the previous list, we don't track which lists we're
    // currently using.
    let h = unsafe { &*h };
    *h.cached_list.lock().unwrap() = with_cache(blocklist, 250);

    true
}

#[no_mangle]
pub unsafe extern "C" fn dns_close(h: *mut Handle) {
    info!("dns_close");
    Box::from_raw(h);
}

#[repr(C)]
pub enum TunnelMode {
    Disabled,
    TunneledInterface,
    DefaultInterface,
}

impl From<TunnelMode> for Option<bool> {
    fn from(mode: TunnelMode) -> Self {
        match mode {
            TunnelMode::TunneledInterface => Some(true),
            TunnelMode::DefaultInterface => Some(false),
            TunnelMode::Disabled => None,
        }
    }
}

#[no_mangle]
pub extern "C" fn dns_history(h: *const Handle) -> DNSHistory {
    let h = unsafe { &*h };
    let history = h.cached_list.lock().unwrap();
    let total = history.total();
    let entries: Box<[DNSHistoryEntry]> = history
        .snapshot()
        .iter()
        .map(|(key, (action, unix_time, requests))| DNSHistoryEntry {
            name: CString::new(&**key)
                .expect("unable to create DNSHistoryEntry")
                .into_raw(),
            action: action.into(),
            unix_time: *unix_time,
            requests: *requests,
        })
        .collect::<Vec<DNSHistoryEntry>>()
        .into_boxed_slice();

    let len = entries.len();
    DNSHistory {
        ptr: Box::into_raw(entries) as *mut DNSHistoryEntry,
        len,
        allowed_requests: total.allowed,
        denied_requests: total.denied,
    }
}

#[no_mangle]
pub extern "C" fn dns_history_free(history: DNSHistory) {
    let entries = unsafe { std::slice::from_raw_parts(history.ptr, history.len) };
    for entry in entries {
        unsafe { CString::from_raw(entry.name) };
    }
}
