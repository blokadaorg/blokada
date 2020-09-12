// pub mod device;
pub mod ffi;
// Required to be listed for finding their FFI
extern crate blocka_api;
extern crate blocka_dns;
extern crate boringtun;
extern crate log;

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}
