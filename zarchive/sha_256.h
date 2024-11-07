#pragma once

#include <stdint.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

struct Sha_256 {
    uint32_t state[8];
    uint8_t buffer[64];
    uint64_t length;
    uint32_t curlen;
};

void sha_256_init(struct Sha_256* sha, uint8_t hash[32]);
void sha_256_write(struct Sha_256* sha, const void* data, size_t length);
void sha_256_close(struct Sha_256* sha);

#ifdef __cplusplus
}
#endif
