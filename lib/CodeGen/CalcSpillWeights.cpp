//===------------------------ CalcSpillWeights.cpp ------------------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "llvm/CodeGen/VirtRegMap.h"
#include "llvm/CodeGen/CalcSpillWeights.h"
#include "llvm/CodeGen/LiveIntervalAnalysis.h"
#include "llvm/CodeGen/MachineBlockFrequencyInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineLoopInfo.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Target/TargetInstrInfo.h"
#include "llvm/Target/TargetRegisterInfo.h"
#include "llvm/Target/TargetSubtargetInfo.h"
using namespace llvm;

#define DEBUG_TYPE "calcspillweights"

void llvm::calculateSpillWeightsAndHints(LiveIntervals &LIS,
                           MachineFunction &MF,
                           VirtRegMap *VRM,
                           const MachineLoopInfo &MLI,
                           const MachineBlockFrequencyInfo &MBFI,
                           VirtRegAuxInfo::NormalizingFn norm) {
  DEBUG(dbgs() << "********** Compute Spill Weights **********\n"
               << "********** Function: " << MF.getName() << '\n');

  MachineRegisterInfo &MRI = MF.getRegInfo();
  VirtRegAuxInfo VRAI(MF, LIS, VRM, MLI, MBFI, norm);
  for (unsigned i = 0, e = MRI.getNumVirtRegs(); i != e; ++i) {
    unsigned Reg = TargetRegisterInfo::index2VirtReg(i);
    if (MRI.reg_nodbg_empty(Reg))
      continue;
    VRAI.calculateSpillWeightAndHint(LIS.getInterval(Reg));
  }
}

// Return the preferred allocation register for reg, given a COPY instruction.
static unsigned copyHint(const MachineInstr *mi, unsigned reg,
                         const TargetRegisterInfo &tri,
                         const MachineRegisterInfo &mri) {
  unsigned sub, hreg, hsub;
  if (mi->getOperand(0).getReg() == reg) {
    sub = mi->getOperand(0).getSubReg();
    hreg = mi->getOperand(1).getReg();
    hsub = mi->getOperand(1).getSubReg();
  } else {
    sub = mi->getOperand(1).getSubReg();
    hreg = mi->getOperand(0).getReg();
    hsub = mi->getOperand(0).getSubReg();
  }

  if (!hreg)
    return 0;

  if (TargetRegisterInfo::isVirtualRegister(hreg))
    return sub == hsub ? hreg : 0;

  const TargetRegisterClass *rc = mri.getRegClass(reg);

  // Only allow physreg hints in rc.
  if (sub == 0)
    return rc->contains(hreg) ? hreg : 0;

  // reg:sub should match the physreg hreg.
  return tri.getMatchingSuperReg(hreg, sub, rc);
}

// Check if all values in LI are rematerializable
static bool isRematerializable(const LiveInterval &LI,
                               const LiveIntervals &LIS,
                               VirtRegMap *VRM,
                               const TargetInstrInfo &TII) {
  unsigned Reg = LI.reg;
  unsigned Original = VRM ? VRM->getOriginal(Reg) : 0;
  for (LiveInterval::const_vni_iterator I = LI.vni_begin(), E = LI.vni_end();
       I != E; ++I) {
    const VNInfo *VNI = *I;
    if (VNI->isUnused())
      continue;
    if (VNI->isPHIDef())
      return false;

    MachineInstr *MI = LIS.getInstructionFromIndex(VNI->def);
    assert(MI && "Dead valno in interval");

    // Trace copies introduced by live range splitting.  The inline
    // spiller can rematerialize through these copies, so the spill
    // weight must reflect this.
    if (VRM) {
      while (MI->isFullCopy()) {
        // The copy destination must match the interval register.
        if (MI->getOperand(0).getReg() != Reg)
          return false;

        // Get the source register.
        Reg = MI->getOperand(1).getReg();

        // If the original (pre-splitting) registers match this
        // copy came from a split.
        if (!TargetRegisterInfo::isVirtualRegister(Reg) ||
            VRM->getOriginal(Reg) != Original)
          return false;

        // Follow the copy live-in value.
        const LiveInterval &SrcLI = LIS.getInterval(Reg);
        LiveQueryResult SrcQ = SrcLI.Query(VNI->def);
        VNI = SrcQ.valueIn();
        assert(VNI && "Copy from non-existing value");
        if (VNI->isPHIDef())
          return false;
        MI = LIS.getInstructionFromIndex(VNI->def);
        assert(MI && "Dead valno in interval");
      }
    }

    if (!TII.isTriviallyReMaterializable(MI, LIS.getAliasAnalysis()))
      return false;
  }
  return true;
}

