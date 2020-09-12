use std::convert::From;
use std::ffi::{CStr, CString};
use std::fs::File;
use std::io::{BufWriter, Write};
use std::os::raw::{c_char, c_ulonglong};
use std::ptr;
use std::time::Duration;

use reqwest;
use tokio::runtime::Builder;

use crate::client::*;
use crate::parser::DOMAINS;

#[no_mangle]
pub unsafe extern "C" fn api_new(
    timeout_seconds: c_ulonglong,
    user_agent: *const c_char,
) -> *mut Client {
    info!("new api client");

    let c_str = CStr::from_ptr(user_agent);
    let user_agent = match c_str.to_str() {
        Ok(string) if string.len() > 0 => string.to_owned(),
        _ => return ptr::null_mut(),
    };

    let client = match reqwest::Client::builder()
        .user_agent(user_agent)
        .timeout(Duration::new(timeout_seconds, 0))
        .use_rustls_tls()
        .http2_prior_knowledge()
        // Keep alive is disabled due to crashing when resuming process on iOS
        .pool_max_idle_per_host(0)
        .build()
    {
        Ok(c) => c,
        Err(e) => {
            error!("error configuring the client: {:?}", e);
            return ptr::null_mut();
        }
    };

    let runtime = match Builder::new()
        .threaded_scheduler()
        .core_threads(1)
        .thread_name("blocka_api")
        .enable_all()
        .build()
    {
        Ok(b) => b,
        Err(e) => {
            error!("tokio runtime error: {:?}", e);
            return ptr::null_mut();
        }
    };

    Box::into_raw(Box::new(Client {
        runtime: runtime,
        client: client,
    }))
}

#[no_mangle]
pub unsafe extern "C" fn api_free(c: *mut Client) {
    Box::from_raw(c);
}

#[repr(C)]
pub struct Response {
    pub body: *mut c_char,
    pub error: *mut c_char,
    pub code: u16,
}

impl From<Error> for Response {
    fn from(error: Error) -> Self {
        Response {
            body: ptr::null_mut(),
            error: CString::into_raw(CString::new(format!("{}", error)).unwrap()),
            code: 0,
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn api_request(
    client: *mut Client,
    method: *const c_char,
    url: *const c_char,
    body: *const c_char,
) -> *mut Response {
    let c_str = CStr::from_ptr(method);
    let method = match c_str.to_str() {
        Err(_) => return ptr::null_mut(),
        Ok(string) => string,
    };
    let c_str = CStr::from_ptr(url);
    let url = match c_str.to_str() {
        Err(_) => return ptr::null_mut(),
        Ok(string) => string,
    };
    let c_str = CStr::from_ptr(body);
    let body = match c_str.to_str() {
        Err(_) => return ptr::null_mut(),
        Ok(string) => string,
    };

    info!("new request: {} {}", method, url);
    let c = &mut *client;
    let reqwest_client = &c.client;

    let req = async {
        match method {
            "POST" => match reqwest_client.post(url).body(body).send().await {
                Ok(r) => Ok(r),
                Err(e) => Err(Error::RequestError(e)),
            },
            "GET" => match reqwest_client.get(url).send().await {
                Ok(r) => Ok(r),
                Err(e) => Err(Error::RequestError(e)),
            },
            "PUT" => match reqwest_client.put(url).body(body).send().await {
                Ok(r) => Ok(r),
                Err(e) => Err(Error::RequestError(e)),
            },
            "DELETE" => match reqwest_client.delete(url).body(body).send().await {
                Ok(r) => Ok(r),
                Err(e) => Err(Error::RequestError(e)),
            },
            _ => Err(Error::UnsupportedMethod),
        }
    };
    let res = match c.runtime.block_on(req) {
        Ok(res) => res,
        Err(e) => {
            return Box::into_raw(Box::new(Response::from(e)));
        }
    };

    let html = match c.runtime.block_on(async {
        let code = res.status();
        match res.text().await {
            Ok(html) => Ok((code, html)),
            Err(e) => Err(Error::RequestError(e)),
        }
    }) {
        Ok(html) => html,
        Err(e) => {
            return Box::into_raw(Box::new(Response::from(e)));
        }
    };
    debug!("{}: {}", html.0, html.1);
    let body = CString::new(html.1).unwrap();

    Box::into_raw(Box::new(Response {
        code: html.0.as_u16(),
        body: CString::into_raw(body),
        error: ptr::null_mut(),
    }))
}

#[no_mangle]
pub unsafe extern "C" fn api_response_free(response: *mut Response) {
    let r = Box::from_raw(response);
    // on errors the body will not be set
    if !r.body.is_null() {
        CString::from_raw(r.body);
    }
    // on normal replies the error won't be set
    if !r.error.is_null() {
        CString::from_raw(r.error);
    }
}

#[no_mangle]
pub unsafe extern "C" fn api_hostlist(
    client: *mut Client,
    url: *const c_char,
    path: *const c_char,
) -> usize {
    let c_str = CStr::from_ptr(url);
    let url = match c_str.to_str() {
        Err(_) => return 0,
        Ok(string) => string,
    };
    let c_str = CStr::from_ptr(path);
    let path = match c_str.to_str() {
        Err(_) => return 0,
        Ok(string) => string,
    };
    let mut output = match File::create(path) {
        Err(e) => {
            error!("could not create file: {}", e);
            return 0;
        }
        Ok(f) => BufWriter::new(f),
    };

    info!("api hostlists: {} -> {}", url, path);
    let c = &mut *client;

    let reqwest_client = &c.client;
    let req = c
        .runtime
        .block_on(async { reqwest_client.get(url).send().await?.text().await });

    let body = match req {
        Err(e) => {
            error!("could not download hostlist: {}", e);
            return 0;
        }
        Ok(body) => body,
    };

    let mut count: usize = 0;
    for domain in body
        .lines()
        .filter_map(|l| DOMAINS.captures(&l))
        .filter_map(|caps| caps.name("domain"))
        .filter_map(|domain| Some(domain.as_str()))
        .filter(|domain| !["localhost.localdomain"].contains(&domain))
    {
        if let Err(e) = output.write_fmt(format_args!("{}\n", domain)) {
            error!("could not write to file: {}", e);
            return 0;
        }
        count += 1;
    }

    count
}
