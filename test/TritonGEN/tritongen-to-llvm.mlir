// RUN: triton-opt -convert-tritongen-to-llvm -split-input-file %s | FileCheck %s

// CHECK-DAG: llvm.func spir_funccc @_Z25__spirv_BuiltInSubgroupIdv() -> i32
// CHECK-DAG: llvm.func spir_funccc @_Z14get_num_groupsj(i32) -> i64 attributes {passthrough = ["nounwind", "willreturn", ["memory", "0"]]}
// CHECK-DAG: llvm.func spir_funccc @_Z14get_local_sizej(i32) -> i64 attributes {passthrough = ["nounwind", "willreturn", ["memory", "0"]]}
// CHECK-DAG: llvm.func spir_funccc @_Z12get_group_idj(i32) -> i64 attributes {passthrough = ["nounwind", "willreturn", ["memory", "0"]]}
// CHECK-DAG: llvm.func spir_funccc @_Z12get_local_idj(i32) -> i64 attributes {passthrough = ["nounwind", "willreturn", ["memory", "0"]]}

llvm.func @gen_special_regs() -> i32 {
  // CHECK-LABEL: gen_special_regs
  // CHECK: [[ZERO:%.*]] = llvm.mlir.constant(0 : i32) : i32
  // CHECK: [[CI:%.*]] = llvm.call spir_funccc @_Z12get_local_idj([[ZERO]]) {{.*}} : (i32) -> i64
  // CHECK-NEXT: llvm.trunc [[CI]] : i64 to i32
  %1 = triton_gen.workitem.id.x : i32
  // CHECK: [[ONE:%.*]] = llvm.mlir.constant(1 : i32) : i32
  // CHECK: llvm.call spir_funccc @_Z12get_local_idj([[ONE]]) {{.*}} : (i32) -> i64
  %2 = triton_gen.workitem.id.y : i32
  // CHECK: [[TWO:%.*]] = llvm.mlir.constant(2 : i32) : i32
  // CHECK: llvm.call spir_funccc @_Z12get_local_idj([[TWO]]) {{.*}} : (i32) -> i64
  %3 = triton_gen.workitem.id.z : i64

  // CHECK: [[ZERO1:%.*]] = llvm.mlir.constant(0 : i32) : i32
  // CHECK: llvm.call spir_funccc @_Z12get_group_idj([[ZERO1]]) {{.*}} : (i32) -> i64
  %4 = triton_gen.workgroup.id.x : i32
  // CHECK: [[ONE1:%.*]] = llvm.mlir.constant(1 : i32) : i32
  // CHECK: llvm.call spir_funccc @_Z12get_group_idj([[ONE1]]) {{.*}} : (i32) -> i64
  %5 = triton_gen.workgroup.id.y : i64
  // CHECK: [[TWO1:%.*]] = llvm.mlir.constant(2 : i32) : i32
  // CHECK: llvm.call spir_funccc @_Z12get_group_idj([[TWO1]]) {{.*}} : (i32) -> i64
  %6 = triton_gen.workgroup.id.z : i32

  // CHECK: [[ZERO2:%.*]] = llvm.mlir.constant(0 : i32) : i32
  // CHECK: llvm.call spir_funccc @_Z14get_local_sizej([[ZERO2]]) {{.*}} : (i32) -> i64
  %7 = triton_gen.workgroup.dim.x : i32
  // CHECK: [[ONE2:%.*]] = llvm.mlir.constant(1 : i32) : i32
  // CHECK: llvm.call spir_funccc @_Z14get_local_sizej([[ONE2]]) {{.*}} : (i32) -> i64
  %8 = triton_gen.workgroup.dim.y : i64
  // CHECK: [[TWO2:%.*]] = llvm.mlir.constant(2 : i32) : i32
  // CHECK: llvm.call spir_funccc @_Z14get_local_sizej([[TWO2]]) {{.*}} : (i32) -> i64
  %9 = triton_gen.workgroup.dim.z : i32

  // CHECK: [[ZERO3:%.*]] = llvm.mlir.constant(0 : i32) : i32
  // CHECK: llvm.call spir_funccc @_Z14get_num_groupsj([[ZERO3]]) {{.*}} : (i32) -> i64
  %10 = triton_gen.grid.dim.x : i32
  // CHECK: [[ONE3:%.*]] = llvm.mlir.constant(1 : i32) : i32
  // CHECK: llvm.call spir_funccc @_Z14get_num_groupsj([[ONE3]]) {{.*}} : (i32) -> i64
  %11 = triton_gen.grid.dim.y : i64
  // CHECK: [[TWO3:%.*]] = llvm.mlir.constant(2 : i32) : i32
  // CHECK: llvm.call spir_funccc @_Z14get_num_groupsj([[TWO3]]) {{.*}} : (i32) -> i64
  %12 = triton_gen.grid.dim.z : i32

  // CHECK: llvm.call spir_funccc @_Z25__spirv_BuiltInSubgroupIdv() {{.*}} : () -> i32
  %13 = triton_gen.subgroup.id : i32

  llvm.return %1 : i32
}

