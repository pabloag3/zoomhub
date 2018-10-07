{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeOperators #-}

module ZoomHub.Storage.PostgreSQL2
  ( -- ** Read operations
    getById
  ) where

import ZoomHub.Storage.PostgreSQL.Schema (Schema)
import ZoomHub.Types.Content (Content(..))
import ZoomHub.Types.ContentId (ContentId, unContentId)
import ZoomHub.Types.ContentMIME (ContentMIME)
import ZoomHub.Types.ContentState (ContentState)
import ZoomHub.Types.ContentType (ContentType)
import ZoomHub.Types.ContentURI (ContentURI)
import ZoomHub.Types.DeepZoomImage (mkDeepZoomImage)
import ZoomHub.Types.DeepZoomImage.TileFormat(TileFormat)
import ZoomHub.Types.DeepZoomImage.TileOverlap(TileOverlap)
import ZoomHub.Types.DeepZoomImage.TileSize(TileSize)

import Control.Monad.Trans.Control (MonadBaseControl)
import Data.Int (Int32, Int64)
import Data.Text (Text)
import Data.Time (UTCTime)
import qualified GHC.Generics as GHC
import qualified Generics.SOP as SOP
import Squeal.PostgreSQL
  ( (:::)
  , Connection
  , MonadPQ
  , NP((:*))
  , NullityType(NotNull, Null)
  , Only(..)
  , PGType(PGfloat8, PGint4, PGint8, PGtext, PGtimestamptz)
  , Query
  , (!)
  , (&)
  , (.==)
  , as
  , firstRow
  , from
  , leftOuterJoin
  , param
  , runQueryParams
  , select
  , table
  , where_
  )
import Squeal.PostgreSQL.Pool (Pool, runPoolPQ)

-- Public API

-- Reads
getById :: MonadBaseControl IO m => ContentId -> Pool (SOP.K Connection Schema) -> m (Maybe Content)
getById cid = runPoolPQ session
  where
    session :: (MonadBaseControl IO m, MonadPQ Schema m) => m (Maybe Content)
    session = do
      result <- runQueryParams selectContentByHashId (Only $ unContentId cid)
      contentRow <- firstRow result
      return (rowToContent <$> contentRow)

selectContentByHashId ::
  Query
  Schema
  '[ 'NotNull 'PGtext ]
  '[ "crId" ::: 'NotNull 'PGint8
  , "crHashId" ::: 'NotNull 'PGtext
  , "crTypeId" ::: 'NotNull 'PGint4
  , "crURL" ::: 'NotNull 'PGtext
  , "crState" ::: 'NotNull 'PGtext
  , "crInitializedAt" ::: 'NotNull 'PGtimestamptz
  , "crActiveAt" ::: 'Null 'PGtimestamptz
  , "crCompletedAt" ::: 'Null 'PGtimestamptz
  , "crTitle" ::: 'Null 'PGtext
  , "crAttributionText" ::: 'Null 'PGtext
  , "crAttributionLink" ::: 'Null 'PGtext
  , "crMIME" ::: 'Null 'PGtext
  , "crSize" ::: 'Null 'PGint8
  , "crError" ::: 'Null 'PGtext
  , "crProgress" ::: 'NotNull 'PGfloat8
  , "crAbuseLevelId" ::: 'NotNull 'PGint4
  , "crNumAbuseReports" ::: 'NotNull 'PGint8
  , "crNumViews" ::: 'NotNull 'PGint8
  , "crVersion" ::: 'NotNull 'PGint4
  , "irWidth" ::: 'Null 'PGint8
  , "irHeight" ::: 'Null 'PGint8
  , "irTileSize" ::: 'Null 'PGint4
  , "irTileOverlap" ::: 'Null 'PGint4
  , "irTileFormat" ::: 'Null 'PGtext
  ]
selectContentByHashId = select
  ( #c ! #id `as` #crId :*
    #c ! #hash_id `as` #crHashId :*
    #c ! #type_id `as` #crTypeId :*
    #c ! #url `as` #crURL :*
    #c ! #state `as` #crState :*
    #c ! #initialized_at `as` #crInitializedAt :*
    #c ! #active_at `as` #crActiveAt :*
    #c ! #completed_at `as` #crCompletedAt :*
    #c ! #title `as` #crTitle :*
    #c ! #attribution_text `as` #crAttributionText :*
    #c ! #attribution_link `as` #crAttributionLink :*
    #c ! #mime `as` #crMIME :*
    #c ! #size `as` #crSize :*
    #c ! #error `as` #crError :*
    #c ! #progress `as` #crProgress :*
    #c ! #abuse_level_id `as` #crAbuseLevelId :*
    #c ! #num_abuse_reports `as` #crNumAbuseReports :*
    #c ! #num_views `as` #crNumViews :*
    #c ! #version `as` #crVersion :*
    #i ! #width `as` #irWidth :*
    #i ! #height `as` #irHeight :*
    #i ! #tile_size `as` #irTileSize :*
    #i ! #tile_overlap `as` #irTileOverlap :*
    #i ! #tile_format `as` #irTileFormat
  )
  ( from (table (#content `as` #c)
         & leftOuterJoin (table (#image `as` #i)) (#c ! #id .== #i ! #content_id)
         )
    & where_ ((#c ! #hash_id) .== param @1)
  )

data ContentRow = ContentRow
  { crId :: Int64
  , crHashId :: ContentId
  , crTypeId :: ContentType
  , crURL :: ContentURI
  , crState :: ContentState
  , crInitializedAt :: UTCTime
  , crActiveAt :: Maybe UTCTime
  , crCompletedAt :: Maybe UTCTime
  , crTitle :: Maybe Text
  , crAttributionText :: Maybe Text
  , crAttributionLink :: Maybe Text
  , crMIME :: Maybe ContentMIME
  , crSize :: Maybe Int64
  , crError :: Maybe Text
  , crProgress :: Double
  , crAbuseLevelId :: Int32
  , crNumAbuseReports :: Int64
  , crNumViews :: Int64
  , crVersion :: Int32
  , irWidth :: Maybe Int64
  , irHeight :: Maybe Int64
  , irTileSize :: Maybe TileSize
  , irTileOverlap :: Maybe TileOverlap
  , irTileFormat :: Maybe TileFormat
  } deriving (Show, GHC.Generic)
instance SOP.Generic ContentRow
instance SOP.HasDatatypeInfo ContentRow

rowToContent :: ContentRow -> Content
rowToContent cr = Content
    { contentId = crHashId cr
    , contentType = crTypeId cr
    , contentURL = crURL cr
    , contentState = crState cr
    , contentInitializedAt = crInitializedAt cr
    , contentActiveAt = crActiveAt cr
    , contentCompletedAt = crCompletedAt cr
    , contentMIME = crMIME cr
    , contentSize = fromIntegral <$> crSize cr
    , contentProgress = crProgress cr
    , contentNumViews = fromIntegral (crNumViews cr)
    , contentError = crError cr
    , contentDZI = mDZI
    }
  where
    mDZI = mkDeepZoomImage <$>
      (fromIntegral <$> irWidth cr) <*>
      (fromIntegral <$> irHeight cr) <*>
      irTileSize cr <*>
      irTileOverlap cr <*>
      irTileFormat cr