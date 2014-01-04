{-# OPTIONS_GHC -W #-}
module Build.Interface (load,decode,isValid) where

import qualified Data.ByteString.Lazy as L
import qualified Data.Binary as Binary

import qualified Elm.Internal.Version as Version
import System.Directory (doesFileExist)

import SourceSyntax.Module

load :: FilePath -> IO (Either String L.ByteString)
load filePath = do
  exists <- doesFileExist filePath
  if exists
    then do
      byteString <- L.readFile filePath
      return $ Right byteString

    else
      return $ Left $ "Unable to find file " ++ filePath ++
                      " for deserialization!"

decode :: Binary.Binary a => FilePath -> L.ByteString -> Either String a
decode filePath bytes =
    case Binary.decodeOrFail bytes of
      Right (_, _, binaryInfo) -> Right binaryInfo

      Left (_, offset, err) ->
          Left $ concat $
          [ "Error reading build artifact: ", filePath, "\n"
          , "    The exact error was '", err, "' at offset ", show offset, ".\n"
          , "    The file was generated by a previous build and may be outdated or corrupt.\n"
          , "    Please remove the file and try again."
          ]

isValid :: FilePath -> (String, ModuleInterface) -> Either String (String, ModuleInterface)
isValid filePath (name, interface) =
    if iVersion interface == Version.elmVersion
    then Right (name, interface)
    else Left $ concat
             [ "Error reading build artifact: ", filePath, "\n"
             , "    It was generated by a different version of the compiler: "
             , show (iVersion interface), "\n"
             , "    Please remove the file and try again.\n"
             ]