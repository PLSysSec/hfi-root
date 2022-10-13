#include <stdio.h>
#include <unistd.h>
#include <sys/mman.h>
#include <stdlib.h>

int main(int argc, char** argv) {
    int mode = argc > 1 ? atoi(argv[1]) : 0;

    char* p = mmap(NULL, 1024*1024*1024, PROT_READ|PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);

    for (int i = 0; i < 1000; i++) {
        for (int j = 0; j < 1024; j++) {
            p[j << 20] = 1;
            if (mode & 1) {
                madvise(p + (j * 1024*1024), 1024*1024, MADV_DONTNEED);
            }
        }

        if (mode & 2) {
            madvise(p, 1024*1024*1024, MADV_DONTNEED);
        }
    }
}
