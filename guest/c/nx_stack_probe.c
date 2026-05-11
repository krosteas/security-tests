// guest/c/nx_stack_probe.c
#include <stdio.h>

typedef void (*probe_fn_t)(void);

int main(void) {
    unsigned char stack_code[1];
    stack_code[0] = 0xC3;   // x86_64: ret

    printf("PROBE_OK\n");
    printf("STACK_EXEC_BEGIN\n");
    fflush(stdout);

    ((probe_fn_t)stack_code)();

    printf("STACK_EXEC_ALLOWED\n");
    fflush(stdout);
    return 0;
}