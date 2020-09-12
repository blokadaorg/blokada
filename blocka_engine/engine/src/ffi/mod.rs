use std::ffi::{CStr, CString};
use std::os::raw::c_char;

use base64::encode;
use boringtun::crypto::x25519::X25519SecretKey;

use util;

#[no_mangle]
pub unsafe extern "C" fn panic_hook(log_printer: Option<unsafe extern "C" fn(*const c_char)>) {
  util::ffi::panic_hook(log_printer);
}

#[no_mangle]
pub extern "C" fn engine_logger(level: *const c_char) {
  let level = if level.is_null() {
    "error"
  } else {
    let c_str = unsafe { CStr::from_ptr(level) };
    match c_str.to_str() {
      Err(_) => "error",
      Ok(string) => string,
    }
  };

  util::logger(&format!(
    "trust_dns_https={trust_level},trust_dns_resolver={trust_level},engine={blocka_level},blocka_api={blocka_level},blocka_dns={blocka_level}",
    blocka_level = level,
    trust_level = "info",
  ));
}

#[repr(C)]
pub struct x25519_base64_keypair {
  pub public_key: *const c_char,
  pub private_key: *const c_char,
}

/// Generates a new x25519 secret key.
#[no_mangle]
pub extern "C" fn keypair_new() -> *mut x25519_base64_keypair {
  let key = X25519SecretKey::new();
  Box::into_raw(Box::new(x25519_base64_keypair {
    public_key: CString::into_raw(CString::new(encode(key.public_key().as_bytes())).unwrap()),
    private_key: CString::into_raw(CString::new(encode(key.as_bytes())).unwrap()),
  }))
}

/// Frees memory of the string given by `x25519_base64_keypair`
#[no_mangle]
pub unsafe extern "C" fn keypair_free(keypair: *mut x25519_base64_keypair) {
  Box::from_raw(keypair);
}
