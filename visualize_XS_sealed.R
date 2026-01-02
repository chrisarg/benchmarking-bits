library(ggplot2)
library(data.table)
library(scales)
library(viridisLite)
library(nlme)

imgwidth <- 16
plotpointsize <- 1.2
dodge_width <- 0.75
# read benchmark results (CSV files in results/)
files <- list.files("results_XS_sealed", pattern = "*.csv", full.names = TRUE)


# The palette with black:
cbbPalette <- c("#000000", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7")

# read function that reads the file and appends the lang, bitveclen, batch, cpu from filename
read_benchmark_file <- function(file) {
  dt <- fread(file)

  # Expected filename formats:
  # - benchmark_bitvectors_Lang<Lang>_Length<bitveclen>_Batch<batch>_CPU<cpu>.csv
  # - benchmark_bitvectors_Length<bitveclen>_Batch<batch>_CPU<cpu>.csv
  bn <- basename(file)
  re <- "^benchmark_APIsealed_Length([0-9]+)_Batch([0-9]+)_Mode([A-Za-z]+)_CPU(.*)\\.csv$"
  m <- regexec(re, bn)
  parts <- regmatches(bn, m)[[1]]
  if (length(parts) == 0) {
    stop(sprintf("Unexpected benchmark filename format: %s", bn))
  }


  bitveclen_val <- as.numeric(parts[2])
  batch_val <- as.numeric(parts[3])
  mode_val <- parts[4]
  cpu_val <- parts[5]

  dt[, bitveclen := bitveclen_val]
  dt[, batch := batch_val]
  dt[, mode := mode_val]
  dt[, cpu := cpu_val]

  value_cols <- setdiff(names(dt), c("bitveclen", "batch", "mode", "cpu"))
  dt[, (value_cols) := lapply(.SD, as.numeric), .SDcols = value_cols]
  return(dt)
}

data_list <- lapply(files, read_benchmark_file)

# Apply reshape + derived columns per-file, then combine
data_long_list <- lapply(data_list, function(dt) {
  dt_long <- melt(dt,
    id.vars = c("bitveclen", "batch", "mode", "cpu"),
    variable.name = "implementation",
    value.name = "time"
  )

  # now create two new columnes, library and operation by splitting implementation on '_'
  # Some implementation names contain multiple underscores; always take first + last piece.
  dt_long[, c("operation", "approach") := {
    impl <- as.character(implementation)
    spl <- strsplit(impl, "_", fixed = TRUE)
    op <- vapply(spl, function(x) x[[1]], character(1))
    ap <- vapply(spl, function(x) if (length(x) >= 2) x[[length(x)]] else NA_character_, character(1))
    list(op, ap)
  }]

  # relevel the operation column
  dt_long[, operation := factor(
    operation,
    levels = c("CreateSetPut", "CreateAset12.5pct", "CreateAset25pct", "CreateAset50pct", "CreateAset100pct"),
  )]

  # relevel the Approach column
  dt_long[, approach := factor(
    approach,
    levels = c("OO", "Sealed", "Procedural")
  )]
  dt_long
})


data_long <- rbindlist(data_long_list)
# filter data that had negative or zero time values
data_long <- data_long[time > 0]

## Replace multiple spaces in the 'cpu' column with single space
data_long[, cpu := gsub("\\s+", " ", cpu)]

# visualize by approach, faceted by operation and cpu

perlplot1 <- ggplot(data_long, aes(x = factor(bitveclen), y = time, color = approach, shape = mode)) +
  geom_point(size = plotpointsize, position = position_dodge2(width = dodge_width, preserve = "single")) +
  scale_y_log10() +
  facet_grid(operation ~ cpu, scales = "free_y") +
  labs(title = "Bit Vector Benchmarking in Perl", x = "Bit Vector Length", y = "Time (seconds, log10 scale)") +
  theme_grey() +
  scale_colour_manual(values = cbbPalette, name = "Approach") +
  scale_shape_discrete(name = "Implementation") +
  guides(color = guide_legend(override.aes = list(size = 2)), shape = guide_legend(override.aes = list(size = 2))) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), legend.position = "bottom")
ggsave("bitvector_APIsealed.png", width = imgwidth, height = 12, plot = perlplot1)


# now color by processor and facet by operation and approach
processor_plot <- ggplot(data_long, aes(x = factor(bitveclen), y = time, color = cpu, shape = mode)) +
  geom_point(size = plotpointsize, position = position_dodge2(width = dodge_width, preserve = "single")) +
  scale_y_log10() +
  facet_grid(operation ~ approach, scales = "free_y") +
  labs(title = "Bit Vector Benchmarking by Processor", x = "Bit Vector Length", y = "Time (seconds, log10 scale)") +
  theme_grey() +
  scale_colour_manual(values = cbbPalette, name = "Processor") +
  scale_shape_discrete(name = "Implementation") +
  guides(color = guide_legend(override.aes = list(size = 2)), shape = guide_legend(override.aes = list(size = 2))) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), legend.position = "bottom")
ggsave("bitvector_APIsealed_processor.png", width = imgwidth, height = 12, plot = processor_plot)

data_long[,bitlen_fac := factor(bitveclen)]
## carry out a repeated measures regression to see if there are significant differences between the approaches
anova_results <- lme(log(time) ~  mode + log(bitveclen) + cpu+ operation*approach, random = ~1|bitlen_fac, data = data_long)

sink("anova_APIsealed_results.txt")
summary(anova_results)
cat("-----------------------------------\n")
cat("Anova results\n")
cat("-----------------------------------\n")
anova(anova_results)
sink()