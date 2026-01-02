#include "./c-libs/bit.h"
#include "./c-libs/roaring.c"
#include "benchmark_helper.h"
#include <string.h>

static int *g_rand_indices = NULL;
static uint32_t *g_rand_indices_u32 = NULL;
static uint64_t *g_rand_indices_u64 = NULL;
static int g_rand_indices_len = 0;

typedef struct benchmark_result {
  char approach[51];
  int number_of_iterations;
  double *time_elapsed;
} benchmark_result_t;

#define BENCHMARK(library, operation, bitveclen, batch_size, num_iterations,   \
                  results, test_num)                                           \
  do {                                                                         \
    benchmark_functions(&results[test_num], #library "_" #operation,           \
                        num_iterations, bitveclen, batch_size,                 \
                        library##_##operation);                                \
    test_num++;                                                                \
  } while (0)

void benchmark_functions(benchmark_result_t *results, char *approach,
                         int num_results, int bitveclen, int batch_size,
                         double (*func)(int, int));
void save_csv(benchmark_result_t *results, int num_results,
              const char *outfile);
void test_bit_funcs(int bitveclen);
static void init_random_indices(int bitveclen, int length_array);
void free_random_indices(void);

// CRoaring benchmark functions
double CRoaring_new(int bitveclen, int batch_size);
double CRoaring_FillHalfSeq(int bitveclen, int batch_size);
double CRoaring_FillHalfMany(int bitveclen, int batch_size);
double CRoaring_PopCount(int bitveclen, int batch_size);
double CRoaring_Inter(int bitveclen, int batch_size);
double CRoaring_InterCount(int bitveclen, int batch_size);

// CRoaring64 benchmark functions
double CRoaring64_new(int bitveclen, int batch_size);
double CRoaring64_FillHalfSeq(int bitveclen, int batch_size);
double CRoaring64_FillHalfMany(int bitveclen, int batch_size);
double CRoaring64_PopCount(int bitveclen, int batch_size);
double CRoaring64_Inter(int bitveclen, int batch_size);
double CRoaring64_InterCount(int bitveclen, int batch_size);

// Bitset benchmark functions
double CBitset_new(int bitveclen, int batch_size);
double CBitset_FillHalfSeq(int bitveclen, int batch_size);
double CBitset_PopCount(int bitveclen, int batch_size);
double CBitset_Inter(int bitveclen, int batch_size);
double CBitset_InterCount(int bitveclen, int batch_size);

// Bit_T benchmark functions
double Bit_T_new(int bitveclen, int batch_size);
double Bit_T_FillHalfSeq(int bitveclen, int batch_size);
double Bit_T_FillHalfMany(int bitveclen, int batch_size);
double Bit_T_PopCount(int bitveclen, int batch_size);
double Bit_T_Inter(int bitveclen, int batch_size);
double Bit_T_InterCount(int bitveclen, int batch_size);

static unsigned int g_seed = 100;
#define MAX_CROARING_MANY 4096
int main(int argc, char *argv[]) {
  if (argc != 4 && argc != 5) {
    puts("Usage: ./benchmark <bitveclen> <num of iterations> <batch_size> "
         "[seed]");
    return 1;
  }
  int bitveclen = atoi(argv[1]);
  int num_of_iterations = atoi(argv[2]);
  int batch_size = atoi(argv[3]);
  g_seed = (argc == 5) ? (unsigned int)strtoul(argv[4], NULL, 10) : 100u;

  // assert that we didn't get non-sensical values
  assert(bitveclen > 0);
  assert(batch_size > 0);
  assert(num_of_iterations > 0);

  // Get CPU model
  char cpu[256];
  assert(get_cpu_model(cpu, sizeof cpu) == 0);

  // Create output file name
  char outfile[512];
  snprintf(outfile, sizeof outfile,
           "results/benchmark_bitvectors_Lang%s_Length%d_Batch%d_CPU%s.csv",
           "C", bitveclen, batch_size, cpu);

  printf("Benchmarking bit vector length %d for %d iterations with batch size "
         "%d on CPU: %s\n",
         bitveclen, num_of_iterations, batch_size, cpu);
  // test bit functions for correctness
  puts("Testing bit functions for correctness...");
  test_bit_funcs(bitveclen);
  puts("Passed correctness tests.");

  init_random_indices(bitveclen, bitveclen / 10);
  benchmark_result_t results[32];
  int test_num = 0;

  // C Roaring benchmarks
  BENCHMARK(CRoaring, new, bitveclen, batch_size, num_of_iterations, results,
            test_num);
  BENCHMARK(CRoaring, FillHalfSeq, bitveclen, batch_size, num_of_iterations,
            results, test_num);
  if (bitveclen <= MAX_CROARING_MANY) {
    BENCHMARK(CRoaring, FillHalfMany, bitveclen, batch_size, num_of_iterations,
              results, test_num);
  } else {
    // Skip FillHalfMany for large bitveclen to save time
    results[test_num].time_elapsed =
        (double *)malloc(sizeof(double) * num_of_iterations);
    for (int i = 0; i < num_of_iterations; i++) {
      results[test_num].time_elapsed[i] = -1.0; // Indicate skipped test
    }
    snprintf(results[test_num].approach, sizeof results[test_num].approach,
             "CRoaring_FillHalfMany");
    results[test_num].number_of_iterations = num_of_iterations;
    test_num++;
  }
  BENCHMARK(CRoaring, PopCount, bitveclen, batch_size, num_of_iterations,
            results, test_num);
  BENCHMARK(CRoaring, Inter, bitveclen, batch_size, num_of_iterations, results,
            test_num);
  BENCHMARK(CRoaring, InterCount, bitveclen, batch_size, num_of_iterations,
            results, test_num);

  // C Roaring64 benchmarks
  BENCHMARK(CRoaring64, new, bitveclen, batch_size, num_of_iterations, results,
            test_num);
  BENCHMARK(CRoaring64, FillHalfSeq, bitveclen, batch_size, num_of_iterations,
            results, test_num);
  if (bitveclen <= MAX_CROARING_MANY) {
    BENCHMARK(CRoaring64, FillHalfMany, bitveclen, batch_size,
              num_of_iterations, results, test_num);
  } else {
    // Skip FillHalfMany for large bitveclen to save time
    results[test_num].time_elapsed =
        (double *)malloc(sizeof(double) * num_of_iterations);
    for (int i = 0; i < num_of_iterations; i++) {
      results[test_num].time_elapsed[i] = -1.0; // Indicate skipped test
    }
    snprintf(results[test_num].approach, sizeof results[test_num].approach,
             "CRoaring_FillHalfMany");
    results[test_num].number_of_iterations = num_of_iterations;
    test_num++;
  }
  BENCHMARK(CRoaring64, PopCount, bitveclen, batch_size, num_of_iterations,
            results, test_num);
  BENCHMARK(CRoaring64, Inter, bitveclen, batch_size, num_of_iterations,
            results, test_num);
  BENCHMARK(CRoaring64, InterCount, bitveclen, batch_size, num_of_iterations,
            results, test_num);

  // C Bitset benchmarks
  BENCHMARK(CBitset, new, bitveclen, batch_size, num_of_iterations, results,
            test_num);
  BENCHMARK(CBitset, FillHalfSeq, bitveclen, batch_size, num_of_iterations,
            results, test_num);
  BENCHMARK(CBitset, PopCount, bitveclen, batch_size, num_of_iterations,
            results, test_num);
  BENCHMARK(CBitset, Inter, bitveclen, batch_size, num_of_iterations, results,
            test_num);
  BENCHMARK(CBitset, InterCount, bitveclen, batch_size, num_of_iterations,
            results, test_num);

  BENCHMARK(Bit_T, new, bitveclen, batch_size, num_of_iterations, results,
            test_num);
  BENCHMARK(Bit_T, FillHalfSeq, bitveclen, batch_size, num_of_iterations,
            results, test_num);
  BENCHMARK(Bit_T, FillHalfMany, bitveclen, batch_size, num_of_iterations,
            results, test_num);
  BENCHMARK(Bit_T, PopCount, bitveclen, batch_size, num_of_iterations, results,
            test_num);
  BENCHMARK(Bit_T, Inter, bitveclen, batch_size, num_of_iterations, results,
            test_num);
  BENCHMARK(Bit_T, InterCount, bitveclen, batch_size, num_of_iterations,
            results, test_num);
  save_csv(results, test_num, outfile);
  free_random_indices();
}

/******************************************************************************

* CRoaring library

******************************************************************************/

double CRoaring_new(int bitveclen, int batch_size) {
  roaring_bitmap_t *r1;
  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int i = 0; i < batch_size; i++) {
    r1 = roaring_bitmap_create_with_capacity(bitveclen);
    assert(r1 != NULL);
    roaring_bitmap_free(r1);
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);
  return timeElapsed;
}

