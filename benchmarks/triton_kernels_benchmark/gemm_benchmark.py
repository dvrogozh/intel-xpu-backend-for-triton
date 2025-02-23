"""
Gemm benchmark
============================

This benchmark is come from the Triton tutorial 10-experimental-block-pointer.py
To compare the performance to XeTLA kernel.

"""

# %%
# Motivations
# -----------
# In the previous matrix multiplication tutorial, we constructed blocks of values by de-referencing blocks of pointers,
# i.e., :code:`load(block<pointer_type<element_type>>) -> block<element_type>`, which involved loading blocks of
# elements from memory. This approach allowed for flexibility in using hardware-managed cache and implementing complex
# data structures, such as tensors of trees or unstructured look-up tables.
#
# However, the drawback of this approach is that it relies heavily on complex optimization passes by the compiler to
# optimize memory access patterns. This can result in brittle code that may suffer from performance degradation when the
# optimizer fails to perform adequately. Additionally, as memory controllers specialize to accommodate dense spatial
# data structures commonly used in machine learning workloads, this problem is likely to worsen.
#
# To address this issue, we will use block pointers :code:`pointer_type<block<element_type>>` and load them into
# :code:`block<element_type>`, in which way gives better friendliness for the compiler to optimize memory access
# patterns.
#
# Let's start with the previous matrix multiplication example and demonstrate how to rewrite it to utilize block pointer
# semantics.

# %%
# Make a Block Pointer
# --------------------
# A block pointer pointers to a block in a parent tensor and is constructed by :code:`make_block_ptr` function,
# which takes the following information as arguments:
#
# * :code:`base`: the base pointer to the parent tensor;
#
# * :code:`shape`: the shape of the parent tensor;
#
# * :code:`strides`: the strides of the parent tensor, which means how much to increase the pointer by when moving by 1 element in a specific axis;
#
# * :code:`offsets`: the offsets of the block;
#
# * :code:`block_shape`: the shape of the block;
#
# * :code:`order`: the order of the block, which means how the block is laid out in memory.
#
# For example, to a block pointer to a :code:`BLOCK_SIZE_M * BLOCK_SIZE_K` block in a row-major 2D matrix A by
# offsets :code:`(pid_m * BLOCK_SIZE_M, 0)` and strides :code:`(stride_am, stride_ak)`, we can use the following code
# (exactly the same as the previous matrix multiplication tutorial):
#
# .. code-block:: python
#
#     a_block_ptr = tl.make_block_ptr(base=a_ptr, shape=(M, K), strides=(stride_am, stride_ak),
#                                     offsets=(pid_m * BLOCK_SIZE_M, 0), block_shape=(BLOCK_SIZE_M, BLOCK_SIZE_K),
#                                     order=(1, 0))
#
# Note that the :code:`order` argument is set to :code:`(1, 0)`, which means the second axis is the inner dimension in
# terms of storage, and the first axis is the outer dimension. This information may sound redundant, but it is necessary
# for some hardware backends to optimize for better performance.

# %%
# Load/Store a Block Pointer
# --------------------------
# To load/store a block pointer, we can use :code:`load/store` function, which takes a block pointer as an argument,
# de-references it, and loads/stores a block. You may mask some values in the block, here we have an extra argument
# :code:`boundary_check` to specify whether to check the boundary of each axis for the block pointer. With check on,
# out-of-bound values will be masked according to the :code:`padding_option` argument (load only), which can be
# :code:`zero` or :code:`nan`. Temporarily, we do not support other values due to some hardware limitations. In this
# mode of block pointer load/store does not support :code:`mask` or :code:`other` arguments in the legacy mode.
#
# So to load the block pointer of A in the previous section, we can simply write
# :code:`a = tl.load(a_block_ptr, boundary_check=(0, 1))`. Boundary check may cost extra performance, so if you can
# guarantee that the block pointer is always in-bound in some axis, you can turn off the check by not passing the index
# into the :code:`boundary_check` argument. For example, if we know that :code:`M` is a multiple of
# :code:`BLOCK_SIZE_M`, we can replace with :code:`a = tl.load(a_block_ptr, boundary_check=(1, ))`, since axis 0 is
# always in bound.

