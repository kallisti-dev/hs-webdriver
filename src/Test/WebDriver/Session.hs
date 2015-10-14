{-# LANGUAGE OverloadedStrings, DeriveDataTypeable, FlexibleContexts, ScopedTypeVariables,
             GeneralizedNewtypeDeriving, RecordWildCards, ConstraintKinds, CPP #-}

#ifndef CABAL_BUILD_DEVELOPER
{-# OPTIONS_GHC  -fno-warn-warnings-deprecations #-}
#endif

module Test.WebDriver.Session
  ( -- * WDSessionState class
    WDSessionState(..), WDSessionStateIO, WDSessionStateControl, modifySession, withSession
    -- ** WebDriver sessions
  , WDSession(..), mostRecentHistory, mostRecentHTTPRequest, SessionId(..), SessionHistory(..)
    -- * SessionHistoryConfig options
  , SessionHistoryConfig, noHistory, unlimitedHistory, onlyMostRecentHistory
  ) where

import Test.WebDriver.Session.History

import Data.Aeson
import Data.ByteString as BS(ByteString) 
import Data.Text (Text)
import Data.Maybe (listToMaybe)

import Control.Applicative
import Control.Monad.Base
import Control.Monad.Trans.Class
import Control.Monad.Trans.Control
import Control.Monad.Trans.Maybe
import Control.Monad.Trans.Identity
import Control.Monad.Trans.List
import Control.Monad.Trans.Reader
import Control.Monad.Trans.Error
--import Control.Monad.Cont
import Control.Monad.Trans.Writer.Strict as SW
import Control.Monad.Trans.Writer.Lazy as LW
import Control.Monad.Trans.State.Strict as SS
import Control.Monad.Trans.State.Lazy as LS
import Control.Monad.Trans.RWS.Strict as SRWS
import Control.Monad.Trans.RWS.Lazy as LRWS

import Control.Exception.Lifted (SomeException, try, throwIO)

--import Network.HTTP.Types.Header (RequestHeaders)
import Network.HTTP.Client (Manager, Request)

import Prelude -- hides some "unused import" warnings

{- |An opaque identifier for a WebDriver session. These handles are produced by
the server on session creation, and act to identify a session in progress. -}
newtype SessionId = SessionId Text
                  deriving (Eq, Ord, Show, Read, FromJSON, ToJSON)

{- |The local state of a WebDriver session. This structure is passed
implicitly through all 'WD' computations -}
data WDSession = WDSession {
                             -- server hostname
                             wdSessHost :: BS.ByteString
                             -- server port
                           , wdSessPort :: Int
                             -- Base path for API requests
                           , wdSessBasePath :: BS.ByteString
                             -- |An opaque reference identifying the session to
                             -- use with 'WD' commands.
                             -- A value of Nothing indicates that a session
                             -- hasn't been created yet.
                             -- Sessions can be created within 'WD' via
                             -- 'Test.WebDriver.createSession', or created
                             -- automatically with 'Test.WebDriver.runSession'
                           , wdSessId   :: Maybe SessionId
                             -- |The complete history of HTTP requests and
                             -- responses, most recent first.
                           , wdSessHist :: [SessionHistory]
                             -- |Update function used to append new entries to session history
                           , wdSessHistUpdate :: SessionHistoryConfig
                             -- |HTTP 'Manager' used for connection pooling by the http-client library.
                           , wdSessHTTPManager :: Manager
                             -- |Number of times to retry a HTTP request if it times out
                           , wdSessHTTPRetryCount :: Int
                           --, wdSessRequestHeaders :: RequestHeaders
                           }


-- |A function used by 'wdHistoryConfig' to append new entries to session history.
type SessionHistoryConfig = SessionHistory -> [SessionHistory] -> [SessionHistory]

-- |No session history is saved.
noHistory :: SessionHistoryConfig
noHistory _ _ = []

-- |Keep unlimited history
unlimitedHistory :: SessionHistoryConfig
unlimitedHistory = (:)

-- |Saves only the most recent history
onlyMostRecentHistory :: SessionHistoryConfig
onlyMostRecentHistory h _ = [h]

-- |A class for monads that carry a WebDriver session with them. The
-- MonadBaseControl superclass is used for exception handling through
-- the lifted-base package.
class (Monad m, Applicative m) => WDSessionState m where
  
  -- |Retrieves the current session state of the monad
  getSession :: m WDSession
  
  -- |Sets a new session state for the monad
  putSession :: WDSession -> m ()

-- |Constraint synonym for the common pairing of 'WDSessionState' and 'MonadBase' 'IO'.
type WDSessionStateIO s = (WDSessionState s, MonadBase IO s)

-- |Constraint synonym for another common pairing of 'WDSessionState' and 'MonadBaseControl' 'IO'. This
-- is commonly used in library types to indicate use of lifted exception handling.
type WDSessionStateControl s = (WDSessionState s, MonadBaseControl IO s) 

modifySession :: WDSessionState s => (WDSession -> WDSession) -> s ()
modifySession f = getSession >>= putSession . f

-- |Locally sets a session state for use within the given action.
-- The state of any outside action is unaffected by this function.
-- This function is useful if you need to work with multiple sessions simultaneously.
withSession :: WDSessionStateControl m => WDSession -> m a -> m a
withSession s m = do
  s' <- getSession
  putSession s
  (a :: Either SomeException a) <- try m
  putSession s'
  either throwIO return a

-- |The most recent SessionHistory entry recorded by this session, if any.
mostRecentHistory :: WDSession -> Maybe SessionHistory
mostRecentHistory = listToMaybe . wdSessHist
    
-- |The most recent HTTP request issued by this session, if any.
mostRecentHTTPRequest :: WDSession -> Maybe Request
mostRecentHTTPRequest = fmap histRequest . mostRecentHistory

                            
instance WDSessionState m => WDSessionState (LS.StateT s m) where
  getSession = lift getSession
  putSession = lift . putSession
  
instance WDSessionState m => WDSessionState (SS.StateT s m) where
  getSession = lift getSession
  putSession = lift . putSession
    
instance WDSessionState m => WDSessionState (MaybeT m) where
  getSession = lift getSession
  putSession = lift . putSession

instance WDSessionState m => WDSessionState (IdentityT m) where
  getSession = lift getSession
  putSession = lift . putSession

instance WDSessionState m => WDSessionState (ListT m) where
  getSession = lift getSession
  putSession = lift . putSession
  
instance (Monoid w, WDSessionState m) => WDSessionState (LW.WriterT w m) where
  getSession = lift getSession
  putSession = lift . putSession

instance (Monoid w, WDSessionState m) => WDSessionState (SW.WriterT w m) where
  getSession = lift getSession
  putSession = lift . putSession
  
instance WDSessionState m => WDSessionState (ReaderT r m) where
  getSession = lift getSession
  putSession = lift . putSession
  
instance (Error e, WDSessionState m) => WDSessionState (ErrorT e m) where
  getSession = lift getSession
  putSession = lift . putSession
  
instance (Monoid w, WDSessionState m) => WDSessionState (SRWS.RWST r w s m) where
  getSession = lift getSession
  putSession = lift . putSession
  
instance (Monoid w, WDSessionState wd) => WDSessionState (LRWS.RWST r w s wd) where
  getSession = lift getSession
  putSession = lift . putSession
