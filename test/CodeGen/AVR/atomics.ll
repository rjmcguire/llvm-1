; RUN: llc -mattr=avr6 < %s -march=avr | FileCheck %s

; Tests atomic operations on AVR

; CHECK-LABEL: atomic_load8
; CHECK:      in r0, 63
; CHECK-NEXT: cli
; CHECK-NEXT: mov [[RR:r[0-9]+]], [[RD:r[0-9]+]]
; CHECK-NEXT: out 63, r0
define i8 @atomic_load8(i8* %foo) {
  %val = load atomic i8, i8* %foo unordered, align 1
  ret i8 %val
}

; CHECK-LABEL: atomic_load16
; CHECK:      in r0, 63
; CHECK-NEXT: cli
; CHECK-NEXT: movw [[RR:r[0-9]+]], [[RD:r[0-9]+]]
; CHECK-NEXT: out 63, r0
define i16 @atomic_load16(i16* %foo) {
  %val = load atomic i16, i16* %foo unordered, align 2
  ret i16 %val
}