void
VirtRegAuxInfo::calculateSpillWeightAndHint(LiveInterval &li) {
  MachineRegisterInfo &mri = MF.getRegInfo();
  const TargetRegisterInfo &tri = *MF.getSubtarget().getRegisterInfo();
  MachineBasicBlock *mbb = nullptr;
  MachineLoop *loop = nullptr;
  bool isExiting = false;
  float totalWeight = 0;
  unsigned numInstr = 0; // Number of instructions using li
  SmallPtrSet<MachineInstr*, 8> visited;

  // Find the best physreg hint and the best virtreg hint.
  float bestPhys = 0, bestVirt = 0;
  unsigned hintPhys = 0, hintVirt = 0;

  // Don't recompute a target specific hint.
  bool noHint = mri.getRegAllocationHint(li.reg).first != 0;

  // Don't recompute spill weight for an unspillable register.
  bool Spillable = li.isSpillable();

  for (MachineRegisterInfo::reg_instr_iterator
       I = mri.reg_instr_begin(li.reg), E = mri.reg_instr_end();
       I != E; ) {
    MachineInstr *mi = &*(I++);
    numInstr++;
    if (mi->isIdentityCopy() || mi->isImplicitDef() || mi->isDebugValue())
      continue;
    if (!visited.insert(mi).second)
      continue;

    float weight = 1.0f;
    if (Spillable) {
      // Get loop info for mi.
      if (mi->getParent() != mbb) {
        mbb = mi->getParent();
        loop = Loops.getLoopFor(mbb);
        isExiting = loop ? loop->isLoopExiting(mbb) : false;
      }

      // Calculate instr weight.
      bool reads, writes;
      std::tie(reads, writes) = mi->readsWritesVirtualRegister(li.reg);
      weight = LiveIntervals::getSpillWeight(writes, reads, &MBFI, *mi);

      // Give extra weight to what looks like a loop induction variable update.
      if (writes && isExiting && LIS.isLiveOutOfMBB(li, mbb))
        weight *= 3;

      totalWeight += weight;
    }

    // Get allocation hints from copies.
    if (noHint || !mi->isCopy())
      continue;
    unsigned hint = copyHint(mi, li.reg, tri, mri);
    if (!hint)
      continue;
    // Force hweight onto the stack so that x86 doesn't add hidden precision,
    // making the comparison incorrectly pass (i.e., 1 > 1 == true??).
    //
    // FIXME: we probably shouldn't use floats at all.
    volatile float hweight = Hint[hint] += weight;
    if (TargetRegisterInfo::isPhysicalRegister(hint)) {
      if (hweight > bestPhys && mri.isAllocatable(hint)) {
        bestPhys = hweight;
        hintPhys = hint;
      }
    } else {
      if (hweight > bestVirt) {
        bestVirt = hweight;
        hintVirt = hint;
      }
    }
  }

  Hint.clear();

  // Always prefer the physreg hint.
  if (unsigned hint = hintPhys ? hintPhys : hintVirt) {
    mri.setRegAllocationHint(li.reg, 0, hint);
    // Weakly boost the spill weight of hinted registers.
    totalWeight *= 1.01F;
  }

  // If the live interval was already unspillable, leave it that way.
  if (!Spillable)
    return;

  // Mark li as unspillable if all live ranges are tiny and the interval
  // is not live at any reg mask.  If the interval is live at a reg mask
  // spilling may be required.
  if (li.isZeroLength(LIS.getSlotIndexes()) &&
      !li.isLiveAtIndexes(LIS.getRegMaskSlots())) {
    // HACK HACK: This is a workaround until PR14879 gets fixed!
    // This code allows us to compile memory intensive functions when only the Z
    // register is available, otherwise we get the "Ran out of registers ..."
    // assertion inside the regalloc.
    // Here we avoid marking as not spillable live intervals that use the
    // PTRDISPREGS class and have a size greater than 8, smaller ones
    // get filtered out, generating better code.
    if (strcmp(MF.getSubtarget().getRegisterInfo()->getRegClassName(mri.getRegClass(li.reg)), "PTRDISPREGS") == 0 &&
      li.getSize() > 8) {
      totalWeight *= 10000.0F;
      li.weight = normalizeSpillWeight(totalWeight, li.getSize(), numInstr);
    } else {
      li.markNotSpillable();
    }
    return;
  }

  // If all of the definitions of the interval are re-materializable,
  // it is a preferred candidate for spilling.
  // FIXME: this gets much more complicated once we support non-trivial
  // re-materialization.
  if (isRematerializable(li, LIS, VRM, *MF.getSubtarget().getInstrInfo()))
    totalWeight *= 0.5F;

  li.weight = normalize(totalWeight, li.getSize(), numInstr);
}