// -----

// CHECK: llvm.func spir_funccc @_Z7barrierj(i32) attributes {passthrough = ["convergent"]}

llvm.func @triton_gen.barrier() {
  // CHECK-LABEL: triton_gen.barrier
  // CHECK: [[CST:%.*]] = llvm.mlir.constant(1 : i32) : i32
  // CHECK: llvm.call spir_funccc @_Z7barrierj([[CST]]) {{.*}} : (i32) -> ()
  triton_gen.barrier
  llvm.return
}

// -----

// CHECK-DAG: llvm.func spir_funccc @_Z31intel_work_group_barrier_arriveii(i32, i32) attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z29intel_work_group_barrier_waitii(i32, i32) attributes {passthrough = ["convergent"]}

llvm.func @triton_gen.split_barrier() {
  // CHECK-LABEL: triton_gen.split_barrier() {
  // CHECK-DAG: [[ZERO:%.*]] = llvm.mlir.constant(0 : i32) : i32
  // CHECK-DAG: [[ONE:%.*]] = llvm.mlir.constant(1 : i32) : i32
  // CHECK:     llvm.call spir_funccc @_Z31intel_work_group_barrier_arriveii([[ZERO]], [[ONE]]) {{.*}} : (i32, i32) -> ()
  // CHECK-DAG: [[ZERO:%.*]] = llvm.mlir.constant(0 : i32) : i32
  // CHECK-DAG: [[ONE:%.*]] = llvm.mlir.constant(1 : i32) : i32
  // CHECK:     llvm.call spir_funccc @_Z29intel_work_group_barrier_waitii([[ZERO]], [[ONE]]) {{.*}} : (i32, i32) -> ()
  triton_gen.split_barrier_signal {mem_fence=None, mem_scope=WorkGroup}
  triton_gen.split_barrier_wait {mem_fence=None, mem_scope=WorkGroup}
  llvm.return
}

// -----

// CHECK-DAG: llvm.func spir_funccc @llvm.genx.GenISA.threadgroupnamedbarriers.signal.i32.i32(i32, i32) attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @llvm.genx.GenISA.threadgroupnamedbarriers.wait.i32(i32) attributes {passthrough = ["convergent"]}

llvm.func @triton_gen.named_barrier(%barrier_id : i32, %thread_group_count : i32) {
  // CHECK-LABEL: triton_gen.named_barrier(%arg0: i32, %arg1: i32) {
  // CHECK:       llvm.call spir_funccc @llvm.genx.GenISA.threadgroupnamedbarriers.signal.i32.i32(%arg0, %arg1) {{.*}} : (i32, i32) -> ()
  // CHECK-NEXT:  llvm.call spir_funccc @llvm.genx.GenISA.threadgroupnamedbarriers.wait.i32(%arg0) {{.*}} : (i32) -> ()
  triton_gen.named_barrier_signal %barrier_id, %thread_group_count : (i32, i32)
  triton_gen.named_barrier_wait %barrier_id : i32
  llvm.return
}

// -----

// CHECK-DAG: llvm.func spir_funccc @_Z30sub_group_clustered_reduce_addij(i32, i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z30sub_group_clustered_reduce_mulij(i32, i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z30sub_group_clustered_reduce_maxij(i32, i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z30sub_group_clustered_reduce_minij(i32, i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z30sub_group_clustered_reduce_andij(i32, i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z29sub_group_clustered_reduce_orij(i32, i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z30sub_group_clustered_reduce_xorij(i32, i32) -> i32 attributes {passthrough = ["convergent"]}

