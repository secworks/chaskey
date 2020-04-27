/*
   Chaskey-12 reference C implementation

   Written in 2015 by Nicky Mouha, based on Chaskey

   To the extent possible under law, the author has dedicated all copyright
   and related and neighboring rights to this software to the public domain
   worldwide. This software is distributed without any warranty.

   You should have received a copy of the CC0 Public Domain Dedication along with
   this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.

   NOTE: This implementation assumes a little-endian architecture
         that does not require aligned memory accesses.
*/
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>

#define DEBUG 1

#define ROTL(x,b) (uint32_t)( ((x) >> (32 - (b))) | ( (x) << (b)) )

#define SUB_ROUND_1A \
  v[0] += v[1]; v[1]=ROTL(v[1], 5);

#define SUB_ROUND_1B \
  v[1] ^= v[0]; v[0]=ROTL(v[0],16);

#define SUB_ROUND_2A \
  v[2] += v[3]; v[3]=ROTL(v[3], 8);

#define SUB_ROUND_2B \
  v[3] ^= v[2];

#define SUB_ROUND_3A \
    v[0] += v[3]; v[3]=ROTL(v[3],13);

#define SUB_ROUND_3B \
    v[3] ^= v[0];

#define SUB_ROUND_4A \
  v[2] += v[1]; v[1]=ROTL(v[1], 7);

#define SUB_ROUND_4B \
  v[1] ^= v[2]; v[2]=ROTL(v[2],16);

#define ROUND \
  do { \
    printf("\n"); \
    SUB_ROUND_1A; \
    printf("SUB_ROUND_1A: v[0]: 0x%08x, v[1]: 0x%08x \n", v[0], v[1]); \
    SUB_ROUND_1B; \
    printf("SUB_ROUND_1A: v[0]: 0x%08x, v[1]: 0x%08x \n", v[0], v[1]); \
    SUB_ROUND_2A; \
    printf("SUB_ROUND_2A: v[2]: 0x%08x, v[3]: 0x%08x \n", v[2], v[3]); \
    SUB_ROUND_2B; \
    printf("SUB_ROUND_2B: v[2]: 0x%08x, v[3]: 0x%08x \n", v[2], v[3]); \
    SUB_ROUND_3A; \
    printf("SUB_ROUND_3A: v[0]: 0x%08x, v[3]: 0x%08x \n", v[0], v[3]); \
    SUB_ROUND_3B; \
    printf("SUB_ROUND_3B: v[0]: 0x%08x, v[3]: 0x%08x \n", v[0], v[3]); \
    SUB_ROUND_4A; \
    printf("SUB_ROUND_4A: v[1]: 0x%08x, v[2]: 0x%08x \n", v[1], v[2]); \
    SUB_ROUND_4B; \
    printf("SUB_ROUND_4B: v[1]: 0x%08x, v[2]: 0x%08x \n", v[1], v[2]); \
    printf("\n"); \
  } while(0)

const volatile uint32_t C[2] = { 0x00, 0x87 };

#define TIMESTWO(out,in) \
  do { \
    out[0] = (in[0] << 1) ^ C[in[3] >> 31]; \
    out[1] = (in[1] << 1) | (in[0] >> 31); \
    out[2] = (in[2] << 1) | (in[1] >> 31); \
    out[3] = (in[3] << 1) | (in[2] >> 31); \
  } while(0)

void subkeys(uint32_t k1[4], uint32_t k2[4], const uint32_t k[4]) {
  TIMESTWO(k1,k);
  TIMESTWO(k2,k1);
}

