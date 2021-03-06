module Control.InjFun (
    -- * Inject function
    InjFun
  , cfapply
  , inject
    -- * Exploding and merging
  , explode
  , merge
    -- * Combinators
  , (||->)
  , (|->)
  , (-<)
  , (-<|)
  , (>-)
  , (>-|)
  ) where

-- |Function able to be injected parameters in.
-- `c` is the injected control parameters, `i` represents its input, `m` is the resulting monad
-- and `o` is the output.
newtype InjFun c i m o = InjFun {
  -- |Feed a `InjFun` with its regular parameters and injected parameters.
  cfapply :: c -> i -> m o
  }

-- |Create an inject function.
inject :: (c -> i -> m o) -> InjFun c i m o
inject f = InjFun f

-- |Sequencing operator. It’s a helper function that composes with `>>=` the two `InjFun`, respecting
-- the order.
--
-- That version (with a single `|`) means that both the two injected parameters are considered
-- the same; then they’re shared as a single `c`.
(|->) :: (Monad m) => InjFun c i m o  -- ^ First function
                   -> InjFun c o m o' -- ^ Second function
                   -> InjFun c i m o' -- ^ Resulting sequencing function
f |-> g = InjFun $ \c i -> cfapply f c i >>= cfapply g c

-- |Sequencing operator. It’s a helper function that composes with `>>=` the two `InjFun`, respecting
-- the order.
--
-- That version (with double `|`) means that the two injected parameters are considered
-- different.
(||->) :: (Monad m) => InjFun c i m o       -- ^ First function
                    -> InjFun c' o m o'     -- ^ Second function
                    -> InjFun (c,c') i m o' -- ^ Resulting sequencing function
f ||-> g = InjFun $ \(c,c') i -> cfapply f c i >>= cfapply g c'

-- |Explode an `InjFun` that outputs two values into two other `InjFun`.
explode :: (Monad m) => InjFun c i m (o0,o1)              -- ^ Function to explode
                     -> (InjFun c i m o0,InjFun c i m o1) -- ^ Exploded functions
explode f = (f',f'')
  where f'  = cf fst
        f'' = cf snd
        cf sel = InjFun $ \c i -> cfapply f c i >>= return . sel

-- |Merge two `InjFun` into one.
merge :: (Monad m) => InjFun c0 i0 m o0                -- ^ First function
                   -> InjFun c1 i1 m o1                -- ^ Second function
                   -> InjFun (c0,c1) (i0,i1) m (o0,o1) -- ^ Merged function
merge f g = fg
  where fg = InjFun $ \(c0,c1) (i0,i1) -> do
                r0 <- cfapply f c0 i0
                r1 <- cfapply g c1 i1
                return (r0,r1)

-- |Explode an `InjFun` and feed two other ones with exploded parts of it.
--
-- In that version, each of the three functions has its own inject parameter.
(-<) :: (Monad m) => InjFun c i m (o0,o1)                           -- ^ Function to explode
                  -> (InjFun c' o0 m o0',InjFun c'' o1 m o1')       -- ^ Functions to feed
                  -> (InjFun (c,c') i m o0',InjFun (c,c'') i m o1') -- ^ Exploded and fed functions
f -< (g,h) = (g',h')
  where g'       = f'  ||-> g
        h'       = f'' ||-> h
        (f',f'') = explode f

-- |Explode an `InjFun` and feed two other ones with exploded parts of it.
--
-- In that version, all the three functions share the same inject parameter.
(-<|) :: (Monad m) => InjFun c i m (o0,o1)                  -- ^ Function to explode
                   -> (InjFun c o0 m o0',InjFun c o1 m o1') -- ^ Functions to feed
                   -> (InjFun c i m o0',InjFun c i m o1')   -- ^ Exploded and fed functions
f -<| (g,h) = (g',h')
  where g'       = f'  |-> g 
        h'       = f'' |-> h
        (f',f'') = explode f

-- |Merge two `InjFun` and feed another one with the merged function.
--
-- In that version, each of the three functions has it its own inject parameter.
(>-) :: (Monad m) => (InjFun c0 i0 m o0,InjFun c1 i1 m o1) -- ^ Functions to merge
                  -> InjFun c2 (o0,o1) m o'                -- ^ Function to feed
                  -> InjFun (c0,c1,c2) (i0,i1) m o'        -- ^ Merged and fed function
(g,h) >- f = inject $ \(c0,c1,c2) i -> cfapply (merge g h) (c0,c1) i >>= cfapply f c2

-- |Merge two `InjFun` and feed another one with the merged function.
--
-- In that version, all the three functions share the same inject parameter.
(>-|) :: (Monad m) => (InjFun c i0 m o0,InjFun c i1 m o1) -- ^ Functions to merge
                   -> InjFun c (o0,o1) m o'               -- ^ Function to feed
                   -> InjFun c (i0,i1) m o'               -- ^ Merged and fed function
(g,h) >-| f = inject $ \c i -> cfapply (merge g h) (c,c) i >>= cfapply f c
