{-|
Module      : $Header$
Description : The adapter interface
Copyright   : (c) Justus Adam, 2016
License     : BSD3
Maintainer  : dev@justus.science
Stability   : experimental
Portability : POSIX
-}
{-# LANGUAGE ExplicitForAll      #-}
{-# LANGUAGE FlexibleInstances   #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Marvin.Adapter
    ( Event(..)
    , RunWithAdapter, EventHandler, InitEventHandler, RunnerM
    , IsAdapter(..)
    , liftAdapterAction
    ) where

import           Control.Monad.IO.Class
import           Control.Monad.Logger
import qualified Data.Configurator.Types as C
import qualified Data.Text.Lazy          as L
import           Marvin.Internal.Types


liftAdapterAction :: MonadLoggerIO m => RunnerM a -> m a
liftAdapterAction ac = do
    loggingFn <- askLoggerIO
    liftIO $ runLoggingT ac loggingFn
