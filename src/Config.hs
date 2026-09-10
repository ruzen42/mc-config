{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE DeriveAnyClass    #-}

module Config (Config (..), stdCfg, saveConfig, decodeConfig, encodeConfig, generateConfig) where

import Dhall
import Dhall.Core as DH
import qualified Dhall.Marshal.Encode as ME 
import TextShow (TextShow(..), Builder, showb, fromText)
import System.Directory (findExecutable, getCurrentDirectory, listDirectory, doesFileExist)
import System.SysInfo (sysInfo, SysInfo (totalram, memUnit))
import qualified Data.Text as T
import Control.Exception (try, IOException)
import Control.Monad (filterM)
import Data.Maybe (fromMaybe)
import Relude.Numeric (Word64)
import qualified Data.Text.IO as TIO
import Logger (unnecessaryLog, successLog)

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
getTotalRamGiB :: IO Int
getTotalRamGiB = do
  res <- sysInfo
  case res of
    Left _err -> pure 4 
    Right info -> do
      let memUnitVal = fromIntegral (memUnit info) :: Word64
          totalBytes = fromIntegral (totalram info) * memUnitVal
          totalGiB   = totalBytes `div` (1024 * 1024 * 1024)
      pure $ fromIntegral totalGiB

findJarInCurrentDir :: IO (Maybe Text)
findJarInCurrentDir = do
  cwd <- getCurrentDirectory
  files <- listDirectory cwd
  
  let textFiles = Prelude.map T.pack files
      jarFiles  = filter (".jar" `T.isSuffixOf`) textFiles

  existingJars <- filterM (doesFileExist . T.unpack) jarFiles

  pure $ case existingJars of
    (firstJar:_) -> Just firstJar
    []           -> Nothing

saveConfig :: Config -> Text -> IO ()
saveConfig cfg configPath = do 
  TIO.writeFile (T.unpack configPath) (encodeConfig cfg)
  TIO.writeFile "eula.txt" "eula=true"
  unnecessaryLog "created: eula.txt -> eula=true" 
  successLog "created new config: "
  TIO.putStrLn configPath
  

generateConfig :: IO (Either Text Config)
generateConfig = do
  maybeExe <- findExecutable "java" 
  case maybeExe of
    Just exe -> do 
      total <- (try getTotalRamGiB :: IO (Either IOException Int))
      jar <- findJarInCurrentDir  
      let parsedJar = fromMaybe "purpur.jar" jar :: Text 
      case total of 
        Right ram -> 
          pure $ Right $ Config 
            { options = [ "+UseZGC", "+ZGenerational", "+AlwaysPreTouch"]
            , javaPath    = T.pack exe
            , jarPath     = parsedJar
            , startRam    = ram `div` 2 - 2 
            , maxRam      = ram - 2 
            , guiMode     = False
            , tmuxSession = Nothing 
            }
        Left _ -> pure $ Left $ "can`t get total ram" 
    Nothing -> pure $ Left "java not found in $PATH"

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
