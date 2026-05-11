#include <stdio.h>
#include <string.h>

__attribute__((noinline))
void vulnerable(void) {
    volatile char buf[16];

    printf("CANARY_PROBE_BEGIN\n");
    fflush(stdout);

    memset((void *)buf, 'A', 128);

    printf("STACK_SMASH_ALLOWED\n");
    fflush(stdout);
}

int main(void) {
    printf("PROBE_OK\n");
    fflush(stdout);

    vulnerable();

    printf("PROBE_END\n");
    fflush(stdout);
    return 0;
}