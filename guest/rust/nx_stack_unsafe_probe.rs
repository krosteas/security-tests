// guest/rust/nx_stack_unsafe_probe.rs
use core::mem;

type ProbeFn = extern "C" fn();

fn main() {
    println!("PROBE_OK");

    let stack_code: [u8; 1] = [0xC3]; // x86_64 ret instruction

    println!("STACK_EXEC_BEGIN");

    unsafe {
        let f: ProbeFn = mem::transmute(stack_code.as_ptr());
        f();
    }

    println!("STACK_EXEC_ALLOWED");
}