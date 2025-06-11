#define _GNU_SOURCE

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <sys/uio.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/types.h>
#include <sys/ptrace.h>

#define MAX_PATTERN_LEN 128
#define MEMORY_CHUNK_SIZE (2 * 1024 * 1024)

int get_pid(void) {
    pid_t pid;
    FILE *cmd;
    char pid_buff[8];

    cmd = popen("pidof cs2", "r");
    fgets(pid_buff, 8, cmd);
    pid = atoi(pid_buff);
    pclose(cmd);

    return pid;
}

void write_mem(unsigned long long addr, pid_t pid) {
    int ret;

    long word;

    unsigned long long ptr = addr + 2;

    uint8_t byte_to_write = 0xc3;

    ret = ptrace(PTRACE_ATTACH, pid, NULL, NULL);

    if (ret == -1) {
        exit(1);
    }

    waitpid(pid, NULL, WUNTRACED);

    unsigned long long aligned_addr = ptr & ~(sizeof(long) - 1);
    long offset_in_word = ptr % sizeof(long);

    word = ptrace(PTRACE_PEEKDATA, pid, aligned_addr, NULL);

    word &= ~((long)0xFF << (offset_in_word * 8));

    word |= ((long) byte_to_write << (offset_in_word * 8));

    ptrace(PTRACE_POKEDATA, pid, aligned_addr, word);

    ptrace(PTRACE_DETACH, pid, NULL, NULL);
}

int hex_to_int(char c) {
    if (c >= '0' && c <= '9') {
        return c - '0';
    } else if (c >= 'A' && c <= 'F') {
        return c - 'A' + 10;
    }

    return -1;
}

size_t get_pattern_len(char *pattern, uint8_t *bytes_out, size_t max_len) {
    size_t pattern_len = 0;

    char *p = pattern;

    while (*p != '\0' && pattern_len < max_len) {
        while (*p == ' ') {
            p++;
        }

        if (*p == '\0') {
            break;
        }

        int high_nibble = hex_to_int(*p);
        int low_nibble = hex_to_int(*(p + 1));

        bytes_out[pattern_len] = (uint8_t)((high_nibble << 4) | low_nibble);

        p += 2; 
        
        pattern_len++;
    }

    return pattern_len;
}

unsigned long long sig_scan(char* pattern, char *file_name, pid_t pid) {
    uint8_t pattern_bytes[MAX_PATTERN_LEN];
    size_t pattern_len;

    char maps_path[128];
    char line[1024];

    pattern_len = get_pattern_len(pattern, pattern_bytes, MAX_PATTERN_LEN);

    unsigned char *read_buffer = (unsigned char*)malloc(MEMORY_CHUNK_SIZE + pattern_len - 1);

    snprintf(maps_path, 128, "/proc/%d/maps", pid);

    FILE *maps_file = fopen(maps_path, "r");

    while(fgets(line, sizeof(line), maps_file) != NULL) {
        unsigned long long start_addr, end_addr;
        char perms[5];

        sscanf(line, "%llx-%llx %4s %*s", &start_addr, &end_addr, perms);

        if (perms[0] != 'r') {
            continue;
        }

        if (strstr(line, file_name) == NULL) {
            continue;
        }

        for (unsigned long long i = start_addr; i < end_addr; i += MEMORY_CHUNK_SIZE) {
            size_t bytes_left = end_addr - i;
            size_t total_bytes_to_read = MEMORY_CHUNK_SIZE + pattern_len - 1;

            if (total_bytes_to_read > bytes_left) {
                total_bytes_to_read = bytes_left;
            }

            if (total_bytes_to_read < pattern_len) {
                continue;
            }

            struct iovec local_iov = { 
                .iov_base = read_buffer, 
                .iov_len = total_bytes_to_read 
            };

            struct iovec remote_iov = {  
                .iov_base = (void *)i,
                .iov_len = total_bytes_to_read
            };

           
            ssize_t nread = process_vm_readv(pid, &local_iov, 1, &remote_iov, 1, 0);

            if (nread == -1) {
                continue;
            }

            for (size_t j = 0; j <= (size_t)nread - pattern_len; ++j) {
                int match = 1;
                for (size_t k = 0; k < pattern_len; ++k) {
                    if (read_buffer[j + k] != pattern_bytes[k]) {
                        match = 0;
                        break;
                    }
                }

                if (match) {
                    unsigned long long found_value = i + j;

                    free(read_buffer);
                    fclose(maps_file);

                    return found_value;
                }
            }
        }
    }

    free(read_buffer);
    fclose(maps_file);

    return -1;
}


int main(void) {
    pid_t pid = get_pid();

    char *pattern = "31 C0 48 85 F6 0F 84";

    unsigned long long addr = sig_scan(pattern, "libclient.so", pid);

    write_mem(addr, pid);

    printf("Patched!\n");

    return 0;
}
