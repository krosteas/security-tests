// guest/rust/nx_heap_unsafe_probe.rs
use core::mem;

type ProbeFn = extern "C" fn();

fn main() {
    println!("PROBE_OK");

    let heap_code = Box::new([0xC3u8; 1]); // x86_64 ret instruction

    println!("HEAP_EXEC_BEGIN");

    unsafe {
        let f: ProbeFn = mem::transmute(heap_code.as_ptr());
        f();
    }

    println!("HEAP_EXEC_ALLOWED");
}