# %%
# Advance a Block Pointer
# -----------------------
# To advance a block pointer, we can use :code:`advance` function, which takes a block pointer and the increment for
# each axis as arguments and returns a new block pointer with the same shape and strides as the original one,
# but with the offsets advanced by the specified amount.
#
# For example, to advance the block pointer by :code:`BLOCK_SIZE_K` in the second axis
# (no need to multiply with strides), we can write :code:`a_block_ptr = tl.advance(a_block_ptr, (0, BLOCK_SIZE_K))`.

# %%
# Final Result
# ------------

import torch
import intel_extension_for_pytorch  # type: ignore # noqa: F401

import triton
import triton.language as tl

import triton_kernels_benchmark
import triton_kernels_benchmark.xetla_kernel as xetla_kernel

benchmark_suit = triton_kernels_benchmark  # triton.testing


@triton.autotune(
    configs=[
        triton.Config({'BLOCK_SIZE_M': 256, 'BLOCK_SIZE_N': 256, 'BLOCK_SIZE_K': 32, 'GROUP_SIZE_M': 4}, num_stages=2,
                      num_warps=32),
        triton.Config({'BLOCK_SIZE_M': 256, 'BLOCK_SIZE_N': 256, 'BLOCK_SIZE_K': 32, 'GROUP_SIZE_M': 4}, num_stages=3,
                      num_warps=32),
        triton.Config({'BLOCK_SIZE_M': 256, 'BLOCK_SIZE_N': 128, 'BLOCK_SIZE_K': 32, 'GROUP_SIZE_M': 4}, num_stages=2,
                      num_warps=32),
        triton.Config({'BLOCK_SIZE_M': 64, 'BLOCK_SIZE_N': 128, 'BLOCK_SIZE_K': 32, 'GROUP_SIZE_M': 4}, num_stages=2,
                      num_warps=32),
        triton.Config({'BLOCK_SIZE_M': 8, 'BLOCK_SIZE_N': 512, 'BLOCK_SIZE_K': 64, 'GROUP_SIZE_M': 1}, num_stages=2,
                      num_warps=32),
    ],
    key=['M', 'N', 'K'],
)
@triton.jit
def matmul_kernel_with_block_pointers(
        # Pointers to matrices
        a_ptr, b_ptr, c_ptr,
        # Matrix dimensions
        M: tl.constexpr, N: tl.constexpr, K: tl.constexpr,
        # The stride variables represent how much to increase the ptr by when moving by 1
        # element in a particular dimension. E.g. `stride_am` is how much to increase `a_ptr`
        # by to get the element one row down (A has M rows).
        stride_am: tl.constexpr, stride_ak: tl.constexpr,  #
        stride_bk: tl.constexpr, stride_bn: tl.constexpr,  #
        stride_cm: tl.constexpr, stride_cn: tl.constexpr,
        # Meta-parameters
        BLOCK_SIZE_M: tl.constexpr, BLOCK_SIZE_N: tl.constexpr, BLOCK_SIZE_K: tl.constexpr, GROUP_SIZE_M: tl.constexpr):
    """Kernel for computing the matmul C = A x B.
    A has shape (M, K), B has shape (K, N) and C has shape (M, N)
    """
    # -----------------------------------------------------------
    # Map program ids `pid` to the block of C it should compute.
    # This is done in a grouped ordering to promote L2 data reuse.
    # See the matrix multiplication tutorial for details.
    pid = tl.program_id(axis=0)
    num_pid_m = tl.cdiv(M, BLOCK_SIZE_M)
    num_pid_n = tl.cdiv(N, BLOCK_SIZE_N)
    num_pid_in_group = GROUP_SIZE_M * num_pid_n
    group_id = pid // num_pid_in_group
    first_pid_m = group_id * GROUP_SIZE_M
    group_size_m = min(num_pid_m - first_pid_m, GROUP_SIZE_M)
    pid_m = first_pid_m + (pid % group_size_m)
    pid_n = (pid % num_pid_in_group) // group_size_m

    # ----------------------------------------------------------
    # Create block pointers for the first blocks of A and B.
    # We will advance this pointer as we move in the K direction and accumulate.
    # See above `Make a Block Pointer` section for details.
    a_block_ptr = tl.make_block_ptr(base=a_ptr, shape=(M, K), strides=(stride_am, stride_ak),
                                    offsets=(pid_m * BLOCK_SIZE_M, 0), block_shape=(BLOCK_SIZE_M, BLOCK_SIZE_K),
                                    order=(1, 0))
    b_block_ptr = tl.make_block_ptr(base=b_ptr, shape=(K, N), strides=(stride_bk, stride_bn),
                                    offsets=(0, pid_n * BLOCK_SIZE_N), block_shape=(BLOCK_SIZE_K, BLOCK_SIZE_N),
                                    order=(1, 0))

    # -----------------------------------------------------------
    # Iterate to compute a block of the C matrix.
    # We accumulate into a `[BLOCK_SIZE_M, BLOCK_SIZE_N]` block.
    # of fp32 values for higher accuracy.
    # `accumulator` will be converted back to fp16 after the loop.
    accumulator = tl.zeros((BLOCK_SIZE_M, BLOCK_SIZE_N), dtype=tl.float32)
    for k in range(0, K, BLOCK_SIZE_K):
        # Load with boundary checks, no need to calculate the mask manually.
        # For better performance, you may remove some axis from the boundary
        # check, if you can guarantee that the access is always in-bound in
        # that axis.
        # See above `Load/Store a Block Pointer` section for details.
        a = tl.load(a_block_ptr, boundary_check=(0, 1))
        b = tl.load(b_block_ptr, boundary_check=(0, 1))
        # We accumulate along the K dimension.
        accumulator += tl.dot(a, b)
        # Advance the block pointer to the next K block.
        # See above `Advance a Block Pointer` section for details.
        a_block_ptr = tl.advance(a_block_ptr, (0, BLOCK_SIZE_K))
        b_block_ptr = tl.advance(b_block_ptr, (BLOCK_SIZE_K, 0))
    c = accumulator.to(tl.float32)
    # ----------------------------------------------------------------
    # Write back the block of the output matrix C with boundary checks.
    # See above `Load/Store a Block Pointer` section for details.
    c_block_ptr = tl.make_block_ptr(base=c_ptr, shape=(M, N), strides=(stride_cm, stride_cn),
                                    offsets=(pid_m * BLOCK_SIZE_M, pid_n * BLOCK_SIZE_N),
                                    block_shape=(BLOCK_SIZE_M, BLOCK_SIZE_N), order=(1, 0))
    tl.store(c_block_ptr, c, boundary_check=(0, 1))


