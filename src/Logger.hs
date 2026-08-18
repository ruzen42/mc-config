{-# LANGUAGE OverloadedStrings #-}

module Logger (unnecessaryLog, errorLog, successLog, warnLog) where

import Rainbow (putChunkLn, putChunk, Chunk
                , fore, grey, red, green, 
                yellow, bold)
import Data.Function ((&))

unnecessaryLog :: Chunk -> IO ()
unnecessaryLog msg = putChunkLn $ msg & fore grey

errorLog :: Chunk -> IO ()
errorLog msg = do
  putChunk $ "bad: " & fore red & bold
  putChunkLn msg

successLog :: Chunk -> IO ()
successLog msg = do
  putChunk $ "good: " & fore green & bold
  putChunkLn msg

warnLog :: Chunk -> IO ()
warnLog msg = do
  putChunk $ "warn: " & fore yellow & bold
  putChunkLn msg
