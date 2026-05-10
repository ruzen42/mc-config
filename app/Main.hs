module Main (main) where

import System.Environment (getArgs)
import Config (stdCfg, execConfig)
import System.Directory (doesFileExist)
import System.IO (hSetBuffering, stdout, BufferMode(NoBuffering))
import Data.Char (toLower)
import Control.Monad (unless)
import System.Exit (exitSuccess, exitFailure)
import Data.Aeson (decode)
import Data.Aeson.Encode.Pretty (encodePretty) 
import qualified Data.ByteString.Lazy as BL

main :: IO ()
main = do 
    hSetBuffering stdout NoBuffering
    args <- getArgs
    
    let configPath = if null args then "./mine.cfg" else head args 
    
    exists <- doesFileExist configPath
    
    unless exists $ do
        putStr $ "File " ++ configPath ++ " does not exist. Create new? [Y/n]: "
        answer <- getLine
        let response = map toLower answer
        
        if (response /= "n") then do
          BL.writeFile configPath (encodePretty stdCfg)
          putStrLn $ "Created new config at: " ++ configPath
        else 
          exitSuccess

    putStrLn $ "Using config: " ++ configPath

    file <- BL.readFile configPath
    
    case decode file of 
      Nothing  -> do
        putStrLn "Config parsing error"
        exitFailure 
      Just cfg -> do 
        print cfg
        execConfig cfg 