@triton.autotune(
    configs=[
        triton.Config({'BLOCK_SIZE_M': 256, 'BLOCK_SIZE_N': 256, 'BLOCK_SIZE_K': 32, 'GROUP_SIZE_M': 4}, num_stages=2,
                      num_warps=32),
        triton.Config({'BLOCK_SIZE_M': 256, 'BLOCK_SIZE_N': 256, 'BLOCK_SIZE_K': 32, 'GROUP_SIZE_M': 4}, num_stages=3,
                      num_warps=32),
        triton.Config({'BLOCK_SIZE_M': 256, 'BLOCK_SIZE_N': 128, 'BLOCK_SIZE_K': 32, 'GROUP_SIZE_M': 4}, num_stages=2,
                      num_warps=32),
        triton.Config({'BLOCK_SIZE_M': 64, 'BLOCK_SIZE_N': 128, 'BLOCK_SIZE_K': 32, 'GROUP_SIZE_M': 4}, num_stages=2,
                      num_warps=32),
        triton.Config({'BLOCK_SIZE_M': 8, 'BLOCK_SIZE_N': 512, 'BLOCK_SIZE_K': 64, 'GROUP_SIZE_M': 1}, num_stages=2,
                      num_warps=32),
        triton.Config({'BLOCK_SIZE_M': 8, 'BLOCK_SIZE_N': 128, 'BLOCK_SIZE_K': 64, 'GROUP_SIZE_M': 1}, num_stages=2,
                      num_warps=4),
    ],
    key=['M', 'N', 'K'],
)
@triton.jit
def matmul_kernel_with_block_pointers_batched(
        # Pointers to matrices
        a_ptr, b_ptr, c_ptr,
        # Matrix dimensions
        B: tl.constexpr, M: tl.constexpr, N: tl.constexpr, K: tl.constexpr,
        # The stride variables represent how much to increase the ptr by when moving by 1
        # element in a particular dimension. E.g. `stride_am` is how much to increase `a_ptr`
        # by to get the element one row down (A has M rows).
        stride_az: tl.constexpr, stride_am: tl.constexpr, stride_ak: tl.constexpr,  #
        stride_bz: tl.constexpr, stride_bk: tl.constexpr, stride_bn: tl.constexpr,  #
        stride_cz: tl.constexpr, stride_cm: tl.constexpr, stride_cn: tl.constexpr,
        # Meta-parameters
        BLOCK_SIZE_M: tl.constexpr, BLOCK_SIZE_N: tl.constexpr, BLOCK_SIZE_K: tl.constexpr, GROUP_SIZE_M: tl.constexpr):
    """Kernel for computing the matmul C = A x B.
    A has shape (M, K), B has shape (K, N) and C has shape (M, N)
    """
    # -----------------------------------------------------------
    # Map program ids `pid` to the block of C it should compute.
    # This is done in a grouped ordering to promote L2 data reuse.
    # See the matrix multiplication tutorial for details.
    bid = tl.program_id(axis=0)
    pid = tl.program_id(axis=1)
    num_pid_m = tl.cdiv(M, BLOCK_SIZE_M)
    num_pid_n = tl.cdiv(N, BLOCK_SIZE_N)
    num_pid_in_group = GROUP_SIZE_M * num_pid_n
    group_id = pid // num_pid_in_group
    first_pid_m = group_id * GROUP_SIZE_M
    group_size_m = min(num_pid_m - first_pid_m, GROUP_SIZE_M)
    pid_m = first_pid_m + (pid % group_size_m)
    pid_n = (pid % num_pid_in_group) // group_size_m

    offset_a = bid.to(tl.int64) * stride_az
    offset_b = bid.to(tl.int64) * stride_bz
    # ----------------------------------------------------------
    # Create block pointers for the first blocks of A and B.
    # We will advance this pointer as we move in the K direction and accumulate.
    # See above `Make a Block Pointer` section for details.
    a_block_ptr = tl.make_block_ptr(base=a_ptr + offset_a, shape=(M, K), strides=(stride_am, stride_ak),
                                    offsets=(pid_m * BLOCK_SIZE_M, 0), block_shape=(BLOCK_SIZE_M, BLOCK_SIZE_K),
                                    order=(1, 0))
    b_block_ptr = tl.make_block_ptr(base=b_ptr + offset_b, shape=(K, N), strides=(stride_bk, stride_bn),
                                    offsets=(0, pid_n * BLOCK_SIZE_N), block_shape=(BLOCK_SIZE_K, BLOCK_SIZE_N),
                                    order=(1, 0))

    # -----------------------------------------------------------
    # Iterate to compute a block of the C matrix.
    # We accumulate into a `[BLOCK_SIZE_M, BLOCK_SIZE_N]` block.
    # of fp32 values for higher accuracy.
    # `accumulator` will be converted back to fp16 after the loop.
    accumulator = tl.zeros((BLOCK_SIZE_M, BLOCK_SIZE_N), dtype=tl.float32)
    for k in range(0, K, BLOCK_SIZE_K):
        # Load with boundary checks, no need to calculate the mask manually.
        # For better performance, you may remove some axis from the boundary
        # check, if you can guarantee that the access is always in-bound in
        # that axis.
        # See above `Load/Store a Block Pointer` section for details.
        a = tl.load(a_block_ptr, boundary_check=(0, 1))
        b = tl.load(b_block_ptr, boundary_check=(0, 1))
        # We accumulate along the K dimension.
        accumulator += tl.dot(a, b)
        # Advance the block pointer to the next K block.
        # See above `Advance a Block Pointer` section for details.
        a_block_ptr = tl.advance(a_block_ptr, (0, BLOCK_SIZE_K))
        b_block_ptr = tl.advance(b_block_ptr, (BLOCK_SIZE_K, 0))
    c = accumulator.to(tl.float32)
    # ----------------------------------------------------------------
    # Write back the block of the output matrix C with boundary checks.
    # See above `Load/Store a Block Pointer` section for details.
    offset_c = bid.to(tl.int64) * stride_cz
    c_block_ptr = tl.make_block_ptr(base=c_ptr + offset_c, shape=(M, N), strides=(stride_cm, stride_cn),
                                    offsets=(pid_m * BLOCK_SIZE_M, pid_n * BLOCK_SIZE_N),
                                    block_shape=(BLOCK_SIZE_M, BLOCK_SIZE_N), order=(1, 0))
    tl.store(c_block_ptr, c, boundary_check=(0, 1))


