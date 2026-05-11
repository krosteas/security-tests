#[inline(never)]
unsafe fn vulnerable() {
    let mut buf = [0u8; 16];

    println!("CANARY_PROBE_BEGIN");

    let ptr = buf.as_mut_ptr();

    for i in 0..128 {
        core::ptr::write_volatile(ptr.add(i), b'A');
    }

    println!("STACK_SMASH_ALLOWED");
}

fn main() {
    println!("PROBE_OK");

    unsafe {
        vulnerable();
    }

    println!("PROBE_END");
}