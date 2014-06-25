{-# OPTIONS_GHC -Wall #-}
module Transform.Expression (crawl, checkPorts) where

import Control.Applicative ( Applicative, (<$>), (<*>) )
import AST.Annotation ( Annotated(A) )
import AST.Expression.General
import qualified AST.Expression.Valid as Valid
import AST.Type (CanonicalType)

checkPorts :: (String -> CanonicalType -> Either err ())
           -> (String -> CanonicalType -> Either err ())
           -> Valid.CanonicalExpr
           -> Either err Valid.CanonicalExpr
checkPorts inCheck outCheck expr = go expr
    where
      go = crawl (mapM checkDef) checkPort

      checkDef def@(Valid.Definition _ body _) =
          do _ <- checkPorts inCheck outCheck body
             return def

      checkPort region port =
          A region . Extras <$>
          case port of
            Valid.PortIn name st ->
                do inCheck name st
                   return $ Valid.PortIn name st

            Valid.PortOut name st signal ->
                do outCheck name st
                   Valid.PortOut name st <$> go signal


crawl :: (Monad m, Applicative m) =>
         ([def] -> m [def'])
      -> (ann -> ext -> m (Expr ann def' ext' var))
      -> Expr ann def ext var
      -> m (Expr ann def' ext' var)
crawl defsTransform extTransform = go
    where
      go (A region expr) =
          A region <$>
          case expr of
            Var x -> return (Var x)
            Lambda p e -> Lambda p <$> go e
            Binop op e1 e2 -> Binop op <$> go e1 <*> go e2
            Case e cases -> Case <$> go e <*> mapM (\(p,b) -> (,) p <$> go b) cases
            Data name es -> Data name <$> mapM go es
            Literal lit -> return (Literal lit)
            Range e1 e2 -> Range <$> go e1 <*> go e2
            ExplicitList es -> ExplicitList <$> mapM go es
            App e1 e2 -> App <$> go e1 <*> go e2
            MultiIf branches -> MultiIf <$> mapM (\(b,e) -> (,) <$> go b <*> go e) branches
            Access e lbl -> Access <$> go e <*> return lbl
            Remove e lbl -> Remove <$> go e <*> return lbl
            Insert e lbl v -> Insert <$> go e <*> return lbl <*> go v
            Modify e fields -> Modify <$> go e <*> mapM (\(k,v) -> (,) k <$> go v) fields
            Record fields -> Record <$> mapM (\(k,v) -> (,) k <$> go v) fields
            Markdown uid md es -> Markdown uid md <$> mapM go es
            Let defs body -> Let <$> defsTransform defs <*> go body
            GLShader uid src gltipe -> return $ GLShader uid src gltipe
            Extras port -> do (A _ e) <- extTransform region port
                              return e
