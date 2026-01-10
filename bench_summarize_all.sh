./juice_processor_up.sh performance
# run all the benchmarks
./batch_run.sh
# run the XS benchmarks
./bench_XS.sh

# summarize all results using R
Rscript ./visualize.R
Rscript ./visualize_XS_sealed.R

./squeeze_processor.sh
