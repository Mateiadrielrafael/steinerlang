module Steiner.Language.Error
  ( class ErrorRep
  , ErrorKind
  , SteinerError
  , RecursiveTypeDetails
  , TypeError(..)
  , failWith
  , errorKind
  , toSteinerError
  ) where

import Prelude
import Control.Monad.Error.Class (class MonadThrow, throwError)
import Data.Generic.Rep (class Generic)
import Data.Generic.Rep.Show (genericShow)
import Data.Maybe (Maybe(..))
import Data.String (joinWith)
import Steienr.Data.String (indent)
import Steiner.Language.Ast (Expression)
import Steiner.Language.Type (Type(..))

-- |
-- Possible kinds (the literal sense, not the purescript type system one) of errors whicn might occur
--
data ErrorKind
  = TypeError
  | SyntaxError

derive instance genericErrorKind :: Generic ErrorKind _

instance showErrorKind :: Show ErrorKind where
  show = genericShow

-- |
-- Typeclass for everything which can be represented as an error
--
class
  Show a <= ErrorRep a where
  -- |
  -- This gets the type of an error. Uusally this 
  --
  errorKind :: a -> ErrorKind

-- |
-- Details for errors generated by the fact a type contains references to itself
--
type RecursiveTypeDetails
  = { ty :: Type
    , varName :: String
    }

-- |
-- Kind of errors which can occur during Type
--
data TypeError
  = CannotUnify Type Type
  | NotPolymorphicEnough Type Type
  | NoSkolemScope String Type
  | RecursiveType RecursiveTypeDetails
  | DifferentSkolemConstants String String
  | NeedsType Expression Type

instance errorRepTypeError :: ErrorRep TypeError where
  errorKind _ = TypeError

instance showTypeError :: Show TypeError where
  show (RecursiveType { ty, varName }) =
    "Type\n"
      <> (indent 4 $ varName <> " = " <> show ty)
      <> "\ncontains a reference to itself."
  show (NotPolymorphicEnough ty ty') =
    joinWith "\n"
      [ "Type"
      , indent 4 $ show ty'
      , "is less polymorphic than type"
      , indent 4 $ show ty
      ]
  show (CannotUnify left right) =
    joinWith "\n"
      [ "Cannot unify type"
      , indent 4 $ show left
      , "with type"
      , indent 4 $ show right
      ]
  show (NoSkolemScope ident ty) =
    joinWith "\n"
      [ "The impossible happened! Cannot find skolem scope for type: "
      , indent 4 $ show $ TForall ident ty Nothing
      ]
  show (DifferentSkolemConstants left right) =
    joinWith "\n"
      [ "Cannot unify type"
      , indent 4 left
      , "with type"
      , indent 4 right
      , "because the skolem constants do not match"
      ]
  show (NeedsType ast ty) =
    joinWith "\n"
      [ "Expression "
      , indent 4 $ show ast
      , "needs type"
      , indent 4 $ show ty
      ]

-- |
-- General type for errors
--
newtype SteinerError
  = SteinerError
  { kind :: ErrorKind
  , message :: String
  }

instance showSteinerError :: Show SteinerError where
  show (SteinerError { kind, message }) =
    joinWith "\n"
      [ show kind <> ": "
      , indent 4 message
      ]

-- |
-- Make a steiner error from some more detalied error data.
--
toSteinerError :: forall e. ErrorRep e => e -> SteinerError
toSteinerError error =
  SteinerError
    { kind: errorKind error
    , message: show error
    }

-- |
-- Helper to fail with a SteinerError
--
failWith :: forall e m r. MonadThrow SteinerError m => ErrorRep e => e -> m r
failWith = throwError <<< toSteinerError
