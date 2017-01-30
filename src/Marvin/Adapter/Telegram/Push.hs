{-|
Module      : $Header$
Description : Adapter for communicating with Telegram via its webhook based push API.
Copyright   : (c) Justus Adam, 2017
License     : BSD3
Maintainer  : dev@justus.science
Stability   : experimental
Portability : POSIX
-}
{-# LANGUAGE NamedFieldPuns #-}
module Marvin.Adapter.Telegram.Push
    ( TelegramAdapter, Push
    , TelegramChat(..), ChatType(..)
    , TelegramUser(..)
    , MkTelegram
    ) where


import           Control.Concurrent.Chan.Lifted
import           Marvin.Adapter
import           Marvin.Adapter.Telegram.Common
import Marvin.Interpolate.All
import Marvin.Types
import Control.Concurrent.Async.Lifted
import Network.Wai
import Network.Wai.Handler.Warp
import Network.Wai.Handler.WarpTLS
import Network.HTTP.Types
import Network.Wreq
import Control.Monad.IO.Class
import Data.Aeson hiding (Success, Error)
import Control.Monad.Logger
import Data.Maybe (fromMaybe)
import Control.Monad
import qualified Data.Text as T


pushEventGetter :: Chan (TelegramUpdate Push) -> AdapterM (TelegramAdapter Push) ()
pushEventGetter evChan = do
    void $ async $ do
        url <- requireFromAdapterConfig "url"
        r <- execAPIMethod parseJSON "setWebhook"
            [ "url" := (url :: T.Text)
            , "allowed_updates" := show telegramSupportedUpdates
            ]
        case r of 
            Right Success{ result = True } -> return ()
            Left err -> error $(isS "Parsing result from setting webhook failed #{err}")
            Right Error{errDescription} -> error $(isS "Setting the webhook failed: #{errDescription}")
    useTLS <- fromMaybe True <$> lookupFromAdapterConfig "use-tls"
    port <- requireFromAdapterConfig "port"

    server <- if useTLS
        then do
            certfile <- requireFromAdapterConfig "certfile"
            keyfile <- requireFromAdapterConfig "keyfile"
            return $ runTLS $ tlsSettings certfile keyfile
        else return runSettings

    let warpSet = setPort port defaultSettings

    logFn <- askLoggerIO

    liftIO $ server warpSet $ \req resp -> flip runLoggingT logFn $ do
        let meth = requestMethod req
        if meth == methodPost
            then do
                bod <- liftIO $ lazyRequestBody req
                case eitherDecode bod of
                    Left err -> do
                        logErrorN $(isT "Unreadable JSON event: '#{err}'")
                        liftIO $ resp $ responseLBS notAcceptable406 [] ""
                    Right update -> do
                        writeChan evChan update
                        liftIO $ resp $ responseLBS ok200 [] ""
            else liftIO $ resp $ responseLBS methodNotAllowed405 [] ""
    


-- | Use the telegram API by recieving updates as a server via webhook
--
-- Note: The initialization for this adapter _includes_ registering or clearing its own webhook.
data Push


instance MkTelegram Push where
    mkAdapterId = "telegram-push"
    mkEventGetter = pushEventGetter