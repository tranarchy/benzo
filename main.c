#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <dirent.h>

#include <sys/wait.h>
#include <sys/ptrace.h>

#include "libsigscan.h"

int get_pid(char *proc_name) {
    pid_t pid;

    char cmdline_buff[512];
    char line[1024];

    DIR *dir;
    FILE *cmdline;
    struct dirent *entry;

    dir = opendir("/proc");

    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_type == DT_DIR) {
            
            if (strcmp(entry->d_name, ".") == 0) {
                continue;
            }

            if (strcmp(entry->d_name, "..") == 0) {
                continue;
            }

            snprintf(cmdline_buff, 512, "/proc/%s/cmdline", entry->d_name);

            cmdline = fopen(cmdline_buff, "r");

            if (cmdline == NULL) {
                continue;
            }

            while(fgets(line, sizeof(line), cmdline) != NULL) {
                if (strstr(line, proc_name) != NULL) {
                    pid = atoi(entry->d_name);

                    fclose(cmdline);
                    closedir(dir);

                    return pid;
                }
            }

            fclose(cmdline);
        }
    }

    closedir(dir);

    return -1;
}

int write_mem(unsigned long long addr, int offset, pid_t pid) {
    int ret;

    long word;

    addr += offset;

    uint8_t byte_to_write = 0xc3;

    ret = ptrace(PTRACE_ATTACH, pid, NULL, NULL);

    if (ret == -1) {
        printf("Couldn't attach to process\n");
        return ret;
    }

    waitpid(pid, NULL, WUNTRACED);

    unsigned long long aligned_addr = addr & ~(sizeof(long) - 1);
    long offset_in_word = addr % sizeof(long);

    word = ptrace(PTRACE_PEEKDATA, pid, aligned_addr, NULL);

    word &= ~((long)0xFF << (offset_in_word * 8));

    word |= ((long) byte_to_write << (offset_in_word * 8));

    ptrace(PTRACE_POKEDATA, pid, aligned_addr, word);

    ptrace(PTRACE_DETACH, pid, NULL, NULL);

    return 0;
}

int main(void) {
    int ret;

    pid_t pid = get_pid("cs2");

    if (pid == -1) {
        printf("CS2 is not running\n");
        return 1;
    }

    char *pattern = "31 C0 48 85 F6 0F 84";
    int offset = 2;

    unsigned long long addr = sig_scan(pattern, "libclient.so", pid);

    if (addr == (unsigned long long) -1) {
        printf("No match found for pattern\n");
        return 1;
    }

    ret = write_mem(addr, offset, pid);

    if (ret == -1) {
        return 1;
    }

    printf("Patched!\n");

    return 0;
}
