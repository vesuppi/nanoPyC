import torch
import torch.utils.benchmark as torchbench
import compiler

@compiler.jit
def my_exp(a):
    b = torch.exp(a)
    return b

def torch_exp(a):
    b = torch.exp(a)
    return b

def bench(fn):
    t0 = torchbench.Timer(
        stmt='fn()',
        globals={'fn': fn},
        num_threads=torch.get_num_threads()
    )
    return t0.timeit(20).mean * 1000

for shape in [(10240, 2048), (102400, 2048)]:
    M, N = shape
    a = torch.randn(M, N, device='cuda', dtype=torch.float32)
    a_cpu = a.cpu()
    b_torch = torch_exp(a)
    b_my = my_exp(a)
    print('allclose:', torch.allclose(b_my, b_torch))
    print('torch runtime:', bench(lambda: torch_exp(a)), 'ms')
    print('torch (cpu) runtime:', bench(lambda: torch_exp(a_cpu)), 'ms')
    print('  our runtime:', bench(lambda: my_exp(a)), 'ms')
