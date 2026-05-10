{-# LANGUAGE DeriveGeneric #-}

module Config (Config(..), stdCfg, execConfig) where 

import GHC.Generics (Generic)
import Data.Aeson (ToJSON, FromJSON)
import System.Process 
import Control.Exception (try, IOException)

data Config = Config 
    { options  :: [String]
    , javaPath :: String 
    , maxRam   :: Int
    , startRam :: Int
    , jarPath  :: String
    , guiMode  :: Bool
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
    { options  = []
    , javaPath = "/usr/bin/java"
    , guiMode  = False
    , maxRam   = 2
    , startRam = 2 
    , jarPath  = "paper.jar"
    }

execConfig :: Config -> IO ()
execConfig cfg = do 
  let cmd = shell $ show cfg
  raw <- try $ readCreateProcess cmd "" :: IO (Either IOException String)
  case raw of 
    Right a -> putStrLn a 
    Left  e -> putStrLn $ "Java Error: " ++ show e