# We can now create a convenience wrapper function that only takes two input tensors,
# and (1) checks any shape constraint; (2) allocates the output; (3) launches the above kernel.
def matmul(a, b):
    # Check constraints.
    if len(a.shape) == 3 and len(b.shape) == 3:
        assert a.shape[0] == b.shape[0], "Incompatible Batch dimension"
        assert a.shape[2] == b.shape[1], "Incompatible dimensions"
        assert a.is_contiguous(), "Matrix A must be contiguous"
        assert b.is_contiguous(), "Matrix B must be contiguous"
        B, M, K = a.shape
        B, K, N = b.shape
        # Allocates output.
        c = torch.empty((B, M, N), device=a.device, dtype=torch.float32)
        # 1D launch kernel where each block gets its own program.
        grid = lambda META: (
            B,
            triton.cdiv(M, META['BLOCK_SIZE_M']) * triton.cdiv(N, META['BLOCK_SIZE_N']),
        )
        matmul_kernel_with_block_pointers_batched[grid](
            a, b, c,  #
            B, M, N, K,  #
            a.stride(0), a.stride(1), a.stride(2),  #
            b.stride(0), b.stride(1), b.stride(2),  #
            c.stride(0), c.stride(1), c.stride(2),  #
            threads_per_warp=16)
    elif len(a.shape) == 2 and len(b.shape) == 2:
        assert a.shape[1] == b.shape[0], "Incompatible dimensions"
        assert a.is_contiguous(), "Matrix A must be contiguous"
        assert b.is_contiguous(), "Matrix B must be contiguous"
        M, K = a.shape
        K, N = b.shape
        # Allocates output.
        c = torch.empty((M, N), device=a.device, dtype=torch.float32)
        grid = lambda META: (triton.cdiv(M, META['BLOCK_SIZE_M']) * triton.cdiv(N, META['BLOCK_SIZE_N']), )
        matmul_kernel_with_block_pointers[grid](
            a, b, c,  #
            M, N, K,  #
            a.stride(0), a.stride(1),  #
            b.stride(0), b.stride(1),  #
            c.stride(0), c.stride(1),  #
            threads_per_warp=16)
    else:
        assert False, "Input matrixs dimensions mismatch"
    return c


