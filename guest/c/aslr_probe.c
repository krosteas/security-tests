// aslr_probe.c
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    int stack_var = 42;
    void *heap_ptr = malloc(16);

    printf("PROBE_OK\n");
    printf("MAIN=%p\n", (void *)&main);
    printf("STACK=%p\n", (void *)&stack_var);
    printf("HEAP=%p\n", heap_ptr);

    free(heap_ptr);
    return 0;
}
