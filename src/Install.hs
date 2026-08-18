{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}

module Install (getAvailableVersions, interactiveDownload, downloadVersion) where

import Control.Lens ((^.))
import Data.Aeson (FromJSON, decode)
import qualified Data.ByteString.Lazy as BL
import GHC.Generics (Generic)
import Network.Wreq (get, responseBody)
import System.IO (hFlush, stdout)
import Text.Read (readMaybe)
import Control.Monad (when, forM_)
import Logger (errorLog, successLog)

data PurpurVersions = PurpurVersions
    { versions :: [String]
    } deriving (Generic, Show)

instance FromJSON PurpurVersions

getAvailableVersions :: IO [String]
getAvailableVersions = do
    r <- get "https://api.purpurmc.org/v2/purpur/"
    let body = r ^. responseBody :: BL.ByteString
    case decode body of
        Just pv -> return $ reverse $ versions pv
        Nothing -> return []

downloadVersion :: String -> IO ()
downloadVersion ver = do
    let url      = "https://api.purpurmc.org/v2/purpur/" ++ ver ++ "/latest/download"
        fileName = "purpur-" ++ ver ++ ".jar"
    putStrLn $ "downloading " ++ fileName ++ "..."
    hFlush stdout
    r <- get url
    let body = r ^. responseBody :: BL.ByteString
    BL.writeFile fileName body
    successLog "done:"
    putStrLn $ "\t " ++ fileName

interactiveDownload :: IO ()
interactiveDownload = do
    putStrLn "getting available versions..."
    vs <- getAvailableVersions
    if null vs
        then errorLog "no versions available :("
        else do
            let numbered = zip [1..] vs
            forM_ numbered $ (\(i, v) -> do
                putStr $ show (i :: Int) ++ ") " ++ v ++ " "
                when (i `mod` 3 == 0) $ putStrLn ""
                )
            putStr $ "\nselect a version [1-" ++ show (length vs) ++ "]: "
            hFlush stdout
            input <- getLine
            case readMaybe input :: Maybe Int of
                Nothing -> errorLog "invalid input"
                Just n
                    | n < 1 || n > length vs ->
                        errorLog $ "number must be between min and max"
                    | otherwise ->
                        downloadVersion (vs !! (n - 1))
