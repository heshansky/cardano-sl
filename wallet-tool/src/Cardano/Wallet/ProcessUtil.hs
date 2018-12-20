{-# LANGUAGE CPP             #-}

module Cardano.Wallet.ProcessUtil
  ( checkProcessExists
  , ProcessID
  , cancelOnExit
  , interruptSelf
  ) where

import           Universum

import           Control.Concurrent.Async (Async (..), cancel)
import           Control.Exception (IOException)

#if defined(mingw32_HOST_OS)
-- Declare stub functions for windows

checkProcessExists :: Maybe ProcessID -> IO Bool
checkProcessExists = const (pure True)

cancelOnExit :: Async a -> IO b -> IO b
cancelOnExit _ = id

interruptSelf :: IO ()
interruptSelf = pure ()

#else

import           System.Posix.Process
import           System.Posix.Signals
import           System.Posix.Types

-- | Monitors that a given process is still running. Useful for when
-- polling the API of that process.
checkProcessExists :: Maybe ProcessID -> IO Bool
checkProcessExists Nothing = pure True
checkProcessExists (Just pid) = hasGroup `catch` (\(_ :: IOException) -> pure False)
  where
    hasGroup = (> 0) <$> getProcessGroupIDOf pid

-- | Installs sigterm and sigint handlers for while an IO action is
-- being run. The signal handlers cancel an Async process.
cancelOnExit :: Async a -> IO b -> IO b
cancelOnExit a = cancelOnCtrlC a . cancelOnTerm a
  where
    addHandler sig h = installHandler sig h Nothing
    cancelOnSig sig as act = bracket (addHandler sig (Catch (cancel as))) (addHandler sig) (const act)
    cancelOnCtrlC = cancelOnSig keyboardSignal
    cancelOnTerm = cancelOnSig softwareTermination

-- | This is only used for testing.
interruptSelf :: IO ()
interruptSelf = raiseSignal sigINT

#endif