double CRoaring_FillHalfSeq(int bitveclen, int batch_size) {
  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int b = 0; b < batch_size; b++) {
    roaring_bitmap_t *r1 = roaring_bitmap_create_with_capacity(bitveclen);
    assert(r1 != NULL);
    for (int i = 0; i < bitveclen / 2; i++) {
      roaring_bitmap_add(r1, g_rand_indices_u32[i]);
    }
    roaring_bitmap_free(r1);
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);
  return timeElapsed;
}

double CRoaring_FillHalfMany(int bitveclen, int batch_size) {
  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int b = 0; b < batch_size; b++) {
    roaring_bitmap_t *r1 = roaring_bitmap_create_with_capacity(bitveclen);
    assert(r1 != NULL);
    for (int i = 0; i < g_rand_indices_len; i++) {
      roaring_bitmap_add_many(r1, g_rand_indices_len, g_rand_indices);
    }
    roaring_bitmap_free(r1);
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);
  return timeElapsed;
}

double CRoaring_PopCount(int bitveclen, int batch_size) {
  roaring_bitmap_t *r1 = roaring_bitmap_create_with_capacity(bitveclen);
  assert(r1 != NULL);
  // set random bits (up to bitveclen/2 draws); do not check for duplicates
  for (int i = 0; i < g_rand_indices_len; i++) {
    roaring_bitmap_add(r1, (uint32_t)g_rand_indices[i]);
  }

  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int i = 0; i < batch_size; i++) {
    volatile uint64_t count = roaring_bitmap_get_cardinality(r1);
    (void)count;
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);
  roaring_bitmap_free(r1);
  return timeElapsed;
}