module attributes {
  spirv.target_env = #spirv.target_env<#spirv.vce<v1.4, [Kernel, Addresses, GroupNonUniformShuffle, Int64], []>, #spirv.resource_limits<subgroup_size = 32>>
} {
  llvm.func @triton_gen.sub_group_reduce() {
    %0 = llvm.mlir.constant(0 : i32) : i32
    // CHECK: [[VAL:%.*]] = llvm.mlir.constant(0 : i32) : i32
    // CHECK: [[SIZE:%.*]] = llvm.mlir.constant(16 : i32) : i32
    // CHECK: llvm.call spir_funccc @_Z30sub_group_clustered_reduce_addij([[VAL]], [[SIZE]]) {{.*}} : (i32, i32) -> i32
    %1 = triton_gen.sub_group_reduce add %0 {size = 16} : i32
    // CHECK: [[SIZE:%.*]] = llvm.mlir.constant(16 : i32) : i32
    // CHECK: llvm.call spir_funccc @_Z30sub_group_clustered_reduce_mulij([[VAL]], [[SIZE]]) {{.*}} : (i32, i32) -> i32
    %2 = triton_gen.sub_group_reduce mul %0 {size = 16} : i32
    // CHECK: [[SIZE:%.*]] = llvm.mlir.constant(16 : i32) : i32
    // CHECK: llvm.call spir_funccc @_Z30sub_group_clustered_reduce_minij([[VAL]], [[SIZE]]) {{.*}} : (i32, i32) -> i32
    %3 = triton_gen.sub_group_reduce min %0 {size = 16} : i32
    // CHECK: [[SIZE:%.*]] = llvm.mlir.constant(16 : i32) : i32
    // CHECK: llvm.call spir_funccc @_Z30sub_group_clustered_reduce_maxij([[VAL]], [[SIZE]]) {{.*}} : (i32, i32) -> i32
    %4 = triton_gen.sub_group_reduce max %0 {size = 16} : i32
    // CHECK: [[SIZE:%.*]] = llvm.mlir.constant(16 : i32) : i32
    // CHECK: llvm.call spir_funccc @_Z30sub_group_clustered_reduce_andij([[VAL]], [[SIZE]]) {{.*}} : (i32, i32) -> i32
    %5 = triton_gen.sub_group_reduce and %0 {size = 16} : i32
    // CHECK: [[SIZE:%.*]] = llvm.mlir.constant(16 : i32) : i32
    // CHECK: llvm.call spir_funccc @_Z29sub_group_clustered_reduce_orij([[VAL]], [[SIZE]]) {{.*}} : (i32, i32) -> i32
    %6 = triton_gen.sub_group_reduce or %0 {size = 16} : i32
    // CHECK: [[SIZE:%.*]] = llvm.mlir.constant(16 : i32) : i32
    // CHECK: llvm.call spir_funccc @_Z30sub_group_clustered_reduce_xorij([[VAL]], [[SIZE]]) {{.*}} : (i32, i32) -> i32
    %7 = triton_gen.sub_group_reduce xor %0 {size = 16} : i32
    llvm.return
  }
}

// -----

// CHECK-DAG: llvm.func spir_funccc @_Z32sub_group_non_uniform_reduce_addi(i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z32sub_group_non_uniform_reduce_muli(i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z32sub_group_non_uniform_reduce_mini(i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z32sub_group_non_uniform_reduce_maxi(i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z32sub_group_non_uniform_reduce_andi(i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z31sub_group_non_uniform_reduce_ori(i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z32sub_group_non_uniform_reduce_xori(i32) -> i32 attributes {passthrough = ["convergent"]}

