{-# LANGUAGE LambdaCase          #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE QuasiQuotes         #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell     #-}

module Main where

import qualified Data.ByteString          as B
import qualified Data.ByteString.Char8    as C8
import qualified Data.ByteString.Lazy     as BL
import           Data.Either              (fromRight)
import           Data.Maybe               (fromMaybe)
import qualified Database.Redis           as Redis
import           GHC.Int
import qualified Hasql.Connection         as Hasql
import qualified Hasql.Session            as Hasql
import qualified Hasql.Statement          as Hasql
import           Hasql.TH
import           Network.HTTP.Types
import           Network.Wai
import           Network.Wai.Handler.Warp
import           System.Environment       (getEnv)

main :: IO ()
main = do

  port :: Int <- read <$> getEnv "APP_PORT"
  dbConnStr <- getEnv "DATABASE_URL"

  redisConn <- Redis.checkedConnect Redis.defaultConnectInfo
  sqlConn <- either (error . C8.unpack . fromMaybe "db connection error") id <$> Hasql.acquire (C8.pack dbConnStr)

  run port $ app $ server sqlConn redisConn

app :: (B.ByteString -> IO (Status, BL.ByteString)) -> Application
app handler request sendResponse = do
  (status, bs) <- handler $ rawPathInfo request
  sendResponse $ responseLBS status [(hContentType, "text/plain")] bs

server :: Hasql.Connection -> Redis.Connection -> B.ByteString -> IO (Status, BL.ByteString)
server sqlConn redisConn = \case
  "/"       -> do
    sqlVal <- getSqlValue sqlConn
    redisVal <- getRedisValue redisConn
    pure (ok200, "Current redis value: " <> BL.fromStrict redisVal <> "\nCurrent sql value: " <> (BL.fromStrict . C8.pack . show) sqlVal)
  _         -> pure (notFound404, "not found")

getSqlValue :: Hasql.Connection -> IO Int32
getSqlValue sqlConn = do

  maybeInt <- fmap (either (error . show) id) $ flip Hasql.run sqlConn $
    Hasql.statement () [maybeStatement|
      SELECT intval :: int4
      FROM value
    |]

  case maybeInt of

    Nothing  -> do
      res <- flip Hasql.run sqlConn $ Hasql.statement 0
        [singletonStatement|
          INSERT INTO value (intval)
          VALUES ($1 :: int4)
          RETURNING intval :: int4
        |]

      pure $ unwrap res

    Just int -> do
      res <- flip Hasql.run sqlConn $ Hasql.statement ()
        [singletonStatement|
          UPDATE value SET
          intval = intval + 1 :: int4
          RETURNING intval :: int4
        |]

      pure $ unwrap res


  where
    unwrap :: Either Hasql.QueryError a -> a
    unwrap = \case
      Left err -> error $ show err
      Right a -> a

getRedisValue :: Redis.Connection -> IO B.ByteString
getRedisValue redisConn =
  Redis.runRedis redisConn $ do
    bsVal <- unwrap <$> Redis.get "app:strval"
    case bsVal of
      Nothing -> do
        Redis.set "app:strval" ""
        pure ""
      Just val   -> do
        let newVal = val <> "x"
        _ <- unwrap <$> Redis.set "app:strval" newVal
        pure newVal

  where
    unwrap :: Either Redis.Reply a -> a
    unwrap = \case
      Left err -> error $ show err
      Right val -> val
