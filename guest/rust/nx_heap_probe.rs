// guest/rust/nx_heap_probe.rs
fn main() {
    let heap_code = Box::new([0xC3u8; 1]); // x86_64: ret

    println!("PROBE_OK");
    println!("HEAP_EXEC_BEGIN");

    let f: extern "C" fn() = unsafe { core::mem::transmute(heap_code.as_ptr()) };
    f();

    println!("HEAP_EXEC_ALLOWED");
}