module attributes {
  spirv.target_env = #spirv.target_env<#spirv.vce<v1.4, [Kernel, Addresses, GroupNonUniformShuffle, Int64], []>, #spirv.resource_limits<subgroup_size = 16>>
} {
  llvm.func @triton_gen.sub_group_reduce() {
    %0 = llvm.mlir.constant(0 : i32) : i32
    // CHECK: [[VAL:%.*]] = llvm.mlir.constant(0 : i32) : i32
    // CHECK: llvm.call spir_funccc @_Z32sub_group_non_uniform_reduce_addi([[VAL]]) {{.*}} : (i32) -> i32
    %1 = triton_gen.sub_group_reduce add %0 {size = 16} : i32
    // CHECK: llvm.call spir_funccc @_Z32sub_group_non_uniform_reduce_muli([[VAL]]) {{.*}} : (i32) -> i32
    %2 = triton_gen.sub_group_reduce mul %0 {size = 16} : i32
    // CHECK: llvm.call spir_funccc @_Z32sub_group_non_uniform_reduce_mini([[VAL]]) {{.*}} : (i32) -> i32
    %3 = triton_gen.sub_group_reduce min %0 {size = 16} : i32
    // CHECK: llvm.call spir_funccc @_Z32sub_group_non_uniform_reduce_maxi([[VAL]]) {{.*}} : (i32) -> i32
    %4 = triton_gen.sub_group_reduce max %0 {size = 16} : i32
    // CHECK: llvm.call spir_funccc @_Z32sub_group_non_uniform_reduce_andi([[VAL]]) {{.*}} : (i32) -> i32
    %5 = triton_gen.sub_group_reduce and %0 {size = 16} : i32
    // CHECK: llvm.call spir_funccc @_Z31sub_group_non_uniform_reduce_ori([[VAL]]) {{.*}} : (i32) -> i32
    %6 = triton_gen.sub_group_reduce or %0 {size = 16} : i32
    // CHECK: llvm.call spir_funccc @_Z32sub_group_non_uniform_reduce_xori([[VAL]]) {{.*}} : (i32) -> i32
    %7 = triton_gen.sub_group_reduce xor %0 {size = 16} : i32
    llvm.return
  }
}

// -----

// CHECK-DAG: llvm.func spir_funccc @_Z40sub_group_non_uniform_scan_exclusive_addi(i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z40sub_group_non_uniform_scan_exclusive_muli(i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z40sub_group_non_uniform_scan_exclusive_maxi(i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z40sub_group_non_uniform_scan_exclusive_mini(i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z40sub_group_non_uniform_scan_exclusive_andi(i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z39sub_group_non_uniform_scan_exclusive_ori(i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z40sub_group_non_uniform_scan_exclusive_xori(i32) -> i32 attributes {passthrough = ["convergent"]}

// CHECK-DAG: llvm.func spir_funccc @_Z40sub_group_non_uniform_scan_inclusive_addi(i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z40sub_group_non_uniform_scan_inclusive_muli(i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z40sub_group_non_uniform_scan_inclusive_maxi(i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z40sub_group_non_uniform_scan_inclusive_mini(i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z40sub_group_non_uniform_scan_inclusive_andi(i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z39sub_group_non_uniform_scan_inclusive_ori(i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z40sub_group_non_uniform_scan_inclusive_xori(i32) -> i32 attributes {passthrough = ["convergent"]}

