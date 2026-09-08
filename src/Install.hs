{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}

module Install (getAvailableVersions, interactiveDownload, downloadVersion) where

import Control.Lens ((^.))
import Data.Aeson (FromJSON, decode)
import qualified Data.ByteString.Lazy as BL
import GHC.Generics (Generic)
import qualified Network.Wreq as NW 
import Text.Read (readMaybe)
import Control.Monad (when, forM_)
import Logger (errorLog, successLog)
import Data.Text (Text)
import qualified Data.Text as T 
import Relude.Lifted.Handle (hFlush, stdout)
import qualified Data.Text.IO as TIO
import Relude (writeFileBS)

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
    hFlush stdout
    r <- NW.get $ T.unpack url
    let body = r ^. NW.responseBody :: BL.ByteString
    writeFileBS (T.unpack fileName) body
    successLog "done:"
    TIO.putStrLn $ "\t " <> fileName

interactiveDownload :: IO ()
interactiveDownload = do
    putStrLn "getting available versions..."
    vs <- getAvailableVersions
    if null vs
        then errorLog "no versions available :("
        else do
            let numbered = zip [1..] vs
            forM_ numbered $ (\(i, v) -> do
                putStr $ show (i :: Int) ++ ") " <> v <> " "
                when (i `mod` 3 == 0) $ putStrLn ""
                )
            putStr $ "\nselect a version [1-" <> show (length vs) <> "]: "
            hFlush stdout
            input <- getLine
            case readMaybe input :: Maybe Int of
                Nothing -> errorLog "invalid input"
                Just n
                    | n < 1 || n > length vs ->
                        errorLog $ "number must be between min and max"
                    | otherwise ->
                        downloadVersion (vs !! (n - 1))
