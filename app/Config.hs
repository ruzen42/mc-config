
{-# LANGUAGE OverloadedStrings #-}

module Config (Config (..), stdCfg, decodeConfig, encodeConfig) where

import           Data.Maybe        (fromMaybe)
import           Toml              (decode, encode, Result (Failure, Success))
import           Toml.Schema       (FromValue (..), ToTable (..), ToValue (..),
                                    defaultTableToValue, optKey, parseTableFromValue,
                                    reqKey, table, (.=))
import           Data.Text         (Text)


data Config = Config
    { options     :: [String]
    , javaPath    :: String
    , maxRam      :: Int
    , startRam    :: Int
    , jarPath     :: String
    , guiMode     :: Bool
    , tmuxSession :: String
    } deriving (Eq)

instance Show Config where
    show cfg =
        javaPath cfg
        ++ " -Xms" ++ show (startRam cfg) ++ "G"
        ++ " -Xmx" ++ show (maxRam   cfg) ++ "G"
        ++ optionToStr (options cfg)
        ++ " -jar " ++ jarPath cfg
        ++ if guiMode cfg then " " else " nogui"
      where
        optionToStr []     = ""
        optionToStr (x:xs) = " -XX:" ++ x ++ optionToStr xs

instance FromValue Config where
    fromValue = parseTableFromValue $ do
        jp  <- reqKey "java_path"
        jr  <- reqKey "jar_path"
        sr  <- reqKey "start_ram"
        mr  <- reqKey "max_ram"
        gui <- reqKey "gui_mode"
        ts  <- reqKey "tmux_session"
        ops <- fromMaybe [] <$> optKey "options"
        pure Config
            { javaPath    = jp
            , jarPath     = jr
            , startRam    = sr
            , maxRam      = mr
            , guiMode     = gui
            , tmuxSession = ts
            , options     = ops
            }

instance ToValue Config where
    toValue = defaultTableToValue

instance ToTable Config where
    toTable cfg = table
        [ "java_path"    .= javaPath    cfg
        , "jar_path"     .= jarPath     cfg
        , "start_ram"    .= startRam    cfg
        , "max_ram"      .= maxRam      cfg
        , "gui_mode"     .= guiMode     cfg
        , "tmux_session" .= tmuxSession cfg
        , "options"      .= options     cfg
        ]

decodeConfig :: Text -> Either String Config
decodeConfig raw = case decode raw of
    Failure (x:_)     -> Left x
    Failure []         -> Left "unknown error"
    Success _ cfg   -> Right cfg

encodeConfig :: Config -> String
encodeConfig = show . encode

stdCfg :: Config
stdCfg = Config
    { options     = []
    , javaPath    = "/usr/bin/java"
    , jarPath     = "purpur.jar"
    , startRam    = 2
    , maxRam      = 2
    , guiMode     = False
    , tmuxSession = "minecraft"
    }
