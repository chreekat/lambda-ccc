{-# LANGUAGE TypeOperators, GADTs, PatternGuards, ScopedTypeVariables #-}
{-# LANGUAGE FlexibleInstances, MultiParamTypeClasses #-}
{-# LANGUAGE ConstraintKinds, RankNTypes, CPP #-}
{-# OPTIONS_GHC -Wall #-}

-- {-# OPTIONS_GHC -fno-warn-unused-imports #-} -- TEMP
-- {-# OPTIONS_GHC -fno-warn-unused-binds   #-} -- TEMP

----------------------------------------------------------------------
-- |
-- Module      :  LambdaCCC.ToCCC
-- Copyright   :  (c) 2013 Tabula, Inc.
-- License     :  BSD3
-- 
-- Maintainer  :  conal@tabula.com
-- Stability   :  experimental
-- 
-- Convert lambda expressions to CCC combinators
----------------------------------------------------------------------

module LambdaCCC.ToCCC (toCCC {-, HasLambda(..) -}) where

import Prelude hiding (id,(.),curry,uncurry,const)

import Data.Functor ((<$>))
import Control.Monad (mplus)
import Data.Maybe (fromMaybe)

import Data.Proof.EQ

import LambdaCCC.Misc
import LambdaCCC.Prim (Prim)
import LambdaCCC.Lambda
import LambdaCCC.CCC ((:->)(Const))     -- Remaining dependency

import Circat.Category

{--------------------------------------------------------------------
    Conversion
--------------------------------------------------------------------}

-- toCCC' :: E a -> (Unit :-> a)
-- toCCC' = convert UnitPat

-- #define PlainConvert

#ifdef PlainConvert

-- | Rewrite a lambda expression via CCC combinators
toCCC :: E (a :=> b) -> (a :-> b)
toCCC (Lam p e) = convert e p
toCCC e = toCCC (Lam vp (e :^ ve))
 where
   (vp,ve) = vars "ETA"

-- | Convert @\ p -> e@ to CCC combinators
convert :: forall a b k. (BiCCC k, k ~ (:->))  =>
           E b -> Pat a -> (a `k` b)
convert (ConstE o)   _ = Const o
convert (Var v)      k = convertVar v k
convert (u :^ v)     k = apply . (convert u k &&& convert v k)
convert (Lam p e)    k = curry (convert e (k :# p))
convert (Either f g) k = curry ((convert' f ||| convert' g) . ldistribS)
 where
   convert' :: E (p :=> q) -> ((a :* p) `k` q)
   convert' h = uncurry (convert h k)

#else

infixl 9 @@
infixr 2 ||||

class HasLambda e where
  constL :: Prim a -> e a
  varL   :: V a -> e a
  (@@)   :: e (a :=> b) -> e a -> e b
  lamL   :: Pat a -> e b -> e (a :=> b)
  (||||) :: e (a -> c) -> e (b -> c) -> e (a :+ b -> c)

instance HasLambda E where
  constL = ConstE
  varL   = Var
  (@@)   = (:^)
  lamL   = Lam
  (||||) = Either

-- | Convert from 'E' to any 'HasLambda'
convertE :: HasLambda ex => E b -> ex b
convertE (ConstE o)   = constL o
convertE (Var v)      = varL v
convertE (s :^ t)     = convertE s @@ convertE t
convertE (Lam p e)    = lamL p (convertE e)
convertE (Either f g) = convertE f |||| convertE g

-- | Rewrite a lambda expression via CCC combinators
toCCC :: E (a :=> b) -> (a :-> b)
toCCC (Lam p e) = unEx (convertE e) p
toCCC e = toCCC (Lam vp (e :^ ve))
 where
   (vp,ve) = vars "ETA"

-- | Generation of CCC terms in a binding context
newtype Ex b = Ex { unEx :: forall a. Pat a -> (a :-> b) }

-- TODO:
-- 
--   type Ex b = forall a k. BiCCC k => Pat a -> (a `k` b)

instance HasLambda Ex where
  constL o       = Ex (\ _ -> Const o)
  varL x         = Ex (\ k -> convertVar x k)
  Ex u @@ Ex v   = Ex (\ k -> apply . (u k &&& v k))
  lamL p (Ex u)  = Ex (\ k -> curry (u (k :# p)))
  Ex f |||| Ex g = Ex (\ k -> curry ((uncurry (f k) ||| uncurry (g k)) . ldistribS))

-- Experiment: a universal instance

newtype Lambda a = L (forall f . HasLambda f => f a)

instance HasLambda Lambda where
  constL o     = L (constL o)
  varL x       = L (varL x)
  L u @@ L v   = L (u @@ v)
  lamL p (L u) = L (lamL p u)
  L f |||| L g = L (f |||| g)

#endif

-- TODO: Handle constants in a generic manner, so we can drop the constraint that k ~ (:->).

-- convert k (Case (a,p) (b,q) ab) =
--   (convert (k :# a) p ||| convert (k :# b) q) . ldistribS . (Id &&& convert k ab)

-- Convert a variable in context
convertVar :: forall b a k. ProductCat k =>
              V b -> Pat a -> (a `k` b)
convertVar u = fromMaybe (error $ "convert: unbound variable: " ++ show u) .
               conv
 where
   conv :: forall c. Pat c -> Maybe (c `k` b)
   conv (VarPat v) | Just Refl <- v ==? u = Just id
                   | otherwise            = Nothing
   conv UnitPat  = Nothing
   conv (p :# q) = ((. exr) <$> conv q) `mplus` ((. exl) <$> conv p)
   conv (p :@ q) = conv q `mplus` conv p

-- Note that we try q before p. This choice cooperates with uncurrying and
-- shadowing.

-- Alternatively,
-- 
--    conv (p :# q) = descend exr q `mplus` descend exl p
--     where
--       descend :: (c `k` d) -> Pat d -> Maybe (c `k` b)
--       descend sel r = (. sel) <$> conv r
