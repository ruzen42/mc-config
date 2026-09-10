{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Config (Config (tmuxSession), stdCfg, saveConfig, encodeConfig, decodeConfig, generateConfig)
import Data.Char (toLower)
import Install (downloadVersion, interactiveDownload)
import Options.Applicative
import System.IO (getChar)
import System.Directory (doesFileExist, removeFile)
import Tmux (runTmux, sendTmux, stopTmux)
import Logger (successLog, unnecessaryLog, errorLog)
import qualified Data.Text.IO as TIO
import Rainbow (chunk)
import Plugin.Manage (fetchPlugin, searchPlugins, formatSearchResults)
import qualified Data.Text as T
import TextShow (showb, toText)

data Command
    = Start     Text        
    | Show      Text       
    | Stop      Text        
    | GetPurpur (Maybe Text)  
    | Send      Text Text 
    | Plugin    PluginCommand
    | Config    ConfigCommand

data PluginCommand
  = PluginAdd    Text
  | PluginRemove Text
  | PluginSearch Text

data ConfigCommand 
  = Generate Text
  | Standard Text

configCommandGenerate :: Parser ConfigCommand 
configCommandGenerate = Generate <$> argument str
  (  metavar "CONFIG"
  <> showDefault
  <> value "mconfig.dhall"
  <> help "generate config"
  )

configCommandStandard :: Parser ConfigCommand 
configCommandStandard = Standard <$> argument str
  (  metavar "CONFIG"
  <> showDefault
  <> value "mconfig.dhall"
  <> help "standard config"
  )

configCommand :: Parser ConfigCommand 
configCommand = hsubparser 
  (  command "generate" (info configCommandGenerate (progDesc "generate config for this system"))
  <> command "standard" (info configCommandStandard (progDesc "standard config"))
  )

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

pluginSearchCmd :: Parser PluginCommand
pluginSearchCmd = PluginSearch . T.pack <$> argument str
  (  metavar "PLUGIN"
  <> help "plugin name to search for"
  )

pluginSubparser :: Parser PluginCommand 
pluginSubparser = hsubparser
  (  command "add"    (info pluginAddCmd    (progDesc "search and download plugin (interactive if multiple matches)"))
  <> command "remove" (info pluginRemoveCmd (progDesc "remove plugin"))
  <> command "search" (info pluginSearchCmd (progDesc "search plugins without downloading"))
  )

startCmd :: Parser Command
startCmd = Start <$> argument str
  (  metavar "CONFIG"
  <> value   "mconfig.dhall"
  <> showDefault
  <> help    "path to config file"
  )

showCmd :: Parser Command
showCmd = Show <$> argument str
  (  metavar "CONFIG"
  <> value   "mconfig.dhall"
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
    <> command "config"     (info (Config <$> configCommand) (progDesc "config management"))
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
        Plugin (PluginSearch name) -> do
            res <- searchPlugins name
            case res of
                Left err     -> errorLog (chunk err)
                Right plugins -> mapM_ TIO.putStrLn (formatSearchResults plugins)
        Config (Generate name) -> do
          res <- generateConfig
          case res of
              Left err  -> errorLog (chunk err)
              Right cfg -> saveConfig cfg name
        Config (Standard name) -> saveConfig stdCfg name
                
runWithConfig :: Bool -> Text -> IO ()
runWithConfig runnable configPath = do
    let pathStr = T.unpack configPath
    exists <- doesFileExist pathStr

    unless exists $ do
        TIO.putStr $ "file " <> configPath <> " not found. Create new? [Y/n]: "
        answer <- getChar 
        if toLower answer /= 'n'
            then do
                TIO.writeFile pathStr (encodeConfig stdCfg)
                TIO.writeFile "eula.txt" "eula=true"
                unnecessaryLog "created: eula.txt -> eula=true" 
                successLog "created new config: "
                TIO.putStrLn configPath
            else exitSuccess

    TIO.putStrLn $ "processed with config: " <> configPath
    file <- TIO.readFile pathStr

    decoded <- decodeConfig file 
    TIO.putStrLn $ config2Text decoded
    let dSession = tmuxSession decoded
    case dSession of
      Just session -> when runnable $ runTmux session (config2Text decoded)
      Nothing -> pure ()
    where 
      config2Text :: Config -> Text
      config2Text input = TextShow.toText $ showb input
