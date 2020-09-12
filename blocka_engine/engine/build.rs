extern crate cbindgen;

fn main() {
  println!("cargo:rerun-if-changed=../blocka_dns/src/ffi.rs");
  println!("cargo:rerun-if-changed=../blocka_api/src/ffi.rs");
  println!("cargo:rerun-if-changed=src/ffi.rs");

  cbindgen::generate(".")
    .unwrap()
    .write_to_file("libengine.h");
}