double CRoaring_Inter(int bitveclen, int batch_size) {
  roaring_bitmap_t *r1 = roaring_bitmap_create_with_capacity(bitveclen);
  roaring_bitmap_t *r2 = roaring_bitmap_create_with_capacity(bitveclen);
  assert(r1 != NULL && r2 != NULL);

  // set half the bits in both bitsets (deterministic, reproducible)
  for (int i = 0; i < g_rand_indices_len; i++) {
    roaring_bitmap_add(r1, (uint32_t)g_rand_indices[i]);
    roaring_bitmap_add(r2, (uint32_t)g_rand_indices[i]);
  }

  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int i = 0; i < batch_size; i++) {
    roaring_bitmap_t *r_and = roaring_bitmap_and(r1, r2);
    assert(r_and != NULL);
    roaring_bitmap_free(r_and);
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);

  roaring_bitmap_free(r1);
  roaring_bitmap_free(r2);
  return timeElapsed;
}

double CRoaring_InterCount(int bitveclen, int batch_size) {
  roaring_bitmap_t *r1 = roaring_bitmap_create_with_capacity(bitveclen);
  roaring_bitmap_t *r2 = roaring_bitmap_create_with_capacity(bitveclen);
  assert(r1 != NULL && r2 != NULL);

  // set half the bits in both bitsets (deterministic, reproducible)
  for (int i = 0; i < g_rand_indices_len; i++) {
    roaring_bitmap_add(r1, (uint32_t)g_rand_indices[i]);
    roaring_bitmap_add(r2, (uint32_t)g_rand_indices[i]);
  }

  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int i = 0; i < batch_size; i++) {
    volatile uint64_t count = roaring_bitmap_and_cardinality(r1, r2);
    (void)count;
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);

  roaring_bitmap_free(r1);
  roaring_bitmap_free(r2);
  return timeElapsed;
}
/******************************************************************************

* CRoaring64 library

******************************************************************************/
double CRoaring64_new(int bitveclen, int batch_size) {
  roaring64_bitmap_t *r1;
  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int i = 0; i < batch_size; i++) {
    r1 = roaring64_bitmap_create();
    assert(r1 != NULL);
    roaring64_bitmap_free(r1);
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);
  return timeElapsed;
}

