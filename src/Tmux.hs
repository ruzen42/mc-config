{-# LANGUAGE OverloadedStrings #-}

module Tmux (checkTmux, runTmux, stopTmux, sendTmux) where

import System.Directory (findExecutable)
import System.Process (callCommand)
import Logger (errorLog, successLog)
import qualified Data.Text as T 
import qualified Data.Text.IO as TIO

checkTmux :: IO Bool
checkTmux = do
    result <- findExecutable "tmux"
    case result of
      Nothing -> do 
        errorLog "Tmux not found"
        return False
      Just tmux -> do
        successLog "tmux found on path:"
        TIO.putStrLn $ "\t" <> T.pack tmux 
        return True

runTmux :: Text -> Text -> IO ()
runTmux session cmd = do
    isTmux <- checkTmux
    if not isTmux then 
      errorLog "Tmux not found, cannot run"
    else do
        let tmuxCmd = "tmux new-session -d -s " <> session <> " '" <> cmd <> " || read'"
        TIO.putStrLn $ "launching tmux session: " <> tmuxCmd
        callCommand (T.unpack tmuxCmd)

stopTmux :: Text -> IO ()
stopTmux session = do
    isTmux <- checkTmux
    if not isTmux then errorLog "tmux not found, cannot stop"
    else do
        let tmuxCmd = "tmux send-keys -t " <> session <> " \"stop\" ENTER"
        TIO.putStrLn $ "stopping tmux session: " <> session
        callCommand (T.unpack tmuxCmd)

sendTmux :: Text -> Text -> IO ()
sendTmux session cmd = do
    isTmux <- checkTmux
    if not isTmux then errorLog "tmux not found, cannot send"
    else do
        let tmuxCmd = "tmux send-keys -t " <> session <> " \"" <> cmd <> "\" ENTER"
        TIO.putStrLn $ "sending command to tmux session: " <> tmuxCmd
        callCommand (T.unpack tmuxCmd)
