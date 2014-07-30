{-# LANGUAGE CPP #-}
{-# LANGUAGE ExplicitForAll, ConstraintKinds, FlexibleContexts #-}  -- For :< experiment

{-# OPTIONS_GHC -Wall #-}
{-# OPTIONS_GHC -fcontext-stack=38 #-}
{-# OPTIONS_GHC -fno-warn-type-defaults #-}

{-# OPTIONS_GHC -fno-warn-unused-imports #-} -- TEMP
{-# OPTIONS_GHC -fno-warn-unused-binds   #-} -- TEMP

----------------------------------------------------------------------
-- |
-- Module      :  TreeTest
-- Copyright   :  (c) 2014 Tabula, Inc.
-- 
-- Maintainer  :  conal@tabula.com
-- Stability   :  experimental
-- 
-- Tests with length-typed treetors. To run:
-- 
--   hermit TreeTest.hs -v0 -opt=LambdaCCC.Monomorphize DoTree.hss resume && ./TreeTest
--   
-- Remove the 'resume' to see intermediate Core.
----------------------------------------------------------------------

-- module TreeTest where

-- TODO: explicit exports

import Prelude hiding (foldr,sum,product)

import Control.Applicative (Applicative(..),liftA2)

import Data.Foldable (Foldable(..),sum,product)
import Data.Traversable (Traversable(..))

-- transformers
import Data.Functor.Identity

import TypeUnary.TyNat
import TypeUnary.Nat (IsNat)
import TypeUnary.Vec
import Circat.RTree
-- Strange -- why needed? EP won't resolve otherwise. Bug?
import qualified LambdaCCC.Lambda
import LambdaCCC.Lambda (EP,reifyEP)

import LambdaCCC.Misc (Unop,Binop)

import Circat.Misc (Unop)
import Circat.Pair (Pair(..))
import Circat.RTree (TreeCat(..))
import Circat.Circuit (GenBuses)

import LambdaCCC.Run (run)

-- Experiment for Typeable resolution in reification
import qualified Data.Typeable

{--------------------------------------------------------------------
    Examples
--------------------------------------------------------------------}

t0 :: Tree N0 Bool
t0 = pure True

t1 :: Tree N1 Bool
t1 = B (pure t0)

p1 :: Unop (Pair Bool)
p1 (a :# b) = b :# a

psum :: Num a => Pair a -> a
psum (a :# b) = a + b

-- tsum :: Num a => Tree n a -> a
-- tsum = foldT id (+)

-- dot :: (IsNat n, Num a) => Tree n a -> Tree n a -> a
-- dot as bs = tsum (prod as bs)

prod :: (Functor f, Num a) => f (a,a) -> f a
prod = fmap (uncurry (*))

prodA :: (Applicative f, Num a) => Binop (f a)
prodA = liftA2 (*)

-- dot :: Num a => Tree n (a,a) -> a
-- dot = tsum . prod

dot :: (Functor f, Foldable f, Num a) => f (a,a) -> a
dot = sum . prod

squares :: (Functor f, Num a) => f a -> f a
squares = fmap (\ x -> x * x)

squares' :: (Functor f, Num a) => f a -> f a
squares' = fmap (^ (2 :: Int))

dot' :: (Applicative f, Foldable f, Num a) => f a -> f a -> a
dot' as bs = sum (prodA as bs)

dot'' :: (Foldable g, Functor g, Foldable f, Num a) => g (f a) -> a
dot'' = sum . fmap product

dot''' :: (Traversable g, Foldable f, Applicative f, Num a) => g (f a) -> a
dot''' = dot'' . sequenceA

{--------------------------------------------------------------------
    Run it
--------------------------------------------------------------------}

go :: GenBuses a => String -> (a -> b) -> IO ()
go name f = run name (reifyEP f)

-- Only works when compiled with HERMIT
main :: IO ()

-- main = go "tdott-0" (dot''' :: Pair (Tree N0 Int) -> Int)

-- main = go "test" (dot'' :: Tree N4 (Pair Int) -> Int)

-- main = go "plusInt" ((+) :: Int -> Int -> Int)
-- main = go "or" ((||) :: Bool -> Bool -> Bool)

-- main = go "tsum-12" (sum :: Tree N12 Int -> Int)

-- main = go "tmap-5" (fmap not :: Unop (Tree N5 Bool))

-- main = go "test" (uncurry (dot' :: Tree N0 Int -> Tree N0 Int -> Int))

-- main = do go "squares3" (squares :: Tree N3 Int -> Tree N3 Int)
--           go "sum4"     (sum     :: Tree N4 Int -> Int)
--           go "dot4"     (dot     :: Tree N4 (Int,Int) -> Int)

-- Problematic examples:

-- -- This one leads to non-terminating CCC construction when the composeApply
-- -- optimization is in place.
-- main = go "dot1" (dot :: Tree N1 (Int,Int) -> Int)

-- main = go "test" (dot :: Tree N4 (Int,Int) -> Int)

main = go "tpsequence-4" (sequenceA :: Tree N4 (Pair Int) -> Pair (Tree N4 Int))

-- main = go "tdot-4" (dot :: Tree N4 (Int,Int) -> Int)

-- main = go "tpdot-4" (dot'' :: Tree N4 (Pair Int) -> Int)

-- -- Doesn't wedge.
-- main = go "dotp" ((psum . prod) :: Pair (Int,Int) -> Int)

-- main = go "prod1" (prod :: Tree N1 (Int,Int) -> Tree N1 Int)

-- main = go "dot5" (dot :: Tree N5 (Int,Int) -> Int)

-- main = go "squares1" (squares :: Unop (Tree N1 Int))

-- main = go "squares2" (squares :: Unop (Tree N2 Int))

-- main = go "squares0" (squares :: Unop (Tree N0 Int))

-- main = go "psum" (psum :: Pair Int -> Int)

-- main = go "tsum1" (tsum :: Tree N1 Int -> Int)

-- -- Not working yet: the (^) is problematic.
-- main = go "squares2" (squares' :: Unop (Tree N0 Int))

-- -- Working out a reify issue.
-- main = go "sum2f" (sum :: Tree N2 Int -> Int)

-- -- Causes a GHC RTS crash ("internal error: stg_ap_pp_ret") with Reify.
-- -- Seemingly infinite rewrite loop with Standard.
-- main = go "prodA1" (uncurry prodA :: (Tree N1 Int,Tree N1 Int) -> Tree N1 Int)

-- main = go "prodA0" (uncurry prodA :: (Tree N0 Int,Tree N0 Int) -> Tree N0 Int)

-- main = go "idA" (uncurry f)
--  where
--    f :: Identity Bool -> Identity Bool -> Identity (Bool,Bool)
--    f = liftA2 (,)
