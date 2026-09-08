{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE DeriveAnyClass    #-}

module Config (Config (..), stdCfg, decodeConfig, encodeConfig, generateConfig) where

import Dhall
import Dhall.Core as DH
import qualified Dhall.Marshal.Encode as ME 
import TextShow (TextShow(..), Builder, showb, fromText)
import System.Directory (findExecutable)
import System.SysInfo (sysInfo, SysInfo (totalram))
import qualified Data.Text as T

data Config = Config
    { options     :: [Text]
    , javaPath    :: Text
    , maxRam      :: Int
    , startRam    :: Int
    , jarPath     :: Text
    , guiMode     :: Bool
    , tmuxSession :: Maybe Text
    } deriving (Eq, Generic, ToDhall, FromDhall)

instance TextShow Config where
  showb cfg =
       fromText (javaPath cfg)
    <> " -Xms" <> showb (startRam cfg) <> "G"
    <> " -Xmx" <> showb (maxRam cfg) <> "G"
    <> formatTextOptions (options cfg)
    <> " -jar " <> fromText (jarPath cfg)
    <> if guiMode cfg then " " else " nogui"
    where
      formatTextOptions :: [Text] -> Builder
      formatTextOptions = foldMap (\opt -> " -XX:" <> fromText opt)

decodeConfig :: Text -> IO Config
decodeConfig raw = input auto raw 

encodeConfig :: Config -> Text
encodeConfig config = DH.pretty $ embed ME.inject config

getTotalRamMB :: IO Int
getTotalRamMB = do
    info <- sysInfo
    -- bytes -> gibibytes
    pure $ (totalram info) `div` (1024 * 1024) -- freeram maybe


generateConfig :: IO (Either Text Config)
generateConfig = do
  maybeExe <- findExecutable "java" 
  case maybeExe of
    Just exe -> 
      total <- getTotalRamMB
      Right $ Config 
        { options     = []
        , javaPath    = (T.pack exe)
        , jarPath     = "purpur.jar"
        , startRam    = total / 2 - 2 
        , maxRam      = total - 2 
        , guiMode     = False
        , tmuxSession = Nothing 
        }
    Nothing -> Left "java not found in $PATH"

stdCfg :: Config
stdCfg = Config
    { options     = []
    , javaPath    = "/usr/bin/java"
    , jarPath     = "purpur.jar"
    , startRam    = 2
    , maxRam      = 4
    , guiMode     = False
    , tmuxSession = Nothing 
    }
