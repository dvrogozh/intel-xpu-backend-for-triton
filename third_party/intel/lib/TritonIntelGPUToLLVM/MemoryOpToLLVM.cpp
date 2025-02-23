#include "PatternTritonGPUOpToLLVM.h"
#include "Utility.h"

namespace {

using namespace mlir;
using namespace mlir::triton;
using namespace mlir::triton::gpu;

// blocked -> shared.
// Swizzling in shared memory to avoid bank conflict. Normally used for
// A/B operands of dots.
void lowerDistributedToShared(LocalAllocOp op, LocalAllocOpAdaptor adaptor,
                              const LLVMTypeConverter *typeConverter,
                              ConversionPatternRewriter &rewriter,
                              const TargetInfoBase &targetInfo) {
  auto loc = op.getLoc();
  auto srcTy = op.getSrc().getType();
  auto dstTy = op.getType();
  auto dstShapePerCTA = triton::gpu::getShapePerCTA(dstTy);
  auto srcLayout = srcTy.getEncoding();
  auto outOrd = cast<SharedEncodingAttr>(dstTy.getEncoding()).getOrder();
  assert(srcTy.getShape().size() == 2 ||
         (srcTy.getShape().size() <= 3 && outOrd[2] == 0) &&
             "Unexpected rank of ConvertLayout(blocked->shared)");
  Value smemBase =
      LLVM::intel::getSharedMemoryBase(loc, rewriter, op.getOperation());
  auto elemTy = typeConverter->convertType(srcTy.getElementType());

  int32_t elemSize = elemTy.getIntOrFloatBitWidth();
  auto mmaLayout = dyn_cast<DpasEncodingAttr>(srcLayout);
  unsigned numElems = triton::gpu::getTotalElemsPerThread(srcTy);
  auto dstStrides =
      LLVM::getStridesFromShapeAndOrder(dstShapePerCTA, outOrd, loc, rewriter);
  auto srcIndices = ::mlir::triton::intel::emitIndices(
      loc, rewriter, targetInfo, srcLayout, srcTy, false);
  auto inVals = unpackLLElements(loc, adaptor.getSrc(), rewriter);
  mlir::triton::intel::storeDistributedToShared(
      op.getSrc(), inVals, dstStrides, op.getResult(), smemBase, elemTy, loc,
      rewriter, targetInfo);
}

struct LocalAllocOpConversion
    : public ConvertTritonGPUOpToLLVMPattern<triton::gpu::LocalAllocOp> {
  LocalAllocOpConversion(const LLVMTypeConverter &converter,
                         const TargetInfoBase &targetInfo,
                         PatternBenefit benefit = 1)
      : ConvertTritonGPUOpToLLVMPattern<triton::gpu::LocalAllocOp>(converter,
                                                                   benefit),
        targetInfo(targetInfo) {}

  LogicalResult
  matchAndRewrite(triton::gpu::LocalAllocOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    if (!op.isSharedMemoryAlloc())
      return failure();
    Location loc = op->getLoc();
    Value smemBase =
        LLVM::intel::getSharedMemoryBase(loc, rewriter, op.getOperation());
    auto resultTy = cast<MemDescType>(op.getType());
    auto typeConverter = getTypeConverter();
    auto sharedLayout =
        cast<triton::gpu::SharedEncodingAttr>(resultTy.getEncoding());
    auto order = sharedLayout.getOrder();
    // Workaround for 3D tensors
    // TODO: we need to modify the pipeline pass to give a proper shared
    // encoding to 3D tensors
    SmallVector<unsigned> newOrder;
    if (resultTy.getShape().size() != order.size()) {
      for (auto i = 0; i < order.size(); ++i)
        newOrder.push_back(order[i] + 1);
      newOrder.push_back(0);
    } else {
      newOrder = SmallVector<unsigned>(order.begin(), order.end());
    }

    // If there is an initial tensor, store it into the shared memory.
    if (op.getSrc()) {
      lowerDistributedToShared(op, adaptor, typeConverter, rewriter,
                               targetInfo);
    }

    auto llvmElemTy = typeConverter->convertType(resultTy.getElementType());
    auto shapePerCTA = getShapePerCTA(sharedLayout, resultTy.getShape());
    auto smemObj = SharedMemoryObject(smemBase, llvmElemTy, shapePerCTA,
                                      newOrder, loc, rewriter);
    auto retVal = getStructFromSharedMemoryObject(loc, smemObj, rewriter);
    rewriter.replaceOp(op, retVal);
    return success();
  }

private:
  const TargetInfoBase &targetInfo;
};

struct LocalDeallocOpConversion
    : public ConvertTritonGPUOpToLLVMPattern<triton::gpu::LocalDeallocOp> {
  using ConvertTritonGPUOpToLLVMPattern<
      triton::gpu::LocalDeallocOp>::ConvertTritonGPUOpToLLVMPattern;

  LogicalResult
  matchAndRewrite(triton::gpu::LocalDeallocOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    rewriter.eraseOp(op);
    return success();
  }
};

} // namespace

void mlir::triton::intel::populateMemoryOpToLLVMPattern(
    LLVMTypeConverter &typeConverter, const TargetInfoBase &targetInfo,
    RewritePatternSet &patterns, PatternBenefit benefit) {
  patterns.add<LocalAllocOpConversion>(typeConverter, targetInfo, benefit);
  patterns.add<LocalDeallocOpConversion>(typeConverter, benefit);
}
