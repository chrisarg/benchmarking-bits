
# Run against perl alternatives
perl -e '@bitlen=(128,256,512,1024,2048,4096,8192,16384,32768,65536,131072,262144); system("./bench_bit_vector_cpan.pl","-bitlen=$_","-iters=100",-"batch=1000") for @bitlen;'
