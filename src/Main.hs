module Main where

import System.Environment (getArgs)


main :: IO ()
main = do 
    args <- getArgs
    let config = if null args then "./mine.cfg" else args !! 0 :: String 
    putStr $ "Use config: " ++ config