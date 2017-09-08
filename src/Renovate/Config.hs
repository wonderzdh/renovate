{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE DataKinds  #-}
-- | Internal helpers for the ELF rewriting interface
module Renovate.Config (
  RenovateConfig(..)
, Rewriter(..)
  ) where

import qualified Control.Monad.Catch as C
import qualified Data.ByteString as B

import qualified Data.Macaw.Architecture.Info as MM

import qualified Renovate.Arch.X86_64.Internal as X86

import qualified Renovate.Redirect as SFE
import qualified Renovate.ISA as SFE

import qualified Renovate.Instrument as I

-- | The configuration required for a run of the ELF rewriter.
data RenovateConfig i a w arch =
  RenovateConfig { rcISA           :: SFE.ISA i a w
                 , rcArchInfo      :: MM.ArchitectureInfo arch
                 , rcAssembler     :: forall m . (C.MonadThrow m) => i () -> m B.ByteString
                 , rcDisassembler  :: forall m . (C.MonadThrow m) => B.ByteString -> m [i ()]
                 , rcDisassembler1 :: forall m . (C.MonadThrow m) => B.ByteString -> m (Int, i ())
                 , rcInstrumentor  :: SFE.SymbolicBlock i a w -> I.Instrument i w [SFE.TaggedInstruction i a]
                 }

data Rewriter = Rewriter
  { iX86_64 :: SFE.SymbolicBlock X86.Instruction (X86.TargetAddress 64) 64
            -> I.Instrument X86.Instruction 64 [SFE.TaggedInstruction X86.Instruction (X86.TargetAddress 64)]
  }

