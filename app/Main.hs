{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import           Config                     (execConfig, stdCfg)
import           Control.Monad              (unless)
import           Data.Aeson                 (decode)
import           Data.Aeson.Encode.Pretty   (encodePretty)
import           Data.Char                  (toLower)
import qualified Data.ByteString.Lazy       as BL
import           Install                    (interactiveDownload)
import           Options.Applicative
import           System.Directory           (doesFileExist)
import           System.Exit                (exitFailure, exitSuccess)
import           System.IO                  (BufferMode (NoBuffering),
                                             hSetBuffering, stdout)

data Command
    = Download
    | Run FilePath
    deriving Show

downloadCmd :: Parser Command
downloadCmd = flag' Download
    (  long  "download"
    <> short 'd'
    <> help  "Select version and download Purpur"
    )

runCmd :: Parser Command
runCmd = Run <$> strArgument
    (  metavar "CONFIG"
    <> value   "./mine.cfg"
    <> showDefault
    <> help    "Path to the configuration file"
    )

opts :: ParserInfo Command
opts = info (downloadCmd <|> runCmd <**> helper)
    (  fullDesc
    <> progDesc "Configurator Minecraft-server"
    <> header   "mc-config - utility for setup Minecraft-server"
    )

main :: IO ()
main = do
    hSetBuffering stdout NoBuffering
    putStrLn "2026 Ruzen42 MIT License (Minecraft configurator v0.1.2.1)"
    cmd <- execParser opts
    case cmd of
        Download       -> interactiveDownload
        Run configPath -> runWithConfig configPath

runWithConfig :: FilePath -> IO ()
runWithConfig configPath = do
    exists <- doesFileExist configPath

    unless exists $ do
        putStr $ "File " ++ configPath ++ " not found. Create new? [Y/n]: "
        answer <- getLine
        if map toLower answer /= "n"
            then do
                BL.writeFile configPath (encodePretty stdCfg)
                BL.writeFile "eula.txt" "eula=true"
                putStrLn $ "Created new config: " ++ configPath
            else exitSuccess

    putStrLn $ "Processed with config: " ++ configPath
    file <- BL.readFile configPath

    case decode file of
        Nothing  -> putStrLn "Error parsing config" >> exitFailure
        Just cfg -> print cfg >> execConfig cfg
