#!/bin/bash

# Configuration
bitlen=(128 256 512 1024 2048 4096 8192 16384 32768 65536 131072 262144)
iter=10
batch=1000
max_croaring_many=4096
seed=100

# Run against perl alternatives
echo "Running Perl benchmarks..."
for len in "${bitlen[@]}"; do
    echo "Running Perl benchmark with bitlen=$len"
    perlbrew exec --with bitperl ./bench_bit_vector_cpan.pl -bitlen="$len" -iters="$iter" -batch="$batch"
done

# Run against c alternatives
echo "Running C benchmarks..."
for len in "${bitlen[@]}"; do
    echo "Running C benchmark with bitlen=$len"
    ./benchmark "$len" "$iter" "$batch" "$max_croaring_many" "$seed"
done

echo "All benchmarks completed."