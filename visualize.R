library(ggplot2)
library(data.table)
library(scales)
library(viridisLite)

imgwidth <- 16
# read benchmark results (CSV files in results/)
files <- list.files("results", pattern="*.csv", full.names=TRUE)



# read function that reads the file and appends the lang, bitveclen, batch, cpu from filename
read_benchmark_file <- function(file) {
  dt <- fread(file)

  # Expected filename formats:
  # - benchmark_bitvectors_Lang<Lang>_Length<bitveclen>_Batch<batch>_CPU<cpu>.csv
  # - benchmark_bitvectors_Length<bitveclen>_Batch<batch>_CPU<cpu>.csv
  bn <- basename(file)
  re <- "^benchmark_bitvectors_(?:Lang([^_]+)_)?Length([0-9]+)_Batch([0-9]+)_CPU(.*)\\.csv$"
  m <- regexec(re, bn)
  parts <- regmatches(bn, m)[[1]]
  if (length(parts) == 0) {
    stop(sprintf("Unexpected benchmark filename format: %s", bn))
  }

  lang_val <- if (nzchar(parts[2])) parts[2] else NA_character_
  bitveclen_val <- as.numeric(parts[3])
  batch_val <- as.numeric(parts[4])
  cpu_val <- parts[5]

  dt[, lang := lang_val]
  dt[, bitveclen := bitveclen_val]
  dt[, batch := batch_val]
  dt[, cpu := cpu_val]

  value_cols <- setdiff(names(dt), c("lang", "bitveclen", "batch", "cpu"))
  dt[, (value_cols) := lapply(.SD, as.numeric), .SDcols = value_cols]
  return(dt)
}

data_list <- lapply(files, read_benchmark_file)

# Apply reshape + derived columns per-file, then combine
data_long_list <- lapply(data_list, function(dt) {
  dt_long <- melt(dt,
    id.vars = c("lang", "bitveclen", "batch", "cpu"),
    variable.name = "implementation",
    value.name = "time"
  )

  # now create two new columnes, library and operation by splitting implementation on '_'
  # Some implementation names contain multiple underscores; always take first + last piece.
  dt_long[, c("library", "operation") := {
    impl <- as.character(implementation)
    spl <- strsplit(impl, "_", fixed = TRUE)
    lib <- vapply(spl, function(x) x[[1]], character(1))
    op <- vapply(spl, function(x) if (length(x) >= 2) x[[length(x)]] else NA_character_, character(1))
    list(lib, op)
  }]

  # refactor the operation column to have more readable names
  dt_long[, operation := factor(
    operation,
    levels = c("new", "Inter", "InterCount", "PopCount", "FillHalfSeq", "FillHalfMany"),
    labels = c("Constructor/Destructor", "Intersection", "Intersection Count", "Population Count", "Fill Half Sequential", "Fill Half Many")
  )]

  dt_long
})

data_long <- rbindlist(data_long_list)
# filter data that had negative or zero time values
data_long <- data_long[time > 0]

# visualize the data using ggplot2; first select only the Perl language, and provide the average and standard deviation (using geometry point and pointrange in logarithmic 2 scale, faceting by operation and processor, using a color scale for library; in the plots  the y axis is time in log2 seconds and the x axis is bitveclen (as factor). Connect the points with lines.

perl_data <- data_long[lang == "Perl"]
perlplot1<-ggplot(perl_data, aes(x=factor(bitveclen), y=time, color=library)) +
  geom_point(size=0.2, position=position_dodge2(width=0.4)) +
  scale_y_log10() +
  facet_grid(operation ~ cpu, scales="free_y") +
  labs(title="Bit Vector Benchmarking in Perl", x="Bit Vector Length", y="Time (seconds, log10 scale)") +
  theme_grey() +scale_colour_viridis_d(name = "Library", option = "turbo") +
  guides(color = guide_legend(override.aes = list(size = 2))) + 
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) 
ggsave("bitvector_benchmark_perl.png", width=imgwidth, height=12,plot=perlplot1)

c_data <- data_long[lang == "C"]
cplot1<-ggplot(c_data, aes(x=factor(bitveclen), y=time, color=library)) +
  geom_point(size=0.2, position=position_dodge2(width=0.4)) +
  scale_y_log10() + 
  facet_grid(operation ~ cpu, scales="free_y") +
  labs(title="Bit Vector Benchmarking in C", x="Bit Vector Length", y="Time (seconds, log10 scale)") +
  theme_grey() +scale_colour_viridis_d(name = "Library", option = "turbo") +
  guides(color = guide_legend(override.aes = list(size = 2))) + 
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) 
ggsave("bitvector_benchmark_c.png", width=imgwidth, height=12,plot=cplot1)


# create a new feature that combines the language and library into a single column lang_library
data_long[, lang_library := paste(lang, library, sep = "_")]
combined_plot<-ggplot(data_long, aes(x=factor(bitveclen), y=time, color=lang_library)) +
  geom_point(size=0.2, position=position_dodge2(width=0.4)) +
  scale_y_log10() + 
  facet_grid(operation ~ cpu, scales="free_y") +
  labs(title="Bit Vector Benchmarking in Perl and C", x="Bit Vector Length", y="Time (seconds, log10 scale)") +
  theme_grey() +scale_colour_viridis_d(name = "Library", option = "turbo") +
  guides(color = guide_legend(override.aes = list(size = 2))) + 
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) 
ggsave("bitvector_benchmark_perl_c.png", width=imgwidth, height=12,plot=combined_plot)