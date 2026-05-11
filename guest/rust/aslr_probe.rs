fn main() {
    let stack_var: i32 = 42;
    let heap_ptr = Box::new(1234);

    println!("PROBE_OK");
    println!("MAIN={:p}", main as *const ());
    println!("STACK={:p}", &stack_var as *const i32);
    println!("HEAP={:p}", &*heap_ptr as *const i32);
}
