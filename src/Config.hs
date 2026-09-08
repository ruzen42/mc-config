{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE DeriveAnyClass    #-}

module Config (Config (..), stdCfg, decodeConfig, encodeConfig) where

import Dhall
import Dhall.Core as DH
import qualified Dhall.Marshal.Encode as ME 

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

instance Show Config where
    show cfg =
        (T.unpack (javaPath cfg))
        ++ " -Xms" ++ show (startRam cfg) ++ "G"
        ++ " -Xmx" ++ show (maxRam   cfg) ++ "G"
        ++ T.unpack (formatTextOptions $ options cfg)
        ++ " -jar " ++ (T.unpack (jarPath cfg))
        ++ if guiMode cfg then " " else " nogui"
      where
        formatTextOptions :: [Text] -> Text
        formatTextOptions []     = ""
        formatTextOptions (x:xs) = " -XX:" <> x <> formatTextOptions xs

decodeConfig :: Text -> IO Config
decodeConfig raw = input auto raw 

encodeConfig :: Config -> Text
encodeConfig config = DH.pretty (embed ME.inject config)

stdCfg :: Config
stdCfg = Config
    { options     = []
    , javaPath    = "/usr/bin/java"
    , jarPath     = "purpur.jar"
    , startRam    = 2
    , maxRam      = 2
    , guiMode     = False
    , tmuxSession = Nothing 
    }