double CRoaring64_FillHalfSeq(int bitveclen, int batch_size) {
  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int b = 0; b < batch_size; b++) {
    roaring64_bitmap_t *r1 = roaring64_bitmap_create();
    assert(r1 != NULL);
    for (int i = 0; i < bitveclen / 2; i++) {
      roaring64_bitmap_add(r1, g_rand_indices_u64[i]);
    }
    roaring64_bitmap_free(r1);
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);
  return timeElapsed;
}

double CRoaring64_FillHalfMany(int bitveclen, int batch_size) {
  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int b = 0; b < batch_size; b++) {
    roaring64_bitmap_t *r1 = roaring64_bitmap_create();
    assert(r1 != NULL);
    for (int i = 0; i < g_rand_indices_len; i++) {
      roaring64_bitmap_add_many(r1, g_rand_indices_len, g_rand_indices_u64);
    }
    roaring64_bitmap_free(r1);
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);
  return timeElapsed;
}

double CRoaring64_PopCount(int bitveclen, int batch_size) {
  roaring64_bitmap_t *r1 = roaring64_bitmap_create();
  assert(r1 != NULL);
  // set random bits (up to bitveclen/2 draws); do not check for duplicates
  for (int i = 0; i < g_rand_indices_len; i++) {
    roaring64_bitmap_add(r1, g_rand_indices_u64[i]);
  }

  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int i = 0; i < batch_size; i++) {
    volatile uint64_t count = roaring64_bitmap_get_cardinality(r1);
    (void)count;
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);
  roaring64_bitmap_free(r1);
  return timeElapsed;
}

double CRoaring64_Inter(int bitveclen, int batch_size) {
  roaring64_bitmap_t *r1 = roaring64_bitmap_create();
  roaring64_bitmap_t *r2 = roaring64_bitmap_create();
  assert(r1 != NULL && r2 != NULL);

  // set half the bits in both bitsets (deterministic, reproducible)
  for (int i = 0; i < g_rand_indices_len; i++) {
    roaring64_bitmap_add(r1, g_rand_indices_u64[i]);
    roaring64_bitmap_add(r2, g_rand_indices_u64[i]);
  }

  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int i = 0; i < batch_size; i++) {
    roaring64_bitmap_t *r_and = roaring64_bitmap_and(r1, r2);
    assert(r_and != NULL);
    roaring64_bitmap_free(r_and);
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);

  roaring64_bitmap_free(r1);
  roaring64_bitmap_free(r2);
  return timeElapsed;
}

