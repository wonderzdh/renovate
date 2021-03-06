{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
module Renovate.Arch.PPC (
  -- * Configuration
  config32,
  config64,
  -- * Architecture Selection
  MP.PPC64,
  MP.PPC32,
  -- * Functions
  isa,
  -- * Assembly and Disassembly
  assemble,
  disassemble,
  Instruction,
  TargetAddress(..),
  -- * ELF Support
  MP.TOC,
  MP.parseTOC,
  MP.lookupTOC,
  MP.entryPoints,
  -- * Instruction Helpers
  toInst,
  fromInst,
  -- * Exceptions
  InstructionDisassemblyFailure(..)
  ) where

import qualified Data.Macaw.BinaryLoader as MBL
import qualified Data.Macaw.CFG.Core as MC
import qualified Data.Macaw.Memory as MM

import qualified Data.Macaw.PPC as MP
-- FIXME: We probably shouldn't need this import, since the PPCReg type is
-- re-exported from Data.Macaw.PPC
import           Data.Macaw.PPC.PPCReg ()
import qualified Data.Macaw.PPC.Symbolic as MPS

import qualified Renovate as R
import           Renovate.Arch.PPC.ISA

-- | A renovate configuration for 32 bit PowerPC
config32 :: (MM.MemWidth w, w ~ 32, MC.ArchAddrWidth MP.PPC32 ~ w, MBL.BinaryLoader MP.PPC32 binFmt, MBL.ArchBinaryData MP.PPC32 binFmt ~ MP.TOC MP.PPC32)
         => R.Analyze MP.PPC32 binFmt a
         -- ^ An analysis function that produces a summary result that will be
         -- fed into the rewriter
         -> R.Rewrite MP.PPC32 binFmt a
         -- ^ A rewriting action
         -> R.RenovateConfig MP.PPC32 binFmt a
config32 analysis rewriter =
  R.RenovateConfig { R.rcISA = isa
                   , R.rcArchInfo = MP.ppc32_linux_info . MBL.archBinaryData
                   , R.rcAssembler = assemble
                   , R.rcDisassembler = disassemble
                   , R.rcBlockCallback = Nothing
                   , R.rcFunctionCallback = Nothing
                   , R.rcELFEntryPoints = MP.entryPoints . MBL.archBinaryData
                   , R.rcAnalysis = analysis
                   , R.rcRewriter = rewriter
                   , R.rcUpdateSymbolTable = False
                   -- See Note [Layout Addresses]
                   , R.rcCodeLayoutBase = 0x10100000
                   , R.rcDataLayoutBase = 0x20000000
                   }

-- | A renovate configuration for 64 bit PowerPC
config64 :: (MM.MemWidth w, w ~ 64, MC.ArchAddrWidth MP.PPC64 ~ w, MBL.BinaryLoader MP.PPC64 binFmt, MBL.ArchBinaryData MP.PPC64 binFmt ~ MP.TOC MP.PPC64)
         => R.Analyze MP.PPC64 binFmt a
         -- ^ An analysis function that produces a summary result that will be
         -- fed into the rewriter
         -> R.Rewrite MP.PPC64 binFmt a
         -- ^ A rewriting action
         -> R.RenovateConfig MP.PPC64 binFmt a
config64 analysis rewriter =
  R.RenovateConfig { R.rcISA = isa
                   , R.rcArchInfo = MP.ppc64_linux_info . MBL.archBinaryData
                   , R.rcAssembler = assemble
                   , R.rcDisassembler = disassemble
                   , R.rcBlockCallback = Nothing
                   , R.rcFunctionCallback = Nothing
                   , R.rcELFEntryPoints = MP.entryPoints . MBL.archBinaryData
                   , R.rcAnalysis = analysis
                   , R.rcRewriter = rewriter
                   , R.rcUpdateSymbolTable = False
                   -- See Note [Layout Addresses]
                   , R.rcCodeLayoutBase = 0x10100000
                   , R.rcDataLayoutBase = 0x20000000
                   }

instance R.ArchInfo MP.PPC64 where
  archVals _ = Just (R.ArchVals { R.archFunctions = MPS.ppc64MacawSymbolicFns
                                , R.withArchEval = \sym k -> do
                                    sfns <- MPS.newSymFuns sym
                                    k (MPS.ppc64MacawEvalFn sfns)
                                , R.withArchConstraints = \x -> x
                                })

instance R.ArchInfo MP.PPC32 where
  archVals _ = Just (R.ArchVals { R.archFunctions = MPS.ppc32MacawSymbolicFns
                                , R.withArchEval = \sym k -> do
                                    sfns <- MPS.newSymFuns sym
                                    k (MPS.ppc32MacawEvalFn sfns)
                                , R.withArchConstraints = \x -> x
                                })

{- Note [Layout Addresses]

In PowerPC (at least in the v1 ABI for PowerPC 64), everything seems to start
around address 0x10000000.  We choose addresses far from there for our new code
and data.  Note that we can't go too far, as we need to be able to jump with a
single branch where we only have 24 bits of offset available.

-}
