{-# LANGUAGE DeriveGeneric #-}

module Config (Config(..), stdCfg, decodeConfig, encodeConfig) where

import GHC.Generics (Generic)
import Data.Aeson (ToJSON, FromJSON, decode, encode)
import Data.ByteString.Lazy (ByteString)

data Config = Config
    { options     :: [String]
    , javaPath    :: String
    , maxRam      :: Int
    , startRam    :: Int
    , jarPath     :: String
    , guiMode     :: Bool
    , tmuxSession :: String
    } deriving Generic

instance Show Config where
    show :: Config -> String
    show cfg = (javaPath cfg)
        ++ " "
        ++ "-Xms"
        ++ (show (startRam cfg)) ++ "G "
        ++ "-Xmx"
        ++ (show (maxRam cfg)) ++ "G"
        ++ optionToStr (options cfg)
        ++ " -jar " ++ jarPath cfg
        ++ if guiMode cfg then " " else " nogui "
        where
          optionToStr :: [String] -> String
          optionToStr (x:xs) = " -XX:" ++ x ++ " " ++ optionToStr xs
          optionToStr [] = ""

instance ToJSON   Config
instance FromJSON Config

stdCfg :: Config
stdCfg = Config
    { options     = []
    , javaPath    = "/usr/bin/java"
    , guiMode     = False
    , maxRam      = 2
    , startRam    = 2
    , jarPath     = "purpur.jar"
    , tmuxSession = "minecraft"
    }

decodeConfig :: ByteString -> Maybe Config
decodeConfig = decode

encodeConfig :: Config -> ByteString
encodeConfig = encode
