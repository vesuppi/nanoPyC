__inline__ __device__ float warpReduce(float value) {
    // Use XOR mode to perform butterfly reduction
    for (int i=16; i>=1; i/=2)
        value += __shfl_xor_sync(0xffffffff, value, i, 32);

    // "value" now contains the sum across all threads
    //printf("Thread %d final value = %d\n", threadIdx.x, value);
    return value;
}

__inline__ __device__ float blockReduce(float sum) {
    sum = warpReduce(sum);
    int tid = threadIdx.x;
    __shared__ float psums[16];
    if (tid % 32 == 0) {
        psums[tid / 32] = sum;
    }
    __syncthreads();

    sum = 0;
    for (int i = 0; i < blockDim.x / 32; i++) {
        sum += psums[i];
    }
    return sum;
}

extern "C" __global__
void kernel(int M, int N, float* a, float* c) {
    int m = blockIdx.x;
    int tid = threadIdx.x;

    if (m > M) {
        return;
    }

    const int ROW_SIZE = 1024*4;
    assert(N <= ROW_SIZE);

    /** Load array a into the shared memory (later reused)
     */
    __shared__ float exps[ROW_SIZE];
    for (int n = tid; n < N; n += blockDim.x) {
        if (n < N) {
            exps[n] = exp(a[m*N + n]);
        }
    }

    /** Accumulate the partial sums into the shared memory 
     */

    float sum = 0;
    for (int n = tid; n < N; n += blockDim.x) {
        if (n < N) {
            sum += exps[n];
        }
    }

    __syncthreads();

    sum = blockReduce(sum);

    for (int n = tid; n < N; n += blockDim.x) {
        if (n < N) {
            c[m*N+n] = exps[n] / sum;
        }
    }
}