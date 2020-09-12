#![cfg(target_os = "android")]
#![allow(non_snake_case)]

use std::ptr;
use std::ffi::CString;

use jni::objects::{JClass, JString};
use jni::sys::jlong;
use jni::JNIEnv;

use crate::ffi;

extern crate android_logger;
use log::Level;
use android_logger::Config;

static mut DNS_HANDLE: Option<*mut ffi::Handle> = None;

#[no_mangle]
#[export_name = "Java_com_blocka_dns_BlockaDnsJNI_00024Companion_create_1new_1dns"]
pub unsafe extern "C" fn create_new_dns(
  env: JNIEnv,
  _class: JClass,
  listen_addr: JString,
  dns_ips: JString,
  dns_name: JString,
  dns_path: JString,
) -> jlong {
  let addr: String = env.get_string(listen_addr).expect("JNI param fail").into();
  let ips: String = env.get_string(dns_ips).expect("JNI param fail").into();
  let name: String = env.get_string(dns_name).expect("JNI param fail").into();
  let path: String = env.get_string(dns_path).expect("JNI param fail").into();

  DNS_HANDLE = Some(ffi::new_dns(CString::new(addr).expect("no cstring").as_ptr(),
    ptr::null(), ptr::null(),
    CString::new(ips).expect("no cstring").as_ptr(),
    CString::new(name).expect("no cstring").as_ptr(),
    CString::new(path).expect("no cstring").as_ptr()
  ));
  0
}

#[no_mangle]
#[export_name = "Java_com_blocka_dns_BlockaDnsJNI_00024Companion_dns_1close"]
pub unsafe extern "C" fn close_dns(
  env: JNIEnv,
  _class: JClass,
  handle: jlong,
) {
  match DNS_HANDLE {
    Some(h) => {
      ffi::dns_close(h);
      DNS_HANDLE = None;
    }
    None => {
      log::error!("Requested to close dns when no handle")
    }
  };
}

#[no_mangle]
#[export_name = "Java_com_blocka_dns_BlockaDnsJNI_00024Companion_engine_1logger"]
pub unsafe extern "C" fn engine_logger(
  env: JNIEnv,
  _class: JClass,
  level: JString,
) {
  let lvl: String = env.get_string(level).expect("JNI param fail").into();

  log::debug!("Initiated logging in blocka_dns, level: {}", lvl);

  // util::ffi::panic_hook(Some(|line| {
      // log::error!("{}", line)
  // }));

  if lvl == "info" {
    android_logger::init_once(Config::default().with_min_level(Level::Info));
  } else if lvl == "debug" {
    android_logger::init_once(Config::default().with_min_level(Level::Debug));
  } else if lvl == "warning" {
    android_logger::init_once(Config::default().with_min_level(Level::Warn));
  } else {
    android_logger::init_once(Config::default().with_min_level(Level::Error));
  }
}