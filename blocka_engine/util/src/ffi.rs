use libc::{raise, SIGSEGV};
use std::ffi::CString;
use std::ops::Deref;
use std::os::raw::c_char;
use std::panic;
use std::sync::Once;

static PANIC_HOOK: Once = Once::new();

pub fn panic_hook(log_printer: Option<unsafe extern "C" fn(*const c_char)>) {
  // FFI won't properly unwind on panic, but it will if we cause a segmentation fault
  PANIC_HOOK.call_once(|| {
    panic::set_hook(Box::new(move |panic_info| {
      if let Some(callback) = log_printer {
        let (filename, line) = panic_info
          .location()
          .map(|loc| (loc.file(), loc.line()))
          .unwrap_or(("<unknown>", 0));

        let cause = panic_info
          .payload()
          .downcast_ref::<String>()
          .map(String::deref);

        let cause = cause.unwrap_or_else(|| {
          panic_info
            .payload()
            .downcast_ref::<&str>()
            .map(|s| *s)
            .unwrap_or("<cause unknown>")
        });
        let s = format!("PANIC {}:{}: '{}'", filename, line, cause);
        let s = CString::new(s).unwrap();
        unsafe { callback(s.as_ptr()) };
      }
      unsafe { raise(SIGSEGV) };
    }))
  });
}

pub fn logger(log_printer: Option<unsafe extern "C" fn(*const c_char)>) -> Box<dyn Fn(&str)> {
  match log_printer {
    Some(callback) => Box::new(move |msg| {
      let s = CString::new(msg).unwrap();
      unsafe { callback(s.as_ptr()) };
    }),
    None => Box::new(|_| {}),
  }
}
