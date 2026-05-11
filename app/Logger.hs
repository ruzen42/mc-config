{-# LANGUAGE OverloadedStrings #-}

module Logger (unnecessaryLog, errorLog, successLog, warnLog) where

import           Rainbow (putChunkLn, putChunk, Chunk
                         , fore, grey
                         , red, green, yellow, bold)
import           Data.Function ((&))

unnecessaryLog :: Chunk -> IO ()
unnecessaryLog msg = putChunkLn $ msg & fore grey

errorLog :: Chunk -> IO ()
errorLog msg = do
  putChunk $ "Error: " & fore red & bold
  putChunkLn msg

successLog :: Chunk -> IO ()
successLog msg = do
  putChunk $ "Success: " & fore green & bold
  putChunkLn msg

warnLog :: Chunk -> IO ()
warnLog msg = do
  putChunk $ "Warning: " & fore yellow & bold
  putChunkLn msg
