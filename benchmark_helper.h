#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

double timeDiff(struct timespec *timeA_p, struct timespec *timeB_p);
int get_cpu_model(char *out, size_t out_sz);


// Various functions
double timeDiff(struct timespec *timeA_p, struct timespec *timeB_p) {
  return ((timeA_p->tv_sec - timeB_p->tv_sec) * 1000000000 + timeA_p->tv_nsec -
          timeB_p->tv_nsec) /
         1.0e9;
}

int get_cpu_model(char *out, size_t out_sz) {
  FILE *f = fopen("/proc/cpuinfo", "r");
  if (!f)
    return -1;

  char model[256] = {0};
  int have_model = 0;
  int cores = 0;

  char line[512];
  while (fgets(line, sizeof line, f)) {
    // Count logical CPUs (one "processor" entry per logical core on Linux)
    if (strncmp(line, "processor", strlen("processor")) == 0) {
      char *colon = strchr(line, ':');
      if (colon)
        cores++;
    }

    if (!have_model) {
      // x86 usually has: "model name\t: Intel(R) ... "
      const char *key1 = "model name";
      const char *key2 = "Hardware";  // common on ARM
      const char *key3 = "Processor"; // sometimes on ARM

      const char *keys[] = {key1, key2, key3};
      for (size_t i = 0; i < sizeof(keys) / sizeof(keys[0]); i++) {
        size_t klen = strlen(keys[i]);
        if (strncmp(line, keys[i], klen) == 0) {
          char *colon = strchr(line, ':');
          if (!colon)
            continue;
          colon++; // skip ':'
          while (*colon == ' ' || *colon == '\t')
            colon++;

          // trim trailing newline
          char *nl = strchr(colon, '\n');
          if (nl)
            *nl = '\0';

          snprintf(model, sizeof model, "%s", colon);
          have_model = 1;
          break;
        }
      }
    }
  }

  fclose(f);
  if (!have_model)
    return -2; // not found

  if (cores <= 0)
    cores = 1;

  snprintf(out, out_sz, "%d x %s", cores, model);
  return 0;
}