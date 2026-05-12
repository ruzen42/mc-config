{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import           Config                   (Config (tmuxSession), stdCfg, encodeConfig, decodeConfig)
import           Control.Monad            (unless)
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
import           Data.Text (pack)
import Rainbow (chunk)

data Command
    = Start     FilePath        -- --start [cfg-path]
    | Stop      String          -- --stop  [session-name]
    | GetPurpur (Maybe String)  -- --get-purpur [version]
    | Send      String          -- --send <command>
    deriving Show

-- --start [CONFIG]   default: mine.cfg
startCmd :: Parser Command
startCmd = Start <$>
    ( flag' ()
        (  long "start"
        <> help "Start the Minecraft server"
        )
    *> strArgument
        (  metavar "CONFIG"
        <> value   "mine.cfg"
        <> showDefault
        <> help    "Path to config file"
        )
    )

-- --stop [SESSION]   default: minecraft
stopCmd :: Parser Command
stopCmd = Stop <$>
    ( flag' ()
        (  long "stop"
        <> help "Stop the Minecraft server (sends /stop via tmux)"
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
        <> help "Download a Purpur build (omit version for interactive selection)"
        )
    *> optional (strArgument
        (  metavar "VERSION"
        <> help    "Purpur version to download, e.g. 26.1.2"
        ))
    )

-- --send <COMMAND>   required
sendCmd :: Parser Command
sendCmd = Send <$>
    ( flag' ()
        (  long "send"
        <> help "Send a command to the running server via tmux"
        )
    *> strArgument
        (  metavar "COMMAND"
        <> help    "Server command to send, e.g. \"say hello\""
        )
    )

commands :: Parser Command
commands = startCmd <|> stopCmd <|> getPurpurCmd <|> sendCmd

opts :: ParserInfo Command
opts = info (commands <**> helper)
    (  fullDesc
    <> header   "mc-config - Minecraft server manager"
    <> progDesc "Start/stop a Purpur server, download builds, send commands"
    )

main :: IO ()
main = do
    hSetBuffering stdout NoBuffering
    unnecessaryLog "2026 Ruzen42 MIT License (Minecraft configurator v1.0.0.0)"
    cmd <- execParser opts
    case cmd of
        Start     cfgPath -> runWithConfig cfgPath
        Stop      session -> stopTmux session
        GetPurpur mver    -> case mver of
            Nothing         -> interactiveDownload
            Just ver        -> downloadVersion ver
        Send      cmd1    -> sendTmux "minecraft" cmd1

runWithConfig :: FilePath -> IO ()
runWithConfig configPath = do
    exists <- doesFileExist configPath

    unless exists $ do
        putStr $ "File " ++ configPath ++ " not found. Create new? [Y/n]: "
        answer <- getLine
        if map toLower answer /= "n"
            then do
                writeFile configPath (encodeConfig stdCfg)
                TIO.writeFile "eula.txt" "eula=true"
                successLog $ "Created new config: "
                putStrLn configPath
            else exitSuccess

    putStrLn $ "Processed with config: " ++ configPath
    file <- TIO.readFile configPath

    case decodeConfig file of
        Left err -> do
            errorLog $ "invalid config" <> (chunk $ pack err)
            exitFailure
        Right cfg -> print cfg >> runTmux (tmuxSession cfg) (show cfg)