void chaskey(uint8_t *tag, uint32_t taglen, const uint8_t *m, const uint32_t mlen, const uint32_t k[4], const uint32_t k1[4], const uint32_t k2[4]) {

  const uint32_t *M = (uint32_t*) m;
  const uint32_t *end = M + (((mlen-1)>>4)<<2); /* pointer to last message block */

  const uint32_t *l;
  uint8_t lb[16];
  const uint32_t *lastblock;
  uint32_t v[4];

  int i;
  uint8_t *p;

  assert(taglen <= 16);

  v[0] = k[0];
  v[1] = k[1];
  v[2] = k[2];
  v[3] = k[3];

  if (mlen != 0) {
    for ( ; M != end; M += 4 ) {
#ifdef DEBUG
      printf("(%3d) v[0] %08x\n", mlen, v[0]);
      printf("(%3d) v[1] %08x\n", mlen, v[1]);
      printf("(%3d) v[2] %08x\n", mlen, v[2]);
      printf("(%3d) v[3] %08x\n", mlen, v[3]);
      printf("(%3d) compress %08x %08x %08x %08x\n", mlen, m[0], m[1], m[2], m[3]);
#endif
      v[0] ^= M[0];
      v[1] ^= M[1];
      v[2] ^= M[2];
      v[3] ^= M[3];

      for (int r = 0 ; r < 12 ; r += 1) {
#ifdef DEBUG
        printf("Round %d\n", r);
        printf("Input:  v[0]: 0x%08x, v[1]: 0x%08x, v[2]: 0x%08x, v[3]: 0x%08x\n", v[0], v[1], v[2], v[3]);
#endif

        ROUND;

#ifdef DEBUG
        printf("Output: v[0]: 0x%08x, v[1]: 0x%08x, v[2]: 0x%08x, v[3]: 0x%08x\n", v[0], v[1], v[2], v[3]);
        printf("\n");
#endif

      }
    }
  }

  if ((mlen != 0) && ((mlen & 0xF) == 0)) {
    l = k1;
    lastblock = M;
  } else {
    l = k2;
    p = (uint8_t*) M;
    i = 0;
    for ( ; p != m + mlen; p++,i++) {
      lb[i] = *p;
    }
    lb[i++] = 0x01; /* padding bit */
    for ( ; i != 16; i++) {
      lb[i] = 0;
    }
    lastblock = (uint32_t*) lb;
  }

#ifdef DEBUG
  printf("(%3d) v[0] %08x\n", mlen, v[0]);
  printf("(%3d) v[1] %08x\n", mlen, v[1]);
  printf("(%3d) v[2] %08x\n", mlen, v[2]);
  printf("(%3d) v[3] %08x\n", mlen, v[3]);
  printf("(%3d) last block %08x %08x %08x %08x\n", mlen, lastblock[0], lastblock[1], lastblock[2], lastblock[3]);
#endif
  v[0] ^= lastblock[0];
  v[1] ^= lastblock[1];
  v[2] ^= lastblock[2];
  v[3] ^= lastblock[3];

  v[0] ^= l[0];
  v[1] ^= l[1];
  v[2] ^= l[2];
  v[3] ^= l[3];

      for (int r = 0 ; r < 12 ; r += 1) {
#ifdef DEBUG
        printf("Round %d\n", r);
        printf("Input:  v[0]: 0x%08x, v[1]: 0x%08x, v[2]: 0x%08x, v[3]: 0x%08x\n", v[0], v[1], v[2], v[3]);
#endif

        ROUND;

#ifdef DEBUG
        printf("Output: v[0]: 0x%08x, v[1]: 0x%08x, v[2]: 0x%08x, v[3]: 0x%08x\n", v[0], v[1], v[2], v[3]);
        printf("\n");
#endif

      }

#ifdef DEBUG
  printf("(%3d) v[0] %08x\n", mlen, v[0]);
  printf("(%3d) v[1] %08x\n", mlen, v[1]);
  printf("(%3d) v[2] %08x\n", mlen, v[2]);
  printf("(%3d) v[3] %08x\n", mlen, v[3]);
#endif

  v[0] ^= l[0];
  v[1] ^= l[1];
  v[2] ^= l[2];
  v[3] ^= l[3];

  memcpy(tag,v,taglen);

}

