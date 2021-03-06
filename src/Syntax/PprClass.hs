module Syntax.PprClass (
  -- * Documents
  Doc,
  -- * Pretty-printing class
  Ppr(..), IsInfix(..), ListStyle(..), listStyleBrack,
  -- ** Helpers
  ppr0, ppr1, pprPrec1, pprDepth,
  -- ** Context operations
  prec, prec0, mapPrec, prec1, descend, atPrec, atDepth,
  askPrec, ifPrec, askDepth, ifDepth,
  trimList, trimCat,
  -- *** For type name shortening
  TyNames(..), tyNames0,
  setTyNames, askTyNames, enterTyNames, lookupTyNames,
  -- * Pretty-printing combinators
  (>+>), (>?>), ifEmpty,
  vcat, sep, cat, fsep, fcat,
  -- * Renderers
  render, renderS, printDoc, printPpr, hPrintDoc, hPrintPpr,
  -- ** Instantiations of several context-sensitive functions
  --    with the zero context
  isEmpty, renderStyle, fullRender,
  -- ** Instance helpers
  showFromPpr, pprFromShow,
  -- * Alternate printing of 'Maybe'
  MAYBE(..),
  -- * Re-exports
  module Alt.PrettyPrint
) where

import Alt.PrettyPrint hiding ( Doc(..),
                                render, isEmpty, renderStyle, fullRender,
                                vcat, sep, cat, fsep, fcat )
import qualified Alt.PrettyPrint as P

import Data.Perhaps
import Syntax.Prec
import qualified Syntax.Strings as Strings
import AST.Ident (QTypId, ModId, Renamed)

import System.IO (Handle, stdout, hPutChar, hPutStr)
import qualified Data.Map as M
import qualified Data.Set as S

-- | Context for pretty-printing.
data PprContext
  = PprContext {
      pcPrec   :: !Int,
      pcDepth  :: !Int,
      pcTyName :: !TyNames
  }

data TyNames =
  TyNames {
    tnLookup   :: Int -> QTypId Renamed -> QTypId Renamed,
    tnEnter    :: ModId Renamed -> TyNames
  }

-- | Default context
pprContext0 :: PprContext
pprContext0  = PprContext {
  pcPrec   = 0,
  pcDepth  = -1,
  pcTyName = tyNames0
}

tyNames0 :: TyNames
tyNames0  = TyNames {
  tnLookup = const id,
  tnEnter  = const tyNames0
}

type Doc = P.Doc PprContext

data ListStyle 
  = ListStyle {
    listStyleBegin, listStyleEnd, listStylePunct :: Doc,
    listStyleDelimitEmpty, listStyleDelimitSingleton :: Bool,
    listStyleJoiner :: [Doc] -> Doc
  }

-- | Class for pretty-printing at different types
--
-- Minimal complete definition is one of:
--
-- * 'pprPrec'
--
-- * 'ppr'
class Ppr p where
  -- | Print current precedence
  ppr     :: p -> Doc
  -- | Print at the specified enclosing precedence
  pprPrec :: Int -> p -> Doc
  -- | Print a list in the default style
  pprList :: [p] -> Doc
  -- | Print a list in the specified style
  pprStyleList :: ListStyle -> [p] -> Doc
  -- | Style for printing lists
  listStyle   :: [p] -> ListStyle
  --
  --
  ppr         = asksD pcPrec . flip pprPrec
  pprPrec p   = prec p . ppr
  pprList xs  = pprStyleList (listStyle xs) xs
  --
  pprStyleList st [] =
    if listStyleDelimitEmpty st
      then listStyleBegin st <> listStyleEnd st
      else mempty
  pprStyleList st [x] =
    if listStyleDelimitSingleton st
      then listStyleBegin st <> ppr0 x <> listStyleEnd st
      else ppr x
  pprStyleList st xs  =
    listStyleBegin st <>
      listStyleJoiner st (punctuate (listStylePunct st) (map ppr0 xs))
    <> listStyleEnd st
  --
  listStyle _ = ListStyle {
    listStyleBegin            = lparen,
    listStyleEnd              = rparen,
    listStylePunct            = comma,
    listStyleDelimitEmpty     = False,
    listStyleDelimitSingleton = False,
    listStyleJoiner           = fsep
  }

-- | Style for printing square-bracketed lists.
listStyleBrack ∷ ListStyle
listStyleBrack = ListStyle {
  listStyleBegin            = lbrack,
  listStyleEnd              = rbrack,
  listStylePunct            = comma,
  listStyleDelimitEmpty     = True,
  listStyleDelimitSingleton = True,
  listStyleJoiner           = fsep
}

-- | Print at top level.
ppr0      :: Ppr p => p -> Doc
ppr0       = atPrec 0 . ppr