module attributes {
  spirv.target_env = #spirv.target_env<#spirv.vce<v1.4, [Kernel, Addresses, GroupNonUniformShuffle, Int64], []>, #spirv.resource_limits<subgroup_size = 16>>
} {
  llvm.func @triton_gen.sub_group_scan() {
    %0 = llvm.mlir.constant(0 : i32) : i32
    // CHECK: [[VAL:%.*]] = llvm.mlir.constant(0 : i32) : i32
    // CHECK: llvm.call spir_funccc @_Z40sub_group_non_uniform_scan_exclusive_addi([[VAL]]) {{.*}} : (i32) -> i32
    %1 = triton_gen.sub_group_scan add %0 {kind = exclusive} : i32
    // CHECK: llvm.call spir_funccc @_Z40sub_group_non_uniform_scan_exclusive_muli([[VAL]]) {{.*}} : (i32) -> i32
    %2 = triton_gen.sub_group_scan mul %0 {kind = exclusive} : i32
    // CHECK: llvm.call spir_funccc @_Z40sub_group_non_uniform_scan_exclusive_mini([[VAL]]) {{.*}} : (i32) -> i32
    %3 = triton_gen.sub_group_scan min %0 {kind = exclusive} : i32
    // CHECK: llvm.call spir_funccc @_Z40sub_group_non_uniform_scan_exclusive_maxi([[VAL]]) {{.*}} : (i32) -> i32
    %4 = triton_gen.sub_group_scan max %0 {kind = exclusive} : i32
    // CHECK: llvm.call spir_funccc @_Z40sub_group_non_uniform_scan_exclusive_andi([[VAL]]) {{.*}} : (i32) -> i32
    %5 = triton_gen.sub_group_scan and %0 {kind = exclusive} : i32
    // CHECK: llvm.call spir_funccc @_Z39sub_group_non_uniform_scan_exclusive_ori([[VAL]]) {{.*}} : (i32) -> i32
    %6 = triton_gen.sub_group_scan or %0 {kind = exclusive} : i32
    // CHECK: llvm.call spir_funccc @_Z40sub_group_non_uniform_scan_exclusive_xori([[VAL]]) {{.*}} : (i32) -> i32
    %7 = triton_gen.sub_group_scan xor %0 {kind = exclusive} : i32

    // CHECK: llvm.call spir_funccc @_Z40sub_group_non_uniform_scan_inclusive_addi([[VAL]]) {{.*}} : (i32) -> i32
    %8 = triton_gen.sub_group_scan add %0 {kind = inclusive} : i32
    // CHECK: llvm.call spir_funccc @_Z40sub_group_non_uniform_scan_inclusive_muli([[VAL]]) {{.*}} : (i32) -> i32
    %9 = triton_gen.sub_group_scan mul %0 {kind = inclusive} : i32
    // CHECK: llvm.call spir_funccc @_Z40sub_group_non_uniform_scan_inclusive_mini([[VAL]]) {{.*}} : (i32) -> i32
    %10 = triton_gen.sub_group_scan min %0 {kind = inclusive} : i32
    // CHECK: llvm.call spir_funccc @_Z40sub_group_non_uniform_scan_inclusive_maxi([[VAL]]) {{.*}} : (i32) -> i32
    %11 = triton_gen.sub_group_scan max %0 {kind = inclusive} : i32
    // CHECK: llvm.call spir_funccc @_Z40sub_group_non_uniform_scan_inclusive_andi([[VAL]]) {{.*}} : (i32) -> i32
    %12 = triton_gen.sub_group_scan and %0 {kind = inclusive} : i32
    // CHECK: llvm.call spir_funccc @_Z39sub_group_non_uniform_scan_inclusive_ori([[VAL]]) {{.*}} : (i32) -> i32
    %13 = triton_gen.sub_group_scan or %0 {kind = inclusive} : i32
    // CHECK: llvm.call spir_funccc @_Z40sub_group_non_uniform_scan_inclusive_xori([[VAL]]) {{.*}} : (i32) -> i32
    %14 = triton_gen.sub_group_scan xor %0 {kind = inclusive} : i32

    llvm.return
  }
}

// -----

// CHECK-DAG: llvm.func spir_funccc @_Z21sub_group_shuffle_xordj(f64, i32) -> f64 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z21sub_group_shuffle_xorfj(f32, i32) -> f32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z21sub_group_shuffle_xorDhj(f16, i32) -> f16 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z21sub_group_shuffle_xorlj(i64, i32) -> i64 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z21sub_group_shuffle_xorsj(i16, i32) -> i16 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z21sub_group_shuffle_xorcj(i8, i32) -> i8 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z17sub_group_shuffleij(i32, i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z22sub_group_shuffle_downij(i32, i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z20sub_group_shuffle_upij(i32, i32) -> i32 attributes {passthrough = ["convergent"]}
// CHECK-DAG: llvm.func spir_funccc @_Z21sub_group_shuffle_xorij(i32, i32) -> i32 attributes {passthrough = ["convergent"]}

