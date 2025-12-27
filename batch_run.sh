

# Run against perl alternatives
perl -e '@bitlen=(128,256,512,1024,2048,4096,8192,16384,32768,65536,131072,262144); $iter = 30; $batch = 100; system("./bench_bit_vector_cpan.pl","-bitlen=$_","-iters=$iter","-batch=$batch") for @bitlen;'

# Run against c alternatives
perl -e '@bitlen=(128,256,512,1024,2048,4096,8192,16384,32768,65536,131072,262144);$iter = 30; $batch = 100; system("./benchmark","$_","$iter","$batch") for @bitlen;'