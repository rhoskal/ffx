module Api.Environment
  ( Environment,
    get,
  )
where

import Api.Id (AccountId, EnvironmentId)
import Api.Id qualified as Id
import Data.Aeson (FromJSON (..), (.:), (.:?))
import Data.Aeson qualified as J
import Data.Version qualified as V
import Network.HTTP.Simple
  ( JSONException,
    Request,
  )
import Network.HTTP.Simple qualified as HTTP
import Network.HTTP.Types.Header as Header
import Paths_ffx qualified as Meta
import RIO
import RIO.Text qualified as T
import Types

data Environment = Environment
  { envId :: !EnvironmentId,
    envAccountId :: !(Maybe AccountId),
    envName :: !Text,
    envIsProd :: !Bool,
    envGuestAuth :: ![Text]
  }
  deriving (Eq, Show)

instance FromJSON Environment where
  parseJSON = J.withObject "Environment" $ \o -> do
    obj <- o .: "data"
    Environment
      <$> (obj .: "id")
      <*> (obj .:? "accountId")
      <*> (obj .: "name")
      <*> (obj .: "isProd")
      <*> (obj .: "guestAuthentication")

buildRequest :: App -> EnvironmentId -> Request
buildRequest env envId =
  HTTP.setRequestHost host $
    HTTP.setRequestPort 443 $
      HTTP.setRequestSecure True $
        HTTP.setRequestPath path $
          HTTP.setRequestHeaders
            [ (Header.hAuthorization, T.encodeUtf8 $ "Bearer " <> flatfileSecretKey),
              (Header.hUserAgent, T.encodeUtf8 $ T.pack $ "ffx v" <> V.showVersion Meta.version)
            ]
            HTTP.defaultRequest
  where
    host :: ByteString
    host = "platform.flatfile.com"

    path :: ByteString
    path = T.encodeUtf8 $ "api/v1/environments/" <> Id.unEnvironmentId envId

    flatfileSecretKey :: Text
    flatfileSecretKey = view flatfileSecretKeyL env

get :: EnvironmentId -> RIO App (Either JSONException Environment)
get envId = do
  env <- ask
  response <- HTTP.httpJSONEither $ buildRequest env envId
  logDebug $ displayShow response
  return $ HTTP.getResponseBody response
