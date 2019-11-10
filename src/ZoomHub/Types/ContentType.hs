{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module ZoomHub.Types.ContentType
  ( ContentType(..)
    -- Squeal / Postgres
  , toExpression
  ) where

import Data.Int (Int32)
import Database.SQLite.Simple (SQLData(SQLInteger))
import Database.SQLite.Simple.FromField
  (FromField, ResultError(ConversionFailed), fromField, returnError)
import Database.SQLite.Simple.Internal (Field(Field))
import Database.SQLite.Simple.Ok (Ok(Ok))
import Database.SQLite.Simple.ToField (ToField, toField)
import Squeal.PostgreSQL (FromValue(..), PG, PGType(PGint4), ToParam(..))

data ContentType =
    Unknown
  | Image
  | Webpage
  | FlickrImage
  | GigaPan
  | Zoomify
  | PDF10
  | PDF11
  | WebpageThumbnail
  deriving (Eq, Show)

-- SQLite
instance ToField ContentType where
  toField Unknown          = SQLInteger  0
  toField Image            = SQLInteger  1
  toField Webpage          = SQLInteger  2
  toField FlickrImage      = SQLInteger  3
  toField GigaPan          = SQLInteger  6
  toField Zoomify          = SQLInteger  7
  toField PDF10            = SQLInteger 10
  toField PDF11            = SQLInteger 11
  toField WebpageThumbnail = SQLInteger 14

instance FromField ContentType where
  fromField (Field (SQLInteger  0) _) = Ok Unknown
  fromField (Field (SQLInteger  1) _) = Ok Image
  fromField (Field (SQLInteger  2) _) = Ok Webpage
  fromField (Field (SQLInteger  3) _) = Ok FlickrImage
  fromField (Field (SQLInteger  6) _) = Ok GigaPan
  fromField (Field (SQLInteger  7) _) = Ok Zoomify
  fromField (Field (SQLInteger 10) _) = Ok PDF10
  fromField (Field (SQLInteger 11) _) = Ok PDF11
  fromField (Field (SQLInteger 14) _) = Ok WebpageThumbnail
  fromField f = returnError ConversionFailed f "invalid content type"

-- Squeal / PostgreSQL
fromPGint4 :: Int32 -> ContentType
fromPGint4 0 = Unknown
fromPGint4 1 = Image
fromPGint4 2 = Webpage
fromPGint4 3 = FlickrImage
fromPGint4 6 = GigaPan
fromPGint4 7 = Zoomify
fromPGint4 10 = PDF10
fromPGint4 11 = PDF11
fromPGint4 14 = WebpageThumbnail
fromPGint4 t = error $ "Invalid ContentType: " <> show t

toPGint4 :: ContentType -> Int32
toPGint4 Unknown =  0
toPGint4 Image =  1
toPGint4 Webpage =  2
toPGint4 FlickrImage =  3
toPGint4 GigaPan =  6
toPGint4 Zoomify =  7
toPGint4 PDF10 = 10
toPGint4 PDF11 = 11
toPGint4 WebpageThumbnail = 14

type instance PG ContentType = 'PGint4
instance ToParam ContentType 'PGint4 where
  toParam = toParam . toPGint4

instance FromValue 'PGint4 ContentType where
  -- TODO: What if database value is not a valid?
  fromValue = fromPGint4 <$> fromValue @'PGint4

toExpression :: Num a => ContentType -> a
toExpression = fromIntegral . toPGint4