double CRoaring64_InterCount(int bitveclen, int batch_size) {
  roaring64_bitmap_t *r1 = roaring64_bitmap_create();
  roaring64_bitmap_t *r2 = roaring64_bitmap_create();
  assert(r1 != NULL && r2 != NULL);

  // set half the bits in both bitsets (deterministic, reproducible)
  for (int i = 0; i < g_rand_indices_len; i++) {
    roaring64_bitmap_add(r1, g_rand_indices_u64[i]);
    roaring64_bitmap_add(r2, g_rand_indices_u64[i]);
  }

  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int i = 0; i < batch_size; i++) {
    volatile uint64_t count = roaring64_bitmap_and_cardinality(r1, r2);
    (void)count;
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);

  roaring64_bitmap_free(r1);
  roaring64_bitmap_free(r2);
  return timeElapsed;
}

/******************************************************************************

* CBitset library

******************************************************************************/

double CBitset_new(int bitveclen, int batch_size) {
  bitset_t *b1;
  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int i = 0; i < batch_size; i++) {
    b1 = bitset_create_with_capacity(bitveclen);
    assert(b1 != NULL);
    bitset_free(b1);
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);
  return timeElapsed;
}

double CBitset_FillHalfSeq(int bitveclen, int batch_size) {
  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int b = 0; b < batch_size; b++) {
    bitset_t *b1 = bitset_create_with_capacity(bitveclen);
    assert(b1 != NULL);
    for (int i = 0; i < g_rand_indices_len; i++) {
      bitset_set(b1, (size_t)g_rand_indices[i]);
    }
    bitset_free(b1);
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);
  return timeElapsed;
}

double CBitset_PopCount(int bitveclen, int batch_size) {
  bitset_t *b1 = bitset_create_with_capacity(bitveclen);
  assert(b1 != NULL);
  // set random bits (up to bitveclen/2 draws); do not check for duplicates
  srand(g_seed);
  for (int i = 0; i < g_rand_indices_len; i++) {
    int idx = g_rand_indices[i];
    bitset_set(b1, (size_t)idx);
  }

  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int i = 0; i < batch_size; i++) {
    volatile uint64_t count = bitset_count(b1);
    (void)count;
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);
  bitset_free(b1);
  return timeElapsed;
}

double CBitset_Inter(int bitveclen, int batch_size) {
  bitset_t *b1 = bitset_create_with_capacity(bitveclen);
  bitset_t *b2 = bitset_create_with_capacity(bitveclen);
  assert(b1 != NULL && b2 != NULL);

  // set half the bits in both bitsets (deterministic, reproducible)
  for (int i = 0; i < bitveclen / 2; i++) {
    bitset_set(b1, (size_t)i);
    bitset_set(b2, (size_t)i);
  }

  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int i = 0; i < batch_size; i++) {
    bitset_t *tmp = bitset_copy(b1);
    assert(tmp != NULL);
    bitset_inplace_intersection(tmp, b2);
    bitset_free(tmp);
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);

  bitset_free(b1);
  bitset_free(b2);
  return timeElapsed;
}

double CBitset_InterCount(int bitveclen, int batch_size) {
  bitset_t *b1 = bitset_create_with_capacity(bitveclen);
  bitset_t *b2 = bitset_create_with_capacity(bitveclen);
  assert(b1 != NULL && b2 != NULL);

  // set half the bits in both bitsets (deterministic, reproducible)
  for (int i = 0; i < g_rand_indices_len; i++) {
    bitset_set(b1, (size_t)g_rand_indices[i]);
    bitset_set(b2, (size_t)g_rand_indices[i]);
  }

  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int i = 0; i < batch_size; i++) {
    volatile size_t count = bitset_intersection_count(b1, b2);
    (void)count;
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);

  bitset_free(b1);
  bitset_free(b2);
  return timeElapsed;
}

/******************************************************************************

* Bit_T library

******************************************************************************/

double Bit_T_new(int bitveclen, int batch_size) {
  Bit_T b1;
  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int i = 0; i < batch_size; i++) {
    b1 = Bit_new(bitveclen);
    assert(b1 != NULL);
    Bit_free(&b1);
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);
  return timeElapsed;
}