-- | Print at next level.
ppr1      :: Ppr p => p -> Doc
ppr1       = prec1 . ppr

-- | Print at one more than the given level.
pprPrec1  :: Ppr p => Int -> p -> Doc
pprPrec1   = pprPrec . succ

-- | Print to the given depth.
pprDepth  :: Ppr p => Int -> p -> Doc
pprDepth d = atDepth d . ppr

-- | Enter the given precedence level, drawing parentheses if necessary,
--   and count it as a descent in depth as well.
prec :: Int -> Doc -> Doc
prec p doc = asksD pcPrec $ \p' ->
  if p' > p
    then descend $ parens (atPrec p doc)
    else atPrec p doc

-- | Enter the given precedence level, drawing parentheses if necessary,
--   and count it as a descent in depth as well. If we enter
--   parentheses, reset the precedence to 0 at most.
prec0 :: Int -> Doc -> Doc
prec0 p doc = asksD pcPrec $ \p' ->
  if p' > p
    then descend $ parens (atPrec (p `min` 0) doc)
    else atPrec p doc

-- | Adjust the precedence with the given function.
mapPrec :: (Int -> Int) -> Doc -> Doc
mapPrec f doc = askPrec (\p -> prec (f p) doc)

-- | Go to the next (tigher) precedence level.
prec1 :: Doc -> Doc
prec1  = mapD (\e -> e { pcPrec = pcPrec e + 1 })

-- | Descend a level, elliding if the level counter runs out
descend :: Doc -> Doc
descend doc = askD $ \e ->
  case pcDepth e of
    -1 -> doc
    0  -> text Strings.ellipsis
    k  -> localD e { pcDepth = k - 1 } doc

-- | Set the precedence, but check or draw parentheses
atPrec   :: Int -> Doc -> Doc
atPrec p  = mapD (\e -> e { pcPrec = p })

-- | Set the precedence, but check or draw parentheses
atDepth  :: Int -> Doc -> Doc
atDepth k = mapD (\e -> e { pcDepth = k })

-- | Find out the precedence
askPrec :: (Int -> Doc) -> Doc
askPrec  = asksD pcPrec

-- | A conditional: uses the second argument if the current precedence
--   satisfies the predicate, otherwise the second
ifPrec  :: (Int -> Bool) -> Doc -> Doc -> Doc
ifPrec predicate true false =
  askPrec $ \p → if predicate p then true else false

-- | Find out the depth
askDepth :: (Int -> Doc) -> Doc
askDepth  = asksD pcDepth

-- | A conditional: uses the second argument if the current depth
--   satisfies the predicate, otherwise the second
ifDepth  :: (Int -> Bool) -> Doc -> Doc -> Doc
ifDepth predicate true false =
  askDepth $ \p → if predicate p then true else false

-- | Change the type name lookup function
setTyNames   :: TyNames -> Doc -> Doc
setTyNames f  = mapD (\e -> e { pcTyName = f })

-- | Retrieve the type name lookup function
askTyNames   :: (TyNames -> Doc) -> Doc
askTyNames    = asksD pcTyName

-- | Render a document with a module opened
enterTyNames :: ModId Renamed -> Doc -> Doc
enterTyNames u doc = askTyNames $ \tn ->
  setTyNames (tnEnter tn u) doc

-- | Look up a type name in the rendering context
lookupTyNames :: Int -> QTypId Renamed -> (QTypId Renamed -> Doc) -> Doc
lookupTyNames tag ql kont = askTyNames $ \tn ->
  kont (tnLookup tn tag ql)

-- | Trim a list to (about) the given number of elements, with
--   "..." in the middle.
trimList :: Int -> [Doc] -> [Doc]
trimList (-1) ds = ds
trimList n2   ds = if k <= 2 * n
                     then ds
                     else take n ds ++ text "... " : drop (k - n) ds
  where
    n = (n2 + 1) `div` 2
    k = length ds

-- | Lift a concatenation function to respect depth.
trimCat :: ([Doc] -> Doc) -> [Doc] -> Doc
trimCat xcat docs = asksD pcDepth $ \d -> case d of
  -1 -> xcat docs
  _  -> atDepth ((d + 1) `div` 2) (xcat (trimList d docs))

vcat, sep, cat, fsep, fcat :: [Doc] -> Doc
vcat = trimCat P.vcat
sep  = trimCat P.sep
cat  = trimCat P.cat
fsep = trimCat P.fsep
fcat = trimCat P.fcat

newtype MAYBE a = MAYBE (Maybe a) deriving (Eq, Ord)

instance Ppr a => Ppr (MAYBE a) where
  ppr (MAYBE Nothing)  = text "nothing"
  ppr (MAYBE (Just a)) = ppr a

instance Ppr a => Ppr (Maybe a) where
  ppr Nothing  = mempty
  ppr (Just a) = ppr a

