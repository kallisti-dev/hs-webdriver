{-# LANGUAGE OverloadedStrings, DeriveDataTypeable, FlexibleContexts, CPP,
             GeneralizedNewtypeDeriving, RecordWildCards, ConstraintKinds #-}
#ifndef CABAL_BUILD_DEVELOPER
{-# OPTIONS_GHC  -fno-warn-warnings-deprecations #-}
#endif
module Test.WebDriver.Class
       ( -- * WebDriver class
         WebDriver(..), Method, methodDelete, methodGet, methodPost,
       ) where
import Test.WebDriver.Session

import Data.Aeson
import Data.Text (Text)

import Network.HTTP.Types.Method (methodDelete, methodGet, methodPost, Method)
import Network.HTTP.Types.Header (RequestHeaders)

import Control.Monad.Trans.Class
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


-- |A class for monads that can handle wire protocol requests. This is the
-- operation underlying all of the high-level commands exported in
-- "Test.WebDriver.Commands". For more information on the wire protocol see
-- <http://code.google.com/p/selenium/wiki/JsonWireProtocol>
class (WDSessionStateControl wd) => WebDriver wd where
  doCommand :: (ToJSON a, FromJSON b) =>
                RequestHeaders -- ^Additional headers
                -> Method      -- ^HTTP request method
                -> Text        -- ^URL of request
                -> a           -- ^JSON parameters passed in the body
                               -- of the request. Note that, as a special case,
                               -- anything that converts to Data.Aeson.Null will
                               -- result in an empty request body.
                -> wd b        -- ^The JSON result of the HTTP request.

instance WebDriver wd => WebDriver (SS.StateT s wd) where
  doCommand rh rm t a = lift (doCommand rh rm t a)

instance WebDriver wd => WebDriver (LS.StateT s wd) where
  doCommand rh rm t a = lift (doCommand rh rm t a)


instance WebDriver wd => WebDriver (MaybeT wd) where
  doCommand rh rm t a = lift (doCommand rh rm t a)

instance WebDriver wd => WebDriver (IdentityT wd) where
  doCommand rh rm t a = lift (doCommand rh rm t a)

instance WebDriver wd => WebDriver (ListT wd) where
  doCommand rh rm t a = lift (doCommand rh rm t a)

instance (Monoid w, WebDriver wd) => WebDriver (LW.WriterT w wd) where
  doCommand rh rm t a = lift (doCommand rh rm t a)

instance (Monoid w, WebDriver wd) => WebDriver (SW.WriterT w wd) where
  doCommand rh rm t a = lift (doCommand rh rm t a)

instance WebDriver wd => WebDriver (ReaderT r wd) where
  doCommand rh rm t a = lift (doCommand rh rm t a)

instance (Error e, WebDriver wd) => WebDriver (ErrorT e wd) where
  doCommand rh rm t a = lift (doCommand rh rm t a)


instance (Monoid w, WebDriver wd) => WebDriver (SRWS.RWST r w s wd) where
  doCommand rh rm t a = lift (doCommand rh rm t a)

instance (Monoid w, WebDriver wd) => WebDriver (LRWS.RWST r w s wd) where
  doCommand rh rm t a = lift (doCommand rh rm t a)