double Bit_T_FillHalfSeq(int bitveclen, int batch_size) {
  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int b = 0; b < batch_size; b++) {
    Bit_T b1 = Bit_new(bitveclen);
    assert(b1 != NULL);
    for (int i = 0; i < g_rand_indices_len; i++) {
      Bit_bset(b1, g_rand_indices[i]);
    }
    Bit_free(&b1);
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);
  return timeElapsed;
}

double Bit_T_FillHalfMany(int bitveclen, int batch_size) {
  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int b = 0; b < batch_size; b++) {
    Bit_T b1 = Bit_new(bitveclen);
    assert(b1 != NULL);
    Bit_aset(b1, g_rand_indices, g_rand_indices_len);
    Bit_free(&b1);
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);
  return timeElapsed;
}

double Bit_T_PopCount(int bitveclen, int batch_size) {
  Bit_T b1 = Bit_new(bitveclen);
  assert(b1 != NULL);
  // set random bits (up to bitveclen/2 draws); do not check for duplicates
  srand(g_seed);
  for (int i = 0; i < g_rand_indices_len; i++) {
    int idx = g_rand_indices[i];
    Bit_bset(b1, idx);
  }

  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int i = 0; i < batch_size; i++) {
    volatile uint64_t count = Bit_count(b1);
    (void)count;
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);
  Bit_free(&b1);
  return timeElapsed;
}

double Bit_T_Inter(int bitveclen, int batch_size) {
  Bit_T b1 = Bit_new(bitveclen);
  Bit_T b2 = Bit_new(bitveclen);
  assert(b1 != NULL && b2 != NULL);

  // set half the bits in both bitsets (deterministic, reproducible)
  for (int i = 0; i < bitveclen / 2; i++) {
    Bit_bset(b1, i);
    Bit_bset(b2, i);
  }

  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int i = 0; i < batch_size; i++) {
    Bit_T inter = Bit_inter(b1, b2);
    assert(inter != NULL);
    Bit_free(&inter);
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);

  Bit_free(&b1);
  Bit_free(&b2);
  return timeElapsed;
}

double Bit_T_InterCount(int bitveclen, int batch_size) {
  Bit_T b1 = Bit_new(bitveclen);
  Bit_T b2 = Bit_new(bitveclen);
  assert(b1 != NULL && b2 != NULL);

  // set half the bits in both bitsets (deterministic, reproducible)
  for (int i = 0; i < g_rand_indices_len; i++) {
    Bit_bset(b1, g_rand_indices[i]);
    Bit_bset(b2, g_rand_indices[i]);
  }

  struct timespec start_time, end_time;
  double timeElapsed = 0;
  clock_gettime(CLOCK_MONOTONIC, &start_time);
  for (int i = 0; i < batch_size; i++) {
    volatile int count = Bit_inter_count(b1, b2);
    (void)count;
  }
  clock_gettime(CLOCK_MONOTONIC, &end_time);
  timeElapsed = timeDiff(&end_time, &start_time);

  Bit_free(&b1);
  Bit_free(&b2);
  return timeElapsed;
}

/*****************************************************************************/