const uint8_t vectors[64][8] =
{
  { 0xdd, 0x3e, 0x18, 0x49, 0xd6, 0x82, 0x45, 0x55 },
  { 0xed, 0x1d, 0xa8, 0x9e, 0xc9, 0x31, 0x79, 0xca },
  { 0x98, 0xfe, 0x20, 0xa3, 0x43, 0xcd, 0x66, 0x6f },
  { 0xf6, 0xf4, 0x18, 0xac, 0xdd, 0x7d, 0x9f, 0xa1 },
  { 0x4c, 0xf0, 0x49, 0x60, 0x09, 0x99, 0x49, 0xf3 },
  { 0x75, 0xc8, 0x32, 0x52, 0x65, 0x3d, 0x3b, 0x57 },
  { 0x96, 0x4b, 0x04, 0x61, 0xfb, 0xe9, 0x22, 0x73 },
  { 0x14, 0x1f, 0xa0, 0x8b, 0xbf, 0x39, 0x96, 0x36 },
  { 0x41, 0x2d, 0x98, 0xed, 0x93, 0x6d, 0x4a, 0xb2 },
  { 0xfb, 0x0d, 0x98, 0xbc, 0x70, 0xe3, 0x05, 0xf9 },
  { 0x36, 0xf8, 0x8e, 0x1f, 0xda, 0x86, 0xc8, 0xab },
  { 0x4d, 0x1a, 0x18, 0x15, 0x86, 0x8a, 0x5a, 0xa8 },
  { 0x7a, 0x79, 0x12, 0xc1, 0x99, 0x9e, 0xae, 0x81 },
  { 0x9c, 0xa1, 0x11, 0x37, 0xb4, 0xa3, 0x46, 0x01 },
  { 0x79, 0x05, 0x14, 0x2f, 0x3b, 0xe7, 0x7e, 0x67 },
  { 0x6a, 0x3e, 0xe3, 0xd3, 0x5c, 0x04, 0x33, 0x97 },
  { 0xd1, 0x39, 0x70, 0xd7, 0xbe, 0x9b, 0x23, 0x50 },
  { 0x32, 0xac, 0xd9, 0x14, 0xbf, 0xda, 0x3b, 0xc8 },
  { 0x8a, 0x58, 0xd8, 0x16, 0xcb, 0x7a, 0x14, 0x83 },
  { 0x03, 0xf4, 0xd6, 0x66, 0x38, 0xef, 0xad, 0x8d },
  { 0xf9, 0x93, 0x22, 0x37, 0xff, 0x05, 0xe8, 0x31 },
  { 0xf5, 0xfe, 0xdb, 0x13, 0x48, 0x62, 0xb4, 0x71 },
  { 0x8b, 0xb5, 0x54, 0x86, 0xf3, 0x8d, 0x57, 0xea },
  { 0x8a, 0x3a, 0xcb, 0x94, 0xb5, 0xad, 0x59, 0x1c },
  { 0x7c, 0xe3, 0x70, 0x87, 0x23, 0xf7, 0x49, 0x5f },
  { 0xf4, 0x2f, 0x3d, 0x2f, 0x40, 0x57, 0x10, 0xc2 },
  { 0xb3, 0x93, 0x3a, 0x16, 0x7e, 0x56, 0x36, 0xac },
  { 0x89, 0x9a, 0x79, 0x45, 0x42, 0x3a, 0x5e, 0x1b },
  { 0x65, 0xe1, 0x2d, 0xf5, 0xa6, 0x95, 0xfa, 0xc8 },
  { 0xb8, 0x24, 0x49, 0xd8, 0xc8, 0xa0, 0x6a, 0xe9 },
  { 0xa8, 0x50, 0xdf, 0xba, 0xde, 0xfa, 0x42, 0x29 },
  { 0xfd, 0x42, 0xc3, 0x9d, 0x08, 0xab, 0x71, 0xa0 },
  { 0xb4, 0x65, 0xc2, 0x41, 0x26, 0x10, 0xbf, 0x84 },
  { 0x89, 0xc4, 0xa9, 0xdd, 0xb5, 0x3e, 0x69, 0x91 },
  { 0x5a, 0x9a, 0xf9, 0x1e, 0xb0, 0x95, 0xd3, 0x31 },
  { 0x8e, 0x54, 0x91, 0x4c, 0x15, 0x1e, 0x46, 0xb0 },
  { 0xfa, 0xb8, 0xab, 0x0b, 0x5b, 0xea, 0xae, 0xc6 },
  { 0x60, 0xad, 0x90, 0x6a, 0xcd, 0x06, 0xc8, 0x23 },
  { 0x6b, 0x1e, 0x6b, 0xc2, 0x42, 0x6d, 0xad, 0x17 },
  { 0x90, 0x32, 0x8f, 0xd2, 0x59, 0x88, 0x9a, 0x8f },
  { 0xf0, 0xf7, 0x81, 0x5e, 0xe6, 0xf3, 0xd5, 0x16 },
  { 0x97, 0xe7, 0xe2, 0xce, 0xbe, 0xa8, 0x26, 0xb8 },
  { 0xb0, 0xfa, 0x18, 0x45, 0xf7, 0x2a, 0x76, 0xd6 },
  { 0xa4, 0x68, 0xbd, 0xfc, 0xdf, 0x0a, 0xa9, 0xc7 },
  { 0xda, 0x84, 0xe1, 0x13, 0x38, 0x38, 0x7d, 0xa7 },
  { 0xb3, 0x0d, 0x5e, 0xad, 0x8e, 0x39, 0xf2, 0xbc },
  { 0x17, 0x8a, 0x43, 0xd2, 0xa0, 0x08, 0x50, 0x3e },
  { 0x6d, 0xfa, 0xa7, 0x05, 0xa8, 0xa0, 0x6c, 0x70 },
  { 0xaa, 0x04, 0x7f, 0x07, 0xc5, 0xae, 0x8d, 0xb4 },
  { 0x30, 0x5b, 0xbb, 0x42, 0x0c, 0x5d, 0x5e, 0xcc },
  { 0x08, 0x32, 0x80, 0x31, 0x59, 0x75, 0x0f, 0x49 },
  { 0x90, 0x80, 0x25, 0x4f, 0xb7, 0x9b, 0xab, 0x1a },
  { 0x61, 0xc2, 0x85, 0xca, 0x24, 0x57, 0x74, 0xa4 },
  { 0x2a, 0xae, 0x03, 0x5c, 0xfb, 0x61, 0xf9, 0x7a },
  { 0xf5, 0x28, 0x90, 0x75, 0xc9, 0xab, 0x39, 0xe5 },
  { 0xe6, 0x5c, 0x42, 0x37, 0x32, 0xda, 0xe7, 0x95 },
  { 0x4b, 0x22, 0xcf, 0x0d, 0x9d, 0xa8, 0xde, 0x3d },
  { 0x26, 0x26, 0xea, 0x2f, 0xa1, 0xf9, 0xab, 0xcf },
  { 0xd1, 0xe1, 0x7e, 0x6e, 0xc4, 0xa8, 0x8d, 0xa6 },
  { 0x16, 0x57, 0x44, 0x28, 0x27, 0xff, 0x64, 0x0a },
  { 0xfd, 0x15, 0x5a, 0x40, 0xdf, 0x15, 0xf6, 0x30 },
  { 0xff, 0xeb, 0x59, 0x6f, 0x29, 0x9f, 0x58, 0xb2 },
  { 0xbe, 0x4e, 0xe4, 0xed, 0x39, 0x75, 0xdf, 0x87 },
  { 0xfc, 0x7f, 0x9d, 0xf7, 0x99, 0x1b, 0x87, 0xbc }
};

