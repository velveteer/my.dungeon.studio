module Auth0.Eval
( runAuth0
) where

import Prelude
import Control.Monad.Aff (Aff(), attempt)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Eff.Now (NOW, now)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Functor.Variant (case_, on)
import Data.DateTime.Instant (unInstant)
import Data.Time.Duration (Milliseconds(..))
import Data.Newtype (unwrap)
import DOM (DOM)
import DOM.WebStorage (STORAGE, getItem, setItem, getLocalStorage)
import Run (Run, interpret)

import Auth0 (WebAuth, AUTH0EFF, Session(..), authorize, parseHash, sessionKey)
import Auth0.Algebra (Auth0DSLF(..), AUTH0, _auth0)

runAuth0
  :: forall eff
   . WebAuth
  -> Run ( auth0 :: AUTH0 )
  ~> Aff ( auth0 :: AUTH0EFF, dom :: DOM, storage :: STORAGE, now :: NOW | eff )
runAuth0 wa = interpret (case_ # on _auth0 (handleAuth0 wa))

handleAuth0
  :: forall eff
   . WebAuth
  -> Auth0DSLF
  ~> Aff ( auth0 :: AUTH0EFF, dom :: DOM, storage :: STORAGE, now :: NOW | eff )
handleAuth0 wa (Ask a) = pure (a wa)
handleAuth0 wa (Authorize a) = do
  liftEff $ authorize wa
  pure a
handleAuth0 wa (GetSession a) = do
  ls <- liftEff getLocalStorage
  session <- liftEff $ getItem ls sessionKey
  pure (a session)
handleAuth0 wa (SetSession (Session session) a) = do
  time <- liftEff now
  let s = Session $ session{ expiresAt = unwrap $ (unInstant time) + (Milliseconds session.expiresIn) }
  ls <- liftEff getLocalStorage
  liftEff $ setItem ls sessionKey s
  pure a
handleAuth0 wa (ParseHash a) = do
  session <- attempt $ parseHash wa
  case session of
    Left _ -> pure $ a Nothing
    Right s -> do
      ls <- liftEff $ getLocalStorage
      liftEff $ setItem ls sessionKey s
      pure $ a (Just s)
handleAuth0 wa (CheckAuth a) = do
  pure (a true)
  {-- ls <- liftEff $ getLocalStorage --}
  {-- session <- liftEff $ getItem ls sessionKey --}
  {-- var expiresAt = JSON.parse(localStorage.getItem('expires_at')); --}
  {--   return new Date().getTime() < expiresAt; --}