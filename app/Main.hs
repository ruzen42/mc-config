{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import           Config                   (Config (tmuxSession), stdCfg, encodeConfig, decodeConfig)
import           Control.Monad            (unless, when)
import           Data.Char                (toLower)
import           Install                  (downloadVersion, interactiveDownload)
import           Options.Applicative
import           System.Directory         (doesFileExist)
import           System.Exit              (exitFailure, exitSuccess)
import           System.IO                (BufferMode (NoBuffering),
                                           hSetBuffering, stdout)
import           Tmux                     (runTmux, sendTmux, stopTmux)
import           Logger                   (successLog, unnecessaryLog, errorLog)
import qualified Data.Text.IO             as TIO
import           Data.Text                (pack)
import           Rainbow                  (chunk)

data Command
    = Start     FilePath        -- --start [cfg-path]
    | Show      FilePath        -- --show [cfg-path]
    | Stop      String          -- --stop  [session-name]
    | GetPurpur (Maybe String)  -- --get-purpur [version]
    | Send      String String   -- --send <session> <command>
    deriving Show

-- --start [CONFIG]   default: mine.cfg
startCmd :: Parser Command
startCmd = Start <$>
    ( flag' ()
        (  long "start"
        <> short 's' 
        <> help "start the Minecraft server"
        )
    *> strArgument
        (  metavar "CONFIG"
        <> value   "mine.cfg"
        <> showDefault
        <> help    "path to config file"
        )
    )

showCmd :: Parser Command
showCmd = Show <$>
    ( flag' ()
        (  long "show"
        <> short 'o'
        <> help "show config"
        )
    *> strArgument
        (  metavar "CONFIG"
        <> value   "mine.cfg"
        <> showDefault
        <> help    "path to config file"
        )
    )

-- --stop [SESSION]   default: minecraft
stopCmd :: Parser Command
stopCmd = Stop <$>
    ( flag' ()
        (  long "stop"
        <> short 't' 
        <> help "stop the Minecraft server (sends /stop in tmux session)"
        )
    *> strArgument
        (  metavar "SESSION"
        <> value   "minecraft"
        <> showDefault
        <> help    "tmux session name"
        )
    )

-- --get-purpur [VERSION]   optional; if omitted → interactive selection
getPurpurCmd :: Parser Command
getPurpurCmd = GetPurpur <$>
    ( flag' ()
        (  long "get-purpur"
        <> short 'g' 
        <> help "download a Purpur build (omit version for interactive selection)"
        )
    *> optional (strArgument
        (  metavar "VERSION"
        <> help    "version to download, e.g. 26.2"
        ))
    )

-- --send <SESSION> <COMMAND>   required

sendCmd :: Parser Command
sendCmd =
    flag' ()
        (  long  "send"
        <> short 'S'
        <> help  "send a command to the running server via tmux"
        )
    *> (Send
        <$> strArgument
                (  metavar "SESSION"
                <> value   "minecraft"
                <> showDefault
                <> help    "tmux session to send the command to"
                )
        <*> strArgument
                (  metavar "COMMAND"
                <> help    "server command"
                ))

commands :: Parser Command
commands = startCmd <|> stopCmd <|> getPurpurCmd <|> sendCmd <|> showCmd

opts :: ParserInfo Command
opts = info (commands <**> helper)
    (  fullDesc
    <> header   "mc-config - minecraft server tool"
    <> progDesc "start/stop a Purpur server, download builds, send commands in tmux session"
    )

main :: IO ()
main = do
    hSetBuffering stdout NoBuffering
    unnecessaryLog "2026 Ruzen42 MIT License (Minecraft configurator v1.3.0.0)"
    cmd <- execParser opts
    case cmd of
        Start     cfgPath -> runWithConfig True cfgPath
        Stop      session -> stopTmux session
        GetPurpur mver    -> case mver of
            Nothing         -> interactiveDownload
            Just ver        -> downloadVersion ver
        Send session cmd1 -> sendTmux session cmd1
        Show      cfgPath -> runWithConfig False cfgPath

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
            errorLog $ "invalid config" <> (chunk $ pack err)
            exitFailure
        Right cfg -> do
            print cfg
            putStrLn ""
            TIO.putStrLn file
            when runnable $ runTmux (tmuxSession cfg) (show cfg)
