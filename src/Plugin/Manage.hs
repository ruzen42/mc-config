{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}

module Plugin.Manage (fetchPlugin, downloadLatestVersion) where

import Control.Lens
import Data.Aeson (FromJSON, parseJSON, withObject, (.:))
import qualified Data.ByteString.Lazy as BL
import Data.Text (Text)
import qualified Data.Text as T
import GHC.Generics (Generic)
import Network.Wreq
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>))

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

fetchPlugin :: Text -> IO (Either Text Text)
fetchPlugin pluginName = do
  let searchUrl = "https://api.modrinth.com/v2/search"
      opts = reqOpts
        & param "query" .~ [pluginName]
        & param "facets" .~ ["[\"project_type:mod\",[\"categories:paper\",\"categories:spigot\",\"categories:purpur\"]]"]

  searchResponse <- asJSON =<< getWith opts searchUrl
  let searchResult = searchResponse ^. responseBody

  case hits searchResult of
    [] -> pure $ Left $ "plugin not found: " <> pluginName
    (targetPlugin : _) -> downloadLatestVersion targetPlugin

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
