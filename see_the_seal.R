library(ggplot2)
library(data.table)
library(scales)
library(viridisLite)

imgwidth <- 16
plotpointsize <- 0.4
dodge_width <- 0.8
# read benchmark results (CSV files in results/)
files <- list.files("results", pattern="*.csv", full.names=TRUE)

# Only get the Perl results
files <- files[grepl("Sealed", files)]

# The palette with black:
cbbPalette <- c("#000000", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7")

# read function that reads the file and appends the lang, bitveclen, batch, cpu from filename
read_benchmark_file <- function(file) {
  dt <- fread(file)

  # Expected filename formats:
  # - benchmark_bitvectors_Lang<Lang>_Length<bitveclen>_Batch<batch>_CPU<cpu>.csv
  # - benchmark_bitvectors_Length<bitveclen>_Batch<batch>_CPU<cpu>.csv
  bn <- basename(file)
  re <- "^benchmark_bitvectors_Sealed_(?:Lang([^_]+)_)?Length([0-9]+)_Batch([0-9]+)_CPU(.*)\\.csv$"
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

## Replace multiple spaces in the 'cpu' column with single space
data_long[, cpu := gsub("\\s+", " ", cpu)]

# visualize the data using ggplot2; first select only the Perl language, and provide the average and standard deviation (using geometry point and pointrange in logarithmic 2 scale, faceting by operation and processor, using a color scale for library; in the plots  the y axis is time in log2 seconds and the x axis is bitveclen (as factor). Connect the points with lines.

perl_data <- data_long[lang == "Perl"]
perlplot1<-ggplot(perl_data, aes(x=factor(bitveclen), y=time, color=library)) +
  geom_point(size=plotpointsize, position=position_dodge2(width=dodge_width,preserve = "single")) +
  scale_y_log10() +
  facet_grid(operation ~ cpu, scales="free_y") +
  labs(title="Bit Vector Benchmarking in Perl", x="Bit Vector Length", y="Time (seconds, log10 scale)") +
  theme_grey() +scale_colour_manual(values = cbbPalette, name = "Library") +
  guides(color = guide_legend(override.aes = list(size = 4))) + 
  theme(axis.text.x = element_text(angle = 45, hjust = 1), legend.position = "bottom") 
ggsave("bitvector_benchmark_sealed_perl.png", width=imgwidth, height=12,plot=perlplot1)



# now color by processor and facet by operation and language
processor_plot<-ggplot(data_long, aes(x=factor(bitveclen), y=time, color=cpu)) +
  geom_point(size=plotpointsize, position=position_dodge2(width=dodge_width,preserve = "single")) +
  scale_y_log10() + 
  facet_grid(operation ~ library, scales="free_y") +
  labs(title="Bit Vector Benchmarking by Processor", x="Bit Vector Length", y="Time (seconds, log10 scale)") +
  theme_grey() +scale_colour_manual(values = cbbPalette, name = "Processor") +
  guides(color = guide_legend(override.aes = list(size = 2))) + 
  theme(axis.text.x = element_text(angle = 45, hjust = 1), legend.position = "bottom") 
ggsave("bitvector_benchmark_sealed_processor.png", width=imgwidth, height=12,plot=processor_plot)