int test_vectors() {
  uint8_t m[64];
  uint8_t tag[8];
  uint8_t k[16] = { 0x00, 0x11, 0x22, 0x33,
                    0x44, 0x55, 0x66, 0x77,
                    0x88, 0x99, 0xaa, 0xbb,
                    0xcc, 0xdd, 0xee, 0xff };
  uint32_t k1[4], k2[4];
  int i;
  int ok = 1;
  uint32_t taglen = 8;

  /* key schedule */
  subkeys(k1,k2,(uint32_t*) k);
#if DEBUG
  printf("K0 %08x %08x %08x %08x\n", k[0], k[1], k[2], k[3]);
  printf("K1 %08x %08x %08x %08x\n", k1[0], k1[1], k1[2], k1[3]);
  printf("K2 %08x %08x %08x %08x\n", k2[0], k2[1], k2[2], k2[3]);
#endif

  /* mac */
  for (i = 0; i < 64; i++) {
    m[i] = i;

    chaskey(tag, taglen, m, i, (uint32_t*) k, k1, k2);

    if (memcmp( tag, vectors[i], taglen )) {
      printf("test vector failed for %d-byte message\n", i);
      ok = 0;
    }
  }

  return ok;
}

int main() {
  if (test_vectors()) printf("test vectors ok\n");

  return 0;
}
