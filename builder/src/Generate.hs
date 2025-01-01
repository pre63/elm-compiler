{-# LANGUAGE BangPatterns #-}
module Generate
  ( debug
  , dev
  , prod
  , repl
  )
  where

import Prelude hiding (cycle, print)
import Control.Concurrent (MVar, forkIO, newEmptyMVar, newMVar, putMVar, readMVar)
import Control.Monad (liftM2)
import qualified Data.ByteString.Builder as B
import Data.Map ((!))
import qualified Data.Map as Map
import qualified Data.Maybe as Maybe
import qualified Data.Name as N
import qualified Data.NonEmptyList as NE

import qualified AST.Optimized as Opt
import qualified Build
import qualified Elm.Compiler.Type.Extract as Extract
import qualified Elm.Details as Details
import qualified Elm.Interface as I
import qualified Elm.ModuleName as ModuleName
import qualified Elm.Package as Pkg
import qualified File
import qualified Generate.LLVM as LLVM
import qualified Generate.Mode as Mode
import qualified Nitpick.Debug as Nitpick
import qualified Reporting.Exit as Exit
import qualified Reporting.Task as Task
import qualified Stuff

type Task a = Task.Task Exit.Generate a

debug :: FilePath -> Details.Details -> Build.Artifacts -> Task B.Builder
debug root details (Build.Artifacts pkg ifaces roots modules) =
  do
    loading <- loadObjects root details modules
    types <- loadTypes root ifaces modules
    objects <- finalizeObjects loading
    let mode = Mode.Dev (Just types)
    let graph = objectsToGlobalGraph objects
    let mains = gatherMains pkg objects roots
    return $ LLVM.generate mode graph mains

dev :: FilePath -> Details.Details -> Build.Artifacts -> Task B.Builder
dev root details (Build.Artifacts pkg _ roots modules) =
  do
    objects <- finalizeObjects =<< loadObjects root details modules
    let mode = Mode.Dev Nothing
    let graph = objectsToGlobalGraph objects
    let mains = gatherMains pkg objects roots
    return $ LLVM.generate mode graph mains

prod :: FilePath -> Details.Details -> Build.Artifacts -> Task B.Builder
prod root details (Build.Artifacts pkg _ roots modules) =
  do
    objects <- finalizeObjects =<< loadObjects root details modules
    checkForDebugUses objects
    let graph = objectsToGlobalGraph objects
    let mode = Mode.Prod (Mode.shortenFieldNames graph)
    let mains = gatherMains pkg objects roots
    return $ LLVM.generate mode graph mains

repl :: FilePath -> Details.Details -> Bool -> Build.ReplArtifacts -> N.Name -> Task B.Builder
repl root details ansi (Build.ReplArtifacts home modules localizer annotations) name =
  do
    objects <- finalizeObjects =<< loadObjects root details modules
    let graph = objectsToGlobalGraph objects
    return $ LLVM.generateForRepl ansi localizer graph home name (annotations ! name)