llvm.func @triton_gen.sub_group_shuffle() {
  // CHECK-LABEL: triton_gen.sub_group_shuffle
  %0 = llvm.mlir.constant(0 : i32) : i32
  // CHECK: [[ZERO:%.*]] = llvm.mlir.constant(0 : i32) : i32
  // CHECK: llvm.call spir_funccc @_Z21sub_group_shuffle_xorij([[ZERO]], [[ZERO]]) {{.*}} : (i32, i32) -> i32
  // CHECK: llvm.call spir_funccc @_Z20sub_group_shuffle_upij([[ZERO]], [[ZERO]]) {{.*}} : (i32, i32) -> i32
  // CHECK: llvm.call spir_funccc @_Z22sub_group_shuffle_downij([[ZERO]], [[ZERO]]) {{.*}} : (i32, i32) -> i32
  // CHECK: llvm.call spir_funccc @_Z17sub_group_shuffleij([[ZERO]], [[ZERO]]) {{.*}} : (i32, i32) -> i32
  %1 = triton_gen.sub_group_shuffle xor %0, %0 : i32
  %2 = triton_gen.sub_group_shuffle up %0, %0 : i32
  %3 = triton_gen.sub_group_shuffle down %0, %0 : i32
  %4 = triton_gen.sub_group_shuffle idx %0, %0 : i32

  // CHECK: [[ZERO1:%.*]] = llvm.mlir.constant(0 : i8) : i8
  // CHECK: llvm.call spir_funccc @_Z21sub_group_shuffle_xorcj([[ZERO1]], [[ZERO]]) {{.*}} : (i8, i32) -> i8
  %5 = llvm.mlir.constant(0 : i8) : i8
  %6 = triton_gen.sub_group_shuffle xor %5, %0 : i8

  // CHECK: [[ZERO2:%.*]] = llvm.mlir.constant(0 : i16) : i16
  // CHECK: llvm.call spir_funccc @_Z21sub_group_shuffle_xorsj([[ZERO2]], [[ZERO]]) {{.*}} : (i16, i32) -> i16
  %7 = llvm.mlir.constant(0 : i16) : i16
  %8 = triton_gen.sub_group_shuffle xor %7, %0 : i16

  // CHECK: [[ZERO3:%.*]] = llvm.mlir.constant(0 : i64) : i64
  // CHECK: llvm.call spir_funccc @_Z21sub_group_shuffle_xorlj([[ZERO3]], [[ZERO]]) {{.*}} : (i64, i32) -> i64
  %9 = llvm.mlir.constant(0 : i64) : i64
  %10 = triton_gen.sub_group_shuffle xor %9, %0 : i64

  // CHECK: [[ZERO4:%.*]] = llvm.mlir.constant(0.000000e+00 : f16) : f16
  // CHECK: llvm.call spir_funccc @_Z21sub_group_shuffle_xorDhj([[ZERO4]], [[ZERO]]) {{.*}} : (f16, i32) -> f16
  %11 = llvm.mlir.constant(0.0 : f16) : f16
  %12 = triton_gen.sub_group_shuffle xor %11, %0 : f16

  // CHECK: [[ZERO5:%.*]] = llvm.mlir.constant(0.000000e+00 : f32) : f32
  // CHECK: llvm.call spir_funccc @_Z21sub_group_shuffle_xorfj([[ZERO5]], [[ZERO]]) {{.*}} : (f32, i32) -> f32
  %13 = llvm.mlir.constant(0.0 : f32) : f32
  %14 = triton_gen.sub_group_shuffle xor %13, %0 : f32

  // CHECK: [[ZERO6:%.*]] = llvm.mlir.constant(0.000000e+00 : f64) : f64
  // CHECK: llvm.call spir_funccc @_Z21sub_group_shuffle_xordj([[ZERO6]], [[ZERO]]) {{.*}} : (f64, i32) -> f64
  %15 = llvm.mlir.constant(0.0 : f64) : f64
  %16 = triton_gen.sub_group_shuffle xor %15, %0 : f64
  llvm.return
}

// -----

// CHECK: llvm.func spir_funccc @_Z36intel_sub_group_i8_i8_matrix_mad_k32Dv8_sDv8_iS0_(vector<8xi16>, vector<8xi32>, vector<8xi32>) -> vector<8xi32> attributes {passthrough = ["convergent"]}

