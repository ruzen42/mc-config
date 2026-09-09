{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}

module Install (getAvailableVersions, interactiveDownload, downloadVersion) where

import Control.Lens ((^.))
import Data.Aeson (FromJSON, decode)
import Logger (errorLog, successLog)
import qualified System.IO as SO

import qualified Data.Text as T 
import qualified Data.List as L 
import qualified Data.Text.IO as TIO
import qualified Data.Text.Read as TR 
import qualified Network.Wreq as NW 
import qualified Data.ByteString.Lazy as BL

data PurpurVersions = PurpurVersions
    { versions :: [Text]
    } deriving (Generic, Show)

instance FromJSON PurpurVersions

getAvailableVersions :: IO [Text]
getAvailableVersions = do
    r <- NW.get "https://api.purpurmc.org/v2/purpur/"
    let body = r ^. NW.responseBody :: BL.ByteString
        out  = decode body :: Maybe PurpurVersions 
    case out of
        Just pv -> return $ reverse $ versions pv
        Nothing -> return []

downloadVersion :: Text -> IO ()
downloadVersion ver = do
    let url      = "https://api.purpurmc.org/v2/purpur/" <> ver <> "/latest/download" :: Text
        fileName = "purpur-" <> ver <> ".jar" :: Text
    TIO.putStrLn $ "downloading " <> fileName <> "..."
    SO.hFlush SO.stdout
    r <- NW.get $ T.unpack url
    let body = r ^. NW.responseBody :: BL.ByteString
    BL.writeFile (T.unpack fileName) body
    successLog "done:"
    TIO.putStrLn $ "\t " <> fileName

readMaybeText :: Text -> Maybe Int
readMaybeText txt = case TR.decimal (T.strip txt) of
  Right (n, rest) | T.null rest -> Just n
  _                            -> Nothing

interactiveDownload :: IO ()
interactiveDownload = do
    putStrLn "getting available versions..."
    vs <- getAvailableVersions
    if null vs
        then errorLog "no versions available :("
        else do
            let numbered = zip [1..] vs
            forM_ numbered $ \(i, v) -> do
                TIO.putStr $ T.pack (show (i :: Int)) <> ") " <> v <> "\t"
                when (i `mod` 3 == 0) $ TIO.putStrLn ""

            when (length vs `mod` 3 /= 0) $ TIO.putStrLn ""

            putStr $ "\nselect a version [1-" <> show (length vs) <> "]: "
            SO.hFlush SO.stdout
            input <- getLine
            case readMaybeText input :: Maybe Int of
                Nothing -> errorLog "invalid input"
                Just n
                    | n < 1 || n > length vs ->
                        errorLog "number must be between min and max"
                    | otherwise ->
                        downloadVersion (vs L.!! (n - 1))
