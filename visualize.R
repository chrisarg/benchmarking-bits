library(ggplot2)
library(data.table)
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

data <- rbindlist(data_list)

# now reshape from wide to long format
data_long <- melt(data, id.vars=c("lang", "bitveclen", "batch", "cpu"), variable.name="implementation", value.name="time")

# now create two new columnes, library and operation by splitting implementation on '_'
data_long[, c("library", "operation") := tstrsplit(implementation, "_", fixed=TRUE)]

# refactor the operation column to have more readable names
data_long[, operation := factor(operation, levels=c("new", "Inter", "InterCount", "PopCount"), labels=c("Constructor/Destructor", "Intersection", "Intersection Count", "Population Count"))]

# visualize the data using ggplot2; first select only the Perl language, and provide the average and standard deviation (using geometry point and pointrange in logarithmic 2 scale, faceting by operation and processor, using a color scale for library; in the plots  the y axis is time in log2 seconds and the x axis is bitveclen (as factor). Connect the points with lines.

perl_data <- data_long[lang == "Perl"]
perlplot1<-ggplot(perl_data, aes(x=factor(bitveclen), y=time, color=library)) +
  geom_point(size=0.2, position=position_dodge2(width=0.4)) +
  scale_y_log10() +
  facet_grid(operation ~ cpu, scales="free_y") +
  labs(title="Bit Vector Benchmarking in Perl", x="Bit Vector Length", y="Time (seconds, log10 scale)") +
  theme_bw() +scale_colour_viridis_d(name = "Library") +
  guides(color = guide_legend(override.aes = list(size = 2))) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
ggsave("perl_bitvector_benchmark.png", width=12, height=8,plot=perlplot1)