llvm.func @triton_gen.dpas.i8(%c : vector<8xi32>, %a : vector<8xi16>, %b : vector<8xi32>) {
  // CHECK:     llvm.func @triton_gen.dpas.i8(%arg0: vector<8xi32>, %arg1: vector<8xi16>, %arg2: vector<8xi32>) {
  // CHECK-NEXT: llvm.call spir_funccc @_Z36intel_sub_group_i8_i8_matrix_mad_k32Dv8_sDv8_iS0_(%arg1, %arg2, %arg0) {{.*}} : (vector<8xi16>, vector<8xi32>, vector<8xi32>) -> vector<8xi32>
  %0 = triton_gen.dpas %c, %a, %b {pa = i8, pb = i8, rc = 8} : (vector<8xi32>, vector<8xi16>, vector<8xi32>) -> vector<8xi32>
  llvm.return
}

// -----

// CHECK: llvm.func spir_funccc @_Z36intel_sub_group_u8_u8_matrix_mad_k32Dv8_sDv8_iS0_(vector<8xi16>, vector<8xi32>, vector<8xi32>) -> vector<8xi32> attributes {passthrough = ["convergent"]}

llvm.func @triton_gen.dpas.u8(%c : vector<8xi32>, %a : vector<8xi16>, %b : vector<8xi32>) {
  // CHECK:     llvm.func @triton_gen.dpas.u8(%arg0: vector<8xi32>, %arg1: vector<8xi16>, %arg2: vector<8xi32>) {
  // CHECK-NEXT: llvm.call spir_funccc @_Z36intel_sub_group_u8_u8_matrix_mad_k32Dv8_sDv8_iS0_(%arg1, %arg2, %arg0) {{.*}} : (vector<8xi16>, vector<8xi32>, vector<8xi32>) -> vector<8xi32>
  %0 = triton_gen.dpas %c, %a, %b {pa = u8, pb = u8, rc = 8} : (vector<8xi32>, vector<8xi16>, vector<8xi32>) -> vector<8xi32>
  llvm.return
}

// -----

// CHECK: llvm.func spir_funccc @_Z40intel_sub_group_bf16_bf16_matrix_mad_k16Dv8_sDv8_iDv8_f(vector<8xi16>, vector<8xi32>, vector<8xf32>) -> vector<8xf32> attributes {passthrough = ["convergent"]}

llvm.func @triton_gen.dpas.bf16(%c : vector<8xf32>, %a : vector<8xi16>, %b : vector<8xi32>) {
  // CHECK:     llvm.func @triton_gen.dpas.bf16(%arg0: vector<8xf32>, %arg1: vector<8xi16>, %arg2: vector<8xi32>) {
  // CHECK-NEXT: llvm.call spir_funccc @_Z40intel_sub_group_bf16_bf16_matrix_mad_k16Dv8_sDv8_iDv8_f(%arg1, %arg2, %arg0) {{.*}} : (vector<8xi16>, vector<8xi32>, vector<8xf32>) -> vector<8xf32>
  %0 = triton_gen.dpas %c, %a, %b {pa = bf16, pb = bf16, rc = 8} : (vector<8xf32>, vector<8xi16>, vector<8xi32>) -> vector<8xf32>
  llvm.return
}

// -----

// CHECK: llvm.func spir_funccc @_Z38intel_sub_group_f16_f16_matrix_mad_k16Dv8_sDv8_iDv8_f(vector<8xi16>, vector<8xi32>, vector<8xf32>) -> vector<8xf32> attributes {passthrough = ["convergent"]}

llvm.func @triton_gen.dpas.f16(%c : vector<8xf32>, %a : vector<8xi16>, %b : vector<8xi32>) {
  // CHECK:     llvm.func @triton_gen.dpas.f16(%arg0: vector<8xf32>, %arg1: vector<8xi16>, %arg2: vector<8xi32>) {
  // CHECK-NEXT: llvm.call spir_funccc @_Z38intel_sub_group_f16_f16_matrix_mad_k16Dv8_sDv8_iDv8_f(%arg1, %arg2, %arg0) {{.*}} : (vector<8xi16>, vector<8xi32>, vector<8xf32>) -> vector<8xf32>
  %0 = triton_gen.dpas %c, %a, %b {pa = f16, pb = f16, rc = 8} : (vector<8xf32>, vector<8xi16>, vector<8xi32>) -> vector<8xf32>
  llvm.return
}

// -----