# Benchmark Performance
@benchmark_suit.perf_report(
    benchmark_suit.Benchmark(
        # argument names to use as an x-axis for the plot
        x_names=['B', 'M', 'K', 'N'],
        # different possible values for `x_name`
        x_vals=[[1, 1024 * i, 1024 * i, 1024 * i] for i in [1, 2, 4, 8]] +  #
        [[1, 1, 5120, 13824],  #
         [1, 4, 4096, 12288],  #
         [1, 512, 8192, 8192],  #
         [1, 512, 8192, 32768],  #
         [1, 512, 32768, 8192],  #
         [1, 1024, 16384, 8192],  #
         [1, 1024, 28672, 8192],  #
         [1, 3072, 4096, 3072],  #
         [1, 4096, 16384, 8192],  #
         [1, 8192, 16384, 1024],  #
         [1, 8192, 16384, 4096],  #
         [1, 16384, 1024, 8192],  #
         [1, 16384, 4096, 8192],  #
         [1, 16384, 8192, 1024],  #
         [1, 16384, 8192, 4096],  #
         [4, 32768, 128, 4096],  #
         [4, 32768, 4096, 128],  #
         [32, 4096, 4096, 128],  #
         [4096, 8, 128, 16384],  #
         [4096, 8, 16384, 128]],
        line_arg='provider',
        # argument name whose value corresponds to a different line in the plot
        # possible values for `line_arg``
        line_vals=['triton', 'xetla'],
        # label name for the lines
        line_names=["Triton", "XeTLA"],
        # line styles
        styles=[('green', '-'), ('green', '--'), ('blue', '-'), ('blue', '--')],
        ylabel=["GB/s", "TFlops"],  # label name for the y-axis
        plot_name="matmul-performance",
        # name for the plot. Used also as a file name for saving the plot.
        args={},
    ))
