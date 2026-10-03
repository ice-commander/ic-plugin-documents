//! The folder this plugin was loaded from, where the libraries it carries sit in a folder of their own.

use std::path::PathBuf;

/// A subfolder because the host tries every library in the plugin folder as a plugin.
pub const CARRIED: &str = "pdfium";

#[cfg(not(target_os = "windows"))]
pub fn own_folder() -> Option<PathBuf> {
    use std::ffi::CStr;
    use std::os::raw::{c_char, c_int, c_void};

    #[repr(C)]
    struct DlInfo {
        file_name: *const c_char,
        file_base: *mut c_void,
        symbol_name: *const c_char,
        symbol_address: *mut c_void,
    }
    extern "C" {
        fn dladdr(address: *const c_void, info: *mut DlInfo) -> c_int;
    }

    let mut told = DlInfo {
        file_name: std::ptr::null(),
        file_base: std::ptr::null_mut(),
        symbol_name: std::ptr::null(),
        symbol_address: std::ptr::null_mut(),
    };
    let here = own_folder as *const () as *const c_void;
    if unsafe { dladdr(here, &mut told) } == 0 || told.file_name.is_null() {
        return None;
    }
    let named = unsafe { CStr::from_ptr(told.file_name) }
        .to_string_lossy()
        .into_owned();
    PathBuf::from(named).parent().map(PathBuf::from)
}

#[cfg(target_os = "windows")]
pub fn own_folder() -> Option<PathBuf> {
    use std::os::raw::{c_char, c_int, c_void};

    const FROM_ADDRESS: u32 = 0x4;
    const UNCHANGED_REFCOUNT: u32 = 0x2;
    extern "system" {
        fn GetModuleHandleExA(flags: u32, name: *const c_char, held: *mut *mut c_void) -> c_int;
        fn GetModuleFileNameA(library: *mut c_void, into: *mut u8, room: u32) -> u32;
    }

    let mut held: *mut c_void = std::ptr::null_mut();
    let here = own_folder as *const () as *const c_char;
    if unsafe { GetModuleHandleExA(FROM_ADDRESS | UNCHANGED_REFCOUNT, here, &mut held) } == 0 {
        return None;
    }
    let mut room = [0u8; 4096];
    let written = unsafe { GetModuleFileNameA(held, room.as_mut_ptr(), room.len() as u32) };
    if written == 0 || written as usize >= room.len() {
        return None;
    }
    let named = String::from_utf8_lossy(&room[..written as usize]).into_owned();
    PathBuf::from(named).parent().map(PathBuf::from)
}
