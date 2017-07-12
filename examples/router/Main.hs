{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeFamilies #-}
module Main where

import Data.Proxy
import Servant.API

import Miso

-- | Model
data Model
  = Model
  { uri :: URI
    -- ^ current URI of application
  } deriving (Eq, Show)

-- | HasURI typeclass
instance HasURI Model where
  lensURI = makeLens getter setter
    where
      getter = uri
      setter = \m u -> m { uri = u }

-- | Action
data Action
  = HandleURI URI
  | ChangeURI URI
  | NoOp
  deriving (Show, Eq)

-- | Main entry point
main :: IO ()
main = do
  currentURI <- getCurrentURI
  startApp App { model = Model currentURI, ..}
  where
    update = updateModel
    events = defaultEvents
    subs   = [ uriSub HandleURI ]
    view   = viewModel

-- | Update your model
updateModel :: Action -> Model -> Effect Model Action
updateModel (HandleURI u) m = m { uri = u } <# do
  pure NoOp
updateModel (ChangeURI u) m = m <# do
  pushURI u
  pure NoOp
updateModel _ m = noEff m

-- | View function, with routing
viewModel :: Model -> View Action
viewModel model@Model {..} = view
  where
    view = either (const the404) id result
    result = runRoute (Proxy :: Proxy API) handlers model
    handlers = about :<|> home
    home (_ :: Model) = div_ [] [
        div_ [] [ text "home" ]
      , button_ [ onClick goAbout ] [ text "go about" ]
      ]
    about (_ :: Model) = div_ [] [
        div_ [] [ text "about" ]
      , button_ [ onClick goHome ] [ text "go home" ]
      ]
    the404 = div_ [] [
        text "the 404 :("
      , button_ [ onClick goHome ] [ text "go home" ]
      ]

-- | Type-level routes
type API   = About :<|> Home
type Home  = View Action
type About = "about" :> View Action

-- | Type-safe links used in `onClick` event handlers to route the application
goAbout, goHome :: Action
(goHome, goAbout) = (goto api home, goto api about)
  where
    goto a b = ChangeURI (safeLink a b)
    home  = Proxy :: Proxy Home
    about = Proxy :: Proxy About
    api   = Proxy :: Proxy API

