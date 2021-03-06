; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc < %s -mtriple=x86_64-unknown-unknown -mattr=+avx,+xop | FileCheck %s
; RUN: llc < %s -mtriple=x86_64-unknown-unknown -mattr=+avx2,+xop | FileCheck %s

declare <2 x double> @llvm.x86.xop.vpermil2pd(<2 x double>, <2 x double>, <2 x double>, i8) nounwind readnone
declare <4 x double> @llvm.x86.xop.vpermil2pd.256(<4 x double>, <4 x double>, <4 x double>, i8) nounwind readnone

declare <4 x float> @llvm.x86.xop.vpermil2ps(<4 x float>, <4 x float>, <4 x float>, i8) nounwind readnone
declare <8 x float> @llvm.x86.xop.vpermil2ps.256(<8 x float>, <8 x float>, <8 x float>, i8) nounwind readnone

declare <16 x i8> @llvm.x86.xop.vpperm(<16 x i8>, <16 x i8>, <16 x i8>) nounwind readnone

define <2 x double> @combine_vpermil2pd_identity(<2 x double> %a0, <2 x double> %a1) {
; CHECK-LABEL: combine_vpermil2pd_identity:
; CHECK:       # BB#0:
; CHECK-NEXT:    vmovsd {{.*#+}} xmm2 = mem[0],zero
; CHECK-NEXT:    vpermil2pd $0, %xmm2, %xmm0, %xmm1, %xmm0
; CHECK-NEXT:    vpermil2pd $0, %xmm2, %xmm0, %xmm0, %xmm0
; CHECK-NEXT:    retq
  %mask = bitcast <2 x i64> <i64 2, i64 0> to <2 x double>
  %res0 = call <2 x double> @llvm.x86.xop.vpermil2pd(<2 x double> %a1, <2 x double> %a0, <2 x double> %mask, i8 0)
  %res1 = call <2 x double> @llvm.x86.xop.vpermil2pd(<2 x double> %res0, <2 x double> undef, <2 x double> %mask, i8 0)
  ret <2 x double> %res1
}

define <4 x double> @combine_vpermil2pd256_identity(<4 x double> %a0, <4 x double> %a1) {
; CHECK-LABEL: combine_vpermil2pd256_identity:
; CHECK:       # BB#0:
; CHECK-NEXT:    vmovapd {{.*#+}} ymm2 = [9.881313e-324,0.000000e+00,9.881313e-324,0.000000e+00]
; CHECK-NEXT:    vpermil2pd $0, %ymm2, %ymm0, %ymm1, %ymm0
; CHECK-NEXT:    vpermil2pd $0, %ymm2, %ymm0, %ymm0, %ymm0
; CHECK-NEXT:    retq
  %mask = bitcast <4 x i64> <i64 2, i64 0, i64 2, i64 0> to <4 x double>
  %res0 = call <4 x double> @llvm.x86.xop.vpermil2pd.256(<4 x double> %a1, <4 x double> %a0, <4 x double> %mask, i8 0)
  %res1 = call <4 x double> @llvm.x86.xop.vpermil2pd.256(<4 x double> %res0, <4 x double> undef, <4 x double> %mask, i8 0)
  ret <4 x double> %res1
}

define <4 x float> @combine_vpermil2ps_identity(<4 x float> %a0, <4 x float> %a1) {
; CHECK-LABEL: combine_vpermil2ps_identity:
; CHECK:       # BB#0:
; CHECK-NEXT:    vmovaps {{.*#+}} xmm2 = [4.203895e-45,2.802597e-45,1.401298e-45,0.000000e+00]
; CHECK-NEXT:    vpermil2ps $0, %xmm2, %xmm0, %xmm1, %xmm0
; CHECK-NEXT:    vpermil2ps $0, %xmm2, %xmm0, %xmm0, %xmm0
; CHECK-NEXT:    retq
  %mask = bitcast <4 x i32> <i32 3, i32 2, i32 1, i32 0> to <4 x float>
  %res0 = call <4 x float> @llvm.x86.xop.vpermil2ps(<4 x float> %a1, <4 x float> %a0, <4 x float> %mask, i8 0)
  %res1 = call <4 x float> @llvm.x86.xop.vpermil2ps(<4 x float> %res0, <4 x float> undef, <4 x float> %mask, i8 0)
  ret <4 x float> %res1
}

define <8 x float> @combine_vpermil2ps256_identity(<8 x float> %a0, <8 x float> %a1) {
; CHECK-LABEL: combine_vpermil2ps256_identity:
; CHECK:       # BB#0:
; CHECK-NEXT:    vmovaps {{.*#+}} ymm2 = [4.203895e-45,2.802597e-45,1.401298e-45,0.000000e+00,1.401298e-45,0.000000e+00,4.203895e-45,2.802597e-45]
; CHECK-NEXT:    vpermil2ps $0, %ymm2, %ymm0, %ymm1, %ymm0
; CHECK-NEXT:    vpermil2ps $0, %ymm2, %ymm0, %ymm0, %ymm0
; CHECK-NEXT:    retq
  %mask = bitcast <8 x i32> <i32 3, i32 2, i32 1, i32 0, i32 1, i32 0, i32 3, i32 2> to <8 x float>
  %res0 = call <8 x float> @llvm.x86.xop.vpermil2ps.256(<8 x float> %a1, <8 x float> %a0, <8 x float> %mask, i8 0)
  %res1 = call <8 x float> @llvm.x86.xop.vpermil2ps.256(<8 x float> %res0, <8 x float> undef, <8 x float> %mask, i8 0)
  ret <8 x float> %res1
}

define <4 x float> @combine_vpermil2ps_blend_with_zero(<4 x float> %a0, <4 x float> %a1) {
; CHECK-LABEL: combine_vpermil2ps_blend_with_zero:
; CHECK:       # BB#0:
; CHECK-NEXT:    vpermil2ps $2, {{.*}}(%rip), %xmm1, %xmm0, %xmm0
; CHECK-NEXT:    retq
  %mask = bitcast <4 x i32> <i32 8, i32 1, i32 2, i32 3> to <4 x float>
  %res0 = call <4 x float> @llvm.x86.xop.vpermil2ps(<4 x float> %a0, <4 x float> %a1, <4 x float> %mask, i8 2)
  ret <4 x float> %res0
}

define <16 x i8> @combine_vpperm_identity(<16 x i8> %a0, <16 x i8> %a1) {
; CHECK-LABEL: combine_vpperm_identity:
; CHECK:       # BB#0:
; CHECK-NEXT:    vmovaps %xmm1, %xmm0
; CHECK-NEXT:    retq
  %res0 = call <16 x i8> @llvm.x86.xop.vpperm(<16 x i8> %a0, <16 x i8> %a1, <16 x i8> <i8 31, i8 30, i8 29, i8 28, i8 27, i8 26, i8 25, i8 24, i8 23, i8 22, i8 21, i8 20, i8 19, i8 18, i8 17, i8 16>)
  %res1 = call <16 x i8> @llvm.x86.xop.vpperm(<16 x i8> %res0, <16 x i8> undef, <16 x i8> <i8 15, i8 14, i8 13, i8 12, i8 11, i8 10, i8 9, i8 8, i8 7, i8 6, i8 5, i8 4, i8 3, i8 2, i8 1, i8 0>)
  ret <16 x i8> %res1
}

define <16 x i8> @combine_vpperm_zero(<16 x i8> %a0, <16 x i8> %a1) {
; CHECK-LABEL: combine_vpperm_zero:
; CHECK:       # BB#0:
; CHECK-NEXT:    vxorps %xmm0, %xmm0, %xmm0
; CHECK-NEXT:    retq
  %res0 = call <16 x i8> @llvm.x86.xop.vpperm(<16 x i8> %a0, <16 x i8> %a1, <16 x i8> <i8 128, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0>)
  %res1 = call <16 x i8> @llvm.x86.xop.vpperm(<16 x i8> %res0, <16 x i8> undef, <16 x i8> <i8 0, i8 128, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0, i8 0>)
  %res2 = call <16 x i8> @llvm.x86.xop.vpperm(<16 x i8> %res1, <16 x i8> undef, <16 x i8> <i8 0, i8 1, i8 128, i8 128, i8 128, i8 128, i8 128, i8 128, i8 128, i8 128, i8 128, i8 128, i8 128, i8 128, i8 128, i8 128>)
  ret <16 x i8> %res2
}

define <16 x i8> @combine_vpperm_identity_bitcast(<16 x i8> %a0, <16 x i8> %a1) {
; CHECK-LABEL: combine_vpperm_identity_bitcast:
; CHECK:       # BB#0:
; CHECK-NEXT:    vpaddq {{.*}}(%rip), %xmm0, %xmm0
; CHECK-NEXT:    retq
  %mask = bitcast <2 x i64> <i64 1084818905618843912, i64 506097522914230528> to <16 x i8>
  %res0 = call <16 x i8> @llvm.x86.xop.vpperm(<16 x i8> %a0, <16 x i8> %a1, <16 x i8> %mask)
  %res1 = call <16 x i8> @llvm.x86.xop.vpperm(<16 x i8> %res0, <16 x i8> undef, <16 x i8> %mask)
  %res2 = bitcast <16 x i8> %res1 to <2 x i64>
  %res3 = add <2 x i64> %res2, <i64 1084818905618843912, i64 506097522914230528>
  %res4 = bitcast <2 x i64> %res3 to <16 x i8>
  ret <16 x i8> %res4
}

define <16 x i8> @combine_vpperm_as_blend_with_zero(<16 x i8> %a0, <16 x i8> %a1) {
; CHECK-LABEL: combine_vpperm_as_blend_with_zero:
; CHECK:       # BB#0:
; CHECK-NEXT:    vpperm {{.*#+}} xmm0 = xmm0[0,1],zero,zero,xmm0[4,5,6,7],zero,zero,zero,zero,zero,zero,zero,zero
; CHECK-NEXT:    retq
  %res0 = call <16 x i8> @llvm.x86.xop.vpperm(<16 x i8> %a0, <16 x i8> %a1, <16 x i8> <i8 0, i8 1, i8 128, i8 129, i8 4, i8 5, i8 6, i8 7, i8 130, i8 131, i8 132, i8 133, i8 134, i8 135, i8 136, i8 137>)
  ret <16 x i8> %res0
}

define <16 x i8> @combine_vpperm_as_unary_unpckhwd(<16 x i8> %a0, <16 x i8> %a1) {
; CHECK-LABEL: combine_vpperm_as_unary_unpckhwd:
; CHECK:       # BB#0:
; CHECK-NEXT:    vpunpckhbw {{.*#+}} xmm0 = xmm0[8,8,9,9,10,10,11,11,12,12,13,13,14,14,15,15]
; CHECK-NEXT:    retq
  %res0 = call <16 x i8> @llvm.x86.xop.vpperm(<16 x i8> %a0, <16 x i8> %a0, <16 x i8> <i8 8, i8 24, i8 9, i8 25, i8 10, i8 26, i8 11, i8 27, i8 12, i8 28, i8 13, i8 29, i8 14, i8 30, i8 15, i8 31>)
  ret <16 x i8> %res0
}

define <16 x i8> @combine_vpperm_as_unpckhwd(<16 x i8> %a0, <16 x i8> %a1) {
; CHECK-LABEL: combine_vpperm_as_unpckhwd:
; CHECK:       # BB#0:
; CHECK-NEXT:    vpperm {{.*#+}} xmm0 = xmm0[8],xmm1[8],xmm0[9],xmm1[9],xmm0[10],xmm1[10],xmm0[11],xmm1[11],xmm0[12],xmm1[12],xmm0[13],xmm1[13],xmm0[14],xmm1[14],xmm0[15],xmm1[15]
; CHECK-NEXT:    retq
  %res0 = call <16 x i8> @llvm.x86.xop.vpperm(<16 x i8> %a0, <16 x i8> %a1, <16 x i8> <i8 8, i8 24, i8 9, i8 25, i8 10, i8 26, i8 11, i8 27, i8 12, i8 28, i8 13, i8 29, i8 14, i8 30, i8 15, i8 31>)
  ret <16 x i8> %res0
}