// CHECK: llvm.func spir_funccc @_Z39intel_sub_group_tf32_tf32_matrix_mad_k8Dv4_fDv8_fS0_(vector<4xf32>, vector<8xf32>, vector<8xf32>) -> vector<8xf32> attributes {passthrough = ["convergent"]}

llvm.func @triton_gen.dpas.f32(%c : vector<8xf32>, %a : vector<4xf32>, %b : vector<8xf32>) {
  // CHECK:     llvm.func @triton_gen.dpas.f32(%arg0: vector<8xf32>, %arg1: vector<4xf32>, %arg2: vector<8xf32>) {
  // CHECK-NEXT: llvm.call spir_funccc @_Z39intel_sub_group_tf32_tf32_matrix_mad_k8Dv4_fDv8_fS0_
  // CHECK-SAME:    (%arg1, %arg2, %arg0)
  // CHECK-SAME:    passthrough = ["convergent"]
  // CHECK-SAME:    : (vector<4xf32>, vector<8xf32>, vector<8xf32>) -> vector<8xf32>
  %0 = triton_gen.dpas %c, %a, %b {pa = tf32, pb = tf32, rc = 8} : (vector<8xf32>, vector<4xf32>, vector<8xf32>) -> vector<8xf32>
  llvm.return
}

// -----

// CHECK: llvm.func spir_funccc @_Z38intel_sub_group_f16_f16_matrix_mad_k16Dv8_sDv8_iDv8_Dh(vector<8xi16>, vector<8xi32>, vector<8xf16>) -> vector<8xf16> attributes {passthrough = ["convergent"]}

llvm.func @triton_gen.dpas.f16_accum(%c: vector<8xf16>, %a : vector<8xi16>, %b : vector<8xi32>) {
  // CHECK:     llvm.func @triton_gen.dpas.f16_accum(%arg0: vector<8xf16>, %arg1: vector<8xi16>, %arg2: vector<8xi32>) {
  // CHECK-NEXT: lvm.call spir_funccc @_Z38intel_sub_group_f16_f16_matrix_mad_k16Dv8_sDv8_iDv8_Dh
  // CHECK-SAME:    (%arg1, %arg2, %arg0)
  // CHECK-SAME:    passthrough = ["convergent"]
  // CHECK-SAME:    : (vector<8xi16>, vector<8xi32>, vector<8xf16>) -> vector<8xf16>
  %0 = triton_gen.dpas %c, %a, %b {pa = f16, pb = f16, rc = 8} : (vector<8xf16>, vector<8xi16>, vector<8xi32>) -> vector<8xf16>
  llvm.return
}

// -----

// CHECK: llvm.func spir_funccc @_Z40intel_sub_group_bf16_bf16_matrix_mad_k16Dv8_sDv8_iS_(vector<8xi16>, vector<8xi32>, vector<8xi16>) -> vector<8xi16> attributes {passthrough = ["convergent"]}

llvm.func @triton_gen.dpas.bf16_accum(%c: vector<8xbf16>, %a : vector<8xi16>, %b : vector<8xi32>) {
  // CHECK:     llvm.func @triton_gen.dpas.bf16_accum(%arg0: vector<8xbf16>, %arg1: vector<8xi16>, %arg2: vector<8xi32>) {
  // CHECK-NEXT: [[CAST:%.*]] = llvm.bitcast %arg0 : vector<8xbf16> to vector<8xi16>
  // CHECK-NEXT: [[RES:%.*]] = llvm.call spir_funccc @_Z40intel_sub_group_bf16_bf16_matrix_mad_k16Dv8_sDv8_iS_
  // CHECK-SAME:    (%arg1, %arg2, [[CAST]])
  // CHECK-SAME:    passthrough = ["convergent"]
  // CHECK-SAME:    : (vector<8xi16>, vector<8xi32>, vector<8xi16>) -> vector<8xi16>
  %0 = triton_gen.dpas %c, %a, %b {pa = bf16, pb = bf16, rc = 8} : (vector<8xbf16>, vector<8xi16>, vector<8xi32>) -> vector<8xbf16>
  // CHECK-NEXT: {{%.*}} = llvm.bitcast [[RES]] : vector<8xi16> to vector<8xbf16>
  llvm.return
}
