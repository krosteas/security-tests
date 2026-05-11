// guest/rust/nx_stack_probe.rs
fn main() {
    let stack_code: [u8; 1] = [0xC3]; // x86_64: ret

    println!("PROBE_OK");
    println!("STACK_EXEC_BEGIN");

    let f: extern "C" fn() = unsafe { core::mem::transmute(stack_code.as_ptr()) };
    f();

    println!("STACK_EXEC_ALLOWED");
}