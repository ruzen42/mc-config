{-# LANGUAGE OverloadedStrings #-}

module Tmux (checkTmux, runTmux, stopTmux, sendTmux) where

import System.Directory (findExecutable)
import System.Process (callCommand)
import Logger (errorLog, successLog)

checkTmux :: IO Bool
checkTmux = do
    result <- findExecutable "tmux"
    if result == Nothing then do
        errorLog "Tmux not found"
        return False
    else do
        successLog $ "Tmux found on path:"
        putStrLn $ "\t" ++ show result
        return True

runTmux :: String -> String -> IO ()
runTmux session cmd = do
    isTmux <- checkTmux
    if not isTmux then errorLog "Tmux not found, cannot run"
    else do
        let tmuxCmd = "tmux new-session -d -s " ++ session ++ " '" ++ cmd ++ " || read'"
        putStrLn $ "Launching tmux session: " ++ tmuxCmd
        callCommand tmuxCmd

stopTmux :: String -> IO ()
stopTmux session = do
    isTmux <- checkTmux
    if not isTmux then errorLog "Tmux not found, cannot stop"
    else do
        let tmuxCmd = "tmux send-keys -t " ++ session ++ " \"stop\" ENTER"
        putStrLn $ "Stopping tmux session: " ++ session
        callCommand tmuxCmd

sendTmux :: String -> String -> IO ()
sendTmux session cmd = do
    isTmux <- checkTmux
    if not isTmux then errorLog "Tmux not found, cannot send"
    else do
        let tmuxCmd = "tmux send-keys -t " ++ session ++ " \"" ++ cmd ++ "\" ENTER"
        putStrLn $ "Sending command to tmux session: " ++ tmuxCmd
        callCommand tmuxCmd