instance Ppr a => Ppr (Perhaps a) where
  ppr Nope     = mempty
  ppr (Here a) = ppr a

instance (Ppr a, Ppr b) => Ppr (Either a b) where
  ppr (Left a)  = prec precApp (text "Left" <+> ppr a)
  ppr (Right a) = prec precApp (text "Right" <+> ppr a)

instance Ppr a => Ppr [a] where
  ppr = pprList

instance (Ppr a, Ppr b) => Ppr (a, b) where
  ppr (a, b) = parens (sep (punctuate comma [ppr0 a, ppr0 b]))

instance (Ppr a, Ppr b, Ppr c) => Ppr (a, b, c) where
  ppr (a,b,c) =
    parens (sep (punctuate comma [ppr0 a, ppr0 b, ppr0 c]))

instance (Ppr a, Ppr b, Ppr c, Ppr d) => Ppr (a, b, c, d) where
  ppr (a,b,c,d) =
    parens (sep (punctuate comma [ppr0 a, ppr0 b, ppr0 c, ppr0 d]))

instance (Ppr k, Ppr v) => Ppr (M.Map k v) where
  ppr m = braces . fsep . punctuate comma $
    [ ppr0 k <> colon <+> ppr0 v
    | (k, v) <- M.toList m ]

instance Ppr a => Ppr (S.Set a) where
  ppr = braces . fsep . punctuate comma . map ppr0 . S.toList

-- | Class to check if a particular thing will print infix.  Adds
--   an operation to print at the given precedence only if the given
--   thing is infix.  (We use this for printing arrows without too
--   many parens.)
class Ppr a => IsInfix a where
  isInfix  :: a -> Bool
  pprRight :: a -> Doc
  pprRight a =
    if isInfix a
      then ppr a
      else ppr0 a

instance Ppr Bool      where pprPrec = pprFromShow
instance Ppr Int       where ppr = int
instance Ppr Integer   where ppr = integer
instance Ppr Double    where ppr = double

instance Ppr Char where
  pprPrec        = pprFromShow
  pprStyleList _ = text

instance Ppr (P.Doc PprContext)  where ppr = id
instance Show (P.Doc PprContext) where showsPrec = showFromPpr

-- Render a document in the preferred style, given a string continuation
renderS :: Doc -> ShowS
renderS doc rest = fullRenderIn pprContext0 PageMode 80 1.1 each rest doc
  where each (Chr c) s'  = c:s'
        each (Str s) s'  = s++s'
        each (PStr s) s' = s++s'

-- Render a document in the preferred style
render :: Doc -> String
render doc = renderS doc ""

-- Is the document empty (in 'pprContext0')?
isEmpty :: Doc -> Bool
isEmpty  = isEmptyIn pprContext0

-- Render in the given style (in 'pprContext0')
renderStyle :: Style -> Doc -> String
renderStyle = renderStyleIn pprContext0

-- Render with the given parameters (in 'pprContext0')
fullRender :: Mode -> Int -> Float ->
              (TextDetails -> a -> a) -> a ->
              Doc -> a
fullRender = fullRenderIn pprContext0

-- Render and display a document in the preferred style
printDoc :: Doc -> IO ()
printDoc  = hPrintDoc stdout

-- Pretty-print, render and display in the preferred style
printPpr :: Ppr a => a -> IO ()
printPpr  = hPrintPpr stdout

-- Render and display a document in the preferred style
hPrintDoc :: Handle -> Doc -> IO ()
hPrintDoc h = fullRenderIn pprContext0 PageMode 80 1.1 each (putChar '\n')
  where each (Chr c) io  = hPutChar h c >> io
        each (Str s) io  = hPutStr h s >> io
        each (PStr s) io = hPutStr h s >> io

hPrintPpr :: Ppr a => Handle -> a -> IO ()
hPrintPpr h = hPrintDoc h . ppr

showFromPpr :: Ppr a => Int -> a -> ShowS
showFromPpr p t = renderS (pprPrec p t)

pprFromShow :: Show a => Int -> a -> Doc
pprFromShow p t = text (showsPrec p t "")

--
-- Some indentation operations
--

liftEmpty :: (Doc -> Doc -> Doc) -> Doc -> Doc -> Doc
liftEmpty joiner d1 d2 = askD f where
  f e | isEmptyIn e d1 = d2
      | isEmptyIn e d2 = d1
      | otherwise      = joiner d1 d2

ifEmpty :: Doc -> Doc -> Doc -> Doc
ifEmpty dc dt df = askD $ \e ->
  if isEmptyIn e dc
    then dt
    else df

(>+>) :: Doc -> Doc -> Doc
(>+>) = flip hang 2

(>?>) :: Doc -> Doc -> Doc
(>?>)  = liftEmpty (>+>)

infixr 5 >+>, >?>