def benchmark(B, M, N, K, provider):
    if B == 1:
        a = torch.rand((M, K), device='xpu', dtype=torch.bfloat16)
        b = torch.rand((K, N), device='xpu', dtype=torch.bfloat16)
    else:
        a = torch.rand((B, M, K), device='xpu', dtype=torch.bfloat16)
        b = torch.rand((B, K, N), device='xpu', dtype=torch.bfloat16)

    quantiles = [0.5, 0.0, 1.0]

    if provider == 'onednn':
        ms, min_ms, max_ms, mean, cv = benchmark_suit.do_bench(lambda: torch.matmul(a, b), warmup=100, rep=100,
                                                               quantiles=quantiles, fast_flush=False)
    if provider == 'triton':
        triton_fn = lambda: matmul(a, b)
        torch_fn = lambda: torch.matmul(a, b).to(torch.float32)
        rtol = 1e-2 if a.dtype == torch.bfloat16 else 1e-3
        benchmark_suit.assert_close(triton_fn(), torch_fn(), atol=1e-4, rtol=rtol, err_msg="triton to torch")
        ms, min_ms, max_ms, mean, cv = benchmark_suit.do_bench(triton_fn, warmup=100, rep=100, quantiles=quantiles,
                                                               fast_flush=False)
    if provider == 'xetla':
        if B == 1:
            c = torch.empty((M, N), device='xpu', dtype=torch.float32)
            acc = torch.empty((M, N), device='xpu', dtype=torch.float32)
            cnt = torch.empty((M, N), device='xpu', dtype=torch.int32)
        else:
            c = torch.empty((B, M, N), device='xpu', dtype=torch.float32)
            acc = torch.empty((B, M, N), device='xpu', dtype=torch.float32)
            cnt = torch.empty((B, M, N), device='xpu', dtype=torch.int32)
        name = "gemm_shape_{}_{}_{}_{}".format(B, M, K, N)
        func = getattr(xetla_kernel, name)
        xetla_fn = lambda: func(a, b, c, acc, cnt)
        torch_fn = lambda: torch.matmul(a, b).to(torch.float32)
        rtol = 1e-2 if a.dtype == torch.bfloat16 else 1e-3
        # FIXME: XeTLA batch GEMM implemention
        benchmark_suit.assert_close(xetla_fn(), torch_fn(), atol=1e-4, rtol=1.0, err_msg="xetla to torch")
        ms, min_ms, max_ms, mean, cv = benchmark_suit.do_bench(xetla_fn, warmup=100, rep=100, quantiles=quantiles,
                                                               fast_flush=False)

    tflops = lambda mean: 2 * B * M * N * K * (1e-12) / (mean * 1e-3)
    gbps = lambda mean: B * (2 * (M * K + K * N) + 4.0 * (M * N)) * (1e-9) / (mean * 1e-3)

    return (gbps(mean), gbps(max_ms), gbps(min_ms)), (tflops(mean), tflops(max_ms), tflops(min_ms)), cv


if __name__ == "__main__":
    benchmark.run(show_plots=False, print_data=True)
