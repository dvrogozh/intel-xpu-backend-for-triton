add_triton_library(TritonIntelGPUToLLVM
    AllocateSharedMemory.cpp
    BF16Casts.cpp
    ControlFlowOpToLLVM.cpp
    ConvertLayoutOpToLLVM/SharedToDotOperandDPAS.cpp
    ConvertLayoutOpToLLVM.cpp
    DecomposeUnsupportedConversions.cpp
    DotOpToLLVM/DPAS.cpp
    DotOpToLLVM/FMA.cpp
    DotOpToLLVM.cpp
    ElementwiseOpToLLVM.cpp
    HistogramOpToLLVM.cpp
    LoadStoreOpToLLVM.cpp
    MakeRangeOpToLLVM.cpp
    MemoryOpToLLVM.cpp
    PrintOpToLLVM.cpp
    ReduceOpToLLVM.cpp
    TritonGPUToLLVM.cpp
    ScanOpToLLVM.cpp
    SPMDOpToLLVM.cpp
    TargetInfo.cpp
    TensorPtrOpsToLLVM.cpp
    TritonGPUToLLVM.cpp
    TritonOpsToLLVM.cpp
    TypeConverter.cpp
    Utility.cpp
    ViewOpToLLVM.cpp

    DEPENDS
    TritonIntelGPUConversionPassIncGen

    LINK_LIBS PUBLIC
    GPUToTritonGEN
    TritonGENIR
    TritonGENToLLVM
    TritonIntelGPUIR
    TritonIntelUtils
)
