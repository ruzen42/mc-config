{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Config (Config (tmuxSession), stdCfg, encodeConfig, decodeConfig)
import Control.Monad (unless, when)
import Data.Char (toLower)
import Install (downloadVersion, interactiveDownload)
import Options.Applicative
import System.Directory (doesFileExist, removeFile)
import System.Exit (exitFailure, exitSuccess)
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)
import Tmux (runTmux, sendTmux, stopTmux)
import Logger (successLog, unnecessaryLog, errorLog)
import qualified Data.Text.IO as TIO
import Data.Text (Text)
import Rainbow (chunk)
import Plugin.Manage (fetchPlugin)
import qualified Data.Text as T

data Command
    = Start     FilePath        
    | Show      FilePath       
    | Stop      String        
    | GetPurpur (Maybe String)  
    | Send      String String  
    | Plugin    PluginCommand

data PluginCommand
  = PluginAdd    Text
  | PluginRemove Text


pluginAddCmd :: Parser PluginCommand
pluginAddCmd = PluginAdd . T.pack <$> argument str
  (  metavar "PLUGIN"
  <> help "plugin name for downloading"
  )

pluginRemoveCmd :: Parser PluginCommand 
pluginRemoveCmd = PluginRemove . T.pack <$> argument str
  (  metavar "PLUGIN"
  <> help "plugin name for removing"
  )

pluginSubparser :: Parser PluginCommand 
pluginSubparser = hsubparser
  (  command "add" (info pluginAddCmd (progDesc "download plugin"))
  <> command "remove" (info pluginRemoveCmd (progDesc "remove plugin"))
  )

startCmd :: Parser Command
startCmd = Start <$> argument str
  (  metavar "CONFIG"
  <> value   "mconfig.toml"
  <> showDefault
  <> help    "path to config file"
  )

showCmd :: Parser Command
showCmd = Show <$> argument str
  (  metavar "CONFIG"
  <> value   "mconfig.toml"
  <> showDefault
  <> help    "path to config file"
  )

stopCmd :: Parser Command
stopCmd = Stop <$> argument str
  (  metavar "SESSION"
  <> value   "minecraft"
  <> showDefault
  <> help    "tmux session name"
  )

getPurpurCmd :: Parser Command
getPurpurCmd = GetPurpur <$> optional (argument str
  (  metavar "VERSION"
  <> help    "version to download, e.g. 26.2"
  ))

sendCmd :: Parser Command
sendCmd = Send
    <$> argument str
        (  metavar "SESSION"
        <> value "minecraft"
        <> showDefault
        <> help "tmux session name"
        )
    <*> argument str
        (  metavar "COMMAND"
        <> help "command for server"
        )

commands :: Parser Command
commands = hsubparser
    (  command "start"      (info startCmd     (progDesc "start server"))
    <> command "show"       (info showCmd      (progDesc "show config"))
    <> command "stop"       (info stopCmd      (progDesc "stop server"))
    <> command "get-purpur" (info getPurpurCmd (progDesc "get Purpur build"))
    <> command "send"       (info sendCmd      (progDesc "send command to tmux session"))
    <> command "plugin"     (info (Plugin <$> pluginSubparser) (progDesc "plugin management"))
    )

opts :: ParserInfo Command
opts = info (commands <**> helper)
    (  fullDesc
    <> header   "mc-config - minecraft server tool"
    <> progDesc "start/stop a Purpur server, download builds, send commands in tmux session"
    )

main :: IO ()
main = do
    hSetBuffering stdout NoBuffering
    unnecessaryLog "2026 MIT License (https://github.com/ruzen42/mc-config v2.0)"
    cmd <- execParser opts
    case cmd of
        Start cfgPath      -> runWithConfig True cfgPath
        Show cfgPath       -> runWithConfig False cfgPath
        Stop session       -> stopTmux session
        GetPurpur mver     -> case mver of
            Nothing  -> interactiveDownload
            Just ver -> downloadVersion ver
        Send session cmd1  -> sendTmux session cmd1
        Plugin (PluginAdd name) -> do
            res <- fetchPlugin name
            case res of
                Left err -> errorLog (chunk err)
                Right msg -> successLog (chunk msg)
        Plugin (PluginRemove name) -> removeFile $ T.unpack name 

-- bool indicates whether to run the config after loading
runWithConfig :: Bool -> FilePath -> IO ()
runWithConfig runnable configPath = do
    exists <- doesFileExist configPath

    unless exists $ do
        putStr $ "file " ++ configPath ++ " not found. Create new? [Y/n]: "
        answer <- getChar
        if toLower answer /= 'n'
            then do
                writeFile configPath (encodeConfig stdCfg)
                TIO.writeFile "eula.txt" "eula=true"
                unnecessaryLog $ "created: eula.txt -> eula=true" 
                successLog $ "created new config: "
                putStrLn configPath
            else exitSuccess

    putStrLn $ "processed with config: " ++ configPath
    file <- TIO.readFile configPath

    case decodeConfig file of
        Left err -> do
            errorLog $ "invalid config" <> (chunk $ T.pack err)
            exitFailure
        Right cfg -> do
            print cfg
            putStrLn ""
            TIO.putStrLn file
            when runnable $ runTmux (tmuxSession cfg) (show cfg)
