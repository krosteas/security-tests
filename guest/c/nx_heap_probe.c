// guest/c/nx_heap_probe.c
#include <stdio.h>
#include <stdlib.h>

typedef void (*probe_fn_t)(void);

int main(void) {
    unsigned char *heap_code = malloc(1);
    if (!heap_code) {
        printf("PROBE_FAIL\n");
        return 2;
    }

    heap_code[0] = 0xC3;   // x86_64: ret

    printf("PROBE_OK\n");
    printf("HEAP_EXEC_BEGIN\n");
    fflush(stdout);

    ((probe_fn_t)heap_code)();

    printf("HEAP_EXEC_ALLOWED\n");
    fflush(stdout);

    free(heap_code);
    return 0;
}