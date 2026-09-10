{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}

module Plugin.Manage
  ( fetchPlugin
  , searchPlugins
  , formatSearchResults
  , downloadLatestVersion
  ) where

import Control.Lens
import Data.Aeson (FromJSON, parseJSON, withObject, (.:))
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Network.Wreq
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>))
import Relude.Unsafe ((!!))

data ModrinthSearchResult = ModrinthSearchResult
  { hits :: [ModrinthPlugin]
  } deriving (Show, Generic)

instance FromJSON ModrinthSearchResult

data ModrinthPlugin = ModrinthPlugin
  { projectId   :: Text
  , slug        :: Text
  , title       :: Text
  , description :: Text
  } deriving (Show, Generic)

instance FromJSON ModrinthPlugin where
  parseJSON = withObject "ModrinthPlugin" $ \v -> ModrinthPlugin
    <$> v .: "project_id"
    <*> v .: "slug"
    <*> v .: "title"
    <*> v .: "description"

data ModrinthVersion = ModrinthVersion
  { files :: [ModrinthFile]
  } deriving (Show, Generic)

instance FromJSON ModrinthVersion

data ModrinthFile = ModrinthFile
  { url      :: Text
  , filename :: Text
  } deriving (Show, Generic)

instance FromJSON ModrinthFile

reqOpts :: Options
reqOpts = defaults
  & header "User-Agent" .~ ["mc-config/1.3.0 (github.com/ruzen42/mc-config)"]

searchFacets :: Text
searchFacets = "[[\"project_type:mod\"],[\"categories:paper\",\"categories:spigot\",\"categories:purpur\"]]"

searchPlugins :: Text -> IO (Either Text [ModrinthPlugin])
searchPlugins pluginName = do
  let searchUrl = "https://api.modrinth.com/v2/search"
      opts = reqOpts
        & param "query"  .~ [pluginName]
        & param "facets" .~ [searchFacets]

  searchResponse <- asJSON =<< getWith opts searchUrl
  let searchResult = searchResponse ^. responseBody

  case hits searchResult of
    [] -> pure $ Left $ "plugin not found: " <> pluginName
    found -> pure $ Right found

fetchPlugin :: Text -> IO (Either Text Text)
fetchPlugin pluginName = do
  result <- searchPlugins pluginName
  case result of
    Left err -> pure $ Left err
    Right [singlePlugin] -> downloadLatestVersion singlePlugin
    Right foundPlugins -> do
      chosen' <- pickPluginInteractively foundPlugins
      case chosen' of
        Nothing -> pure $ Left "cancelled: no plugin selected"
        Just p  -> downloadLatestVersion p

pickPluginInteractively :: [ModrinthPlugin] -> IO (Maybe ModrinthPlugin)
pickPluginInteractively plugins = do
  mapM_ TIO.putStrLn (formatSearchResults plugins)
  TIO.putStr "choose a number (or press Enter to cancel): "
  hFlush stdout
  answer <- TIO.getLine
  if T.null (T.strip answer)
    then pure Nothing
    else case readMaybe (T.unpack (T.strip answer)) of
      Just n | n >= 1, n <= length plugins -> pure $ Just (plugins !! (n - 1))
      _ -> do
        TIO.putStrLn "invalid choice"
        pickPluginInteractively plugins

formatSearchResults :: [ModrinthPlugin] -> [Text]
formatSearchResults plugins =
  ("found " <> T.pack (show (length plugins)) <> " results:")
  : map formatOption (zip [1 :: Int ..] plugins)
  where
    formatOption :: (Int, ModrinthPlugin) -> Text
    formatOption (i, ModrinthPlugin{ title, slug, description }) =
      "  " <> T.pack (show i) <> ") " <> title
           <> " (" <> slug <> ") - " <> truncateDesc description

    truncateDesc :: Text -> Text
    truncateDesc d
      | T.length d <= 80 = d
      | otherwise        = T.take 77 d <> "..."

downloadLatestVersion :: ModrinthPlugin -> IO (Either Text Text)
downloadLatestVersion ModrinthPlugin{ projectId, title } = do
  let versionsUrl = "https://api.modrinth.com/v2/project/" <> T.unpack projectId <> "/version"
      opts = reqOpts
        & param "loaders" .~ ["[\"paper\",\"spigot\",\"purpur\"]"]

  versionsResponse <- asJSON =<< getWith opts versionsUrl
  let versionsList = versionsResponse ^. responseBody :: [ModrinthVersion]

  case versionsList of
    [] -> pure $ Left $ "not found versions for purpur " <> title
    (latestVersion : _) -> case files latestVersion of
      [] -> pure $ Left $ "files for download not found :( " <> title
      (targetFile : _) -> saveJarFile targetFile

saveJarFile :: ModrinthFile -> IO (Either Text Text)
saveJarFile ModrinthFile{ url, filename } = do
  let targetDir = "plugins"
      targetPath = targetDir </> T.unpack filename

  createDirectoryIfMissing True targetDir

  downloadResponse <- getWith reqOpts (T.unpack url)
  let jarBytes = downloadResponse ^. responseBody

  BL.writeFile targetPath jarBytes
  pure $ Right $ "plugin successfully saved in: " <> T.pack targetPath