// create a CRoaring, a Cbitset and a Bit_T, set half the bits, and count the
// number of set bits
void test_bit_funcs(int bitveclen) {
  // CRoaring
  roaring_bitmap_t *r1 = roaring_bitmap_create_with_capacity(bitveclen);
  roaring_bitmap_t *r2 = roaring_bitmap_create_with_capacity(bitveclen);
  int *arr = (int *)calloc((bitveclen / 2), sizeof(int));
  assert(r1 != NULL);
  for (int i = 0; i < bitveclen / 2; i++) {
    roaring_bitmap_add(r1, i);
    arr[i] = i;
  }
  uint64_t count1 = roaring_bitmap_get_cardinality(r1);
  roaring_bitmap_add_many(r2, bitveclen / 2, (uint32_t *)arr);
  uint64_t countr2 = roaring_bitmap_get_cardinality(r2);
  free(arr);
  roaring_bitmap_free(r1);
  roaring_bitmap_free(r2);
  // CBitset
  bitset_t *b1 = bitset_create_with_capacity(bitveclen);
  assert(b1 != NULL);
  for (int i = 0; i < bitveclen / 2; i++) {
    bitset_set(b1, i);
  }
  uint64_t count2 = bitset_count(b1);
  bitset_free(b1);

  // Bit_T
  Bit_T b2 = Bit_new(bitveclen);
  assert(b2 != NULL);
  for (int i = 0; i < bitveclen / 2; i++) {
    Bit_bset(b2, i);
  }
  uint64_t count3 = Bit_count(b2);
  Bit_free(&b2);

  // Verify counts are equal
  assert(count1 == count2 && count2 == count3 && count3 == countr2);
}
// Benchmarking helper functions
void benchmark_functions(benchmark_result_t *results, char *approach,
                         int num_results, int bitveclen, int batch_size,
                         double (*func)(int, int)) {

  strncpy(results->approach, approach, sizeof(results->approach) - 1);

  results->number_of_iterations = num_results;
  results->time_elapsed = (double *)malloc(num_results * sizeof(double));

  for (int i = 0; i < num_results; i++) {
    results->time_elapsed[i] = func(bitveclen, batch_size);
  }
}

void save_csv(benchmark_result_t *results, int num_results,
              const char *outfile) {
  FILE *f = fopen(outfile, "w");
  if (!f) {
    fprintf(stderr, "Error opening file %s for writing\n", outfile);
    return;
  }

  // Write header i.e. the approach strings
  for (int i = 0; i < num_results - 1; i++) {
    fprintf(f, "%s,", results[i].approach);
  }
  fprintf(f, "%s\n", results[num_results - 1].approach);

  // Write data
  for (int j = 1; j <= results[0].number_of_iterations; j++) {
    for (int i = 0; i < num_results - 1; i++) {
      fprintf(f, "%lf,", results[i].time_elapsed[j - 1]);
    }
    fprintf(f, "%lf\n", results[num_results - 1].time_elapsed[j - 1]);
  }

  fclose(f);
}

// Returns a pointer to a static array of length == bitveclen.
// Each entry is a random integer in [0, bitveclen-1], generated
// reproducibly from g_seed.
static void init_random_indices(int bitveclen, int length_array) {
  if (bitveclen <= 0 || length_array <= 0) {
    return;
  }

  if (g_rand_indices == NULL || g_rand_indices_len != length_array) {
    unsigned int *tmp =
        (int *)calloc((size_t)length_array, sizeof(unsigned int));
    uint32_t *tmp_u32 =
        (uint32_t *)calloc((size_t)length_array, sizeof(uint32_t));
    uint64_t *tmp_u64 =
        (uint64_t *)calloc((size_t)length_array, sizeof(uint64_t));
    if (!tmp || !tmp_u32 || !tmp_u64) {
      free(g_rand_indices);
      free(g_rand_indices_u32);
      free(g_rand_indices_u64);
      g_rand_indices = NULL;
      g_rand_indices_len = 0;
      return;
    }
    g_rand_indices = tmp;
    g_rand_indices_u32 = tmp_u32;
    g_rand_indices_u64 = tmp_u64;
    g_rand_indices_len = length_array;
  }

  srand(g_seed);
  for (int i = 0; i < length_array; i++) {
    g_rand_indices[i] = rand() % (bitveclen / 2);
    g_rand_indices_u32[i] = (uint32_t)g_rand_indices[i];
    g_rand_indices_u64[i] = (uint64_t)g_rand_indices[i];
  }
}

void free_random_indices(void) {
  free(g_rand_indices);
  g_rand_indices = NULL;
  free(g_rand_indices_u32);
  g_rand_indices_u32 = NULL;
  free(g_rand_indices_u64);
  g_rand_indices_u64 = NULL;
  g_rand_indices_len = 0;
}