{-# LANGUAGE
      RankNTypes,
      TemplateHaskell #-}
module Syntax.SyntaxTable where

import Meta.THHelpers
import Syntax.Anti
import Syntax.Notable
import Syntax.Ident
import Syntax.Kind
import Syntax.Type
import Syntax.Lit
import Syntax.Patt
import Syntax.Expr
import Syntax.Decl

import qualified Data.Map as M
import qualified Language.Haskell.TH as TH

litAntis, pattAntis,
  exprAntis, bindingAntis, caseAltAntis,
  typeAntis, quantAntis, qExpAntis, tyVarAntis,
  declAntis, tyDecAntis, absTyAntis, modExpAntis,
  lidAntis, uidAntis, qlidAntis, quidAntis, idAntis, noAntis
    :: AntiDict

litAntis
  = "lit"    =:  Nothing
  & "str"    =:< 'LtStr
  & "int"    =:< 'LtInt
  & "flo"    =:< 'LtFloat
  & "float"  =:< 'LtFloat
  & "antiL"  =:< 'LtAnti
pattAntis
  = "patt"   =:! Nothing
  & "anti"   =:< 'PaAnti
exprAntis
  = "expr"   =:! Nothing
  & "anti"   =:< 'ExAnti
bindingAntis
  = "bind"   =:! Nothing
  & "anti"   =:< 'BnAnti
caseAltAntis
  = "case"   =:  Nothing
  & "caseA"  =:< 'CaAnti
typeAntis
  = "type"   =:! Nothing
  & "stx"    =:  appFun (TH.mkName "typeToStx'")
  & "anti"   =:< 'TyAnti
quantAntis
  = "quant"  =:  Nothing
  & "antiQ"  =:< 'QuantAnti
qExpAntis
  = "qexp"   =:! Nothing
  & "qlit"   =:< 'QeLit
  & "qvar"   =:< 'QeVar
  & "qdisj"  =:< 'QeDisj
  & "qconj"  =:< 'QeConj
  & "anti"   =:< 'QeAnti
tyVarAntis
  = "tyvar"  =:! Nothing
  & "anti"   =:< 'TVAnti
declAntis
  = "decl"   =:! Nothing
  & "anti"   =:< 'DcAnti
tyDecAntis
  = "tydec"  =:! Nothing
  & "anti"   =:< 'TdAnti
absTyAntis
  = "absty"  =:! Nothing
  & "anti"   =:< 'AbsTyAnti
modExpAntis
  = "mod"    =:! Nothing
  & "anti"   =:< 'MeAnti
lidAntis
  = "lid"    =:  Nothing
  & "name"   =:  Just (\v -> varS 'lid [varS v []]
                    `whichS` conS 'Lid [wildS, varS v []])
  & "antiLid"=:< 'LidAnti
uidAntis
  = "uid"    =:  Nothing
  & "uname"  =:  Just (\v -> varS 'uid [varS v []]
                    `whichS` conS 'Uid [wildS, varS v []])
  & "antiUid"=:< 'LidAnti
qlidAntis
  = "qlid"   =:  Nothing
  & "qname"  =:  appFun 'qlid -- error in pattern context
quidAntis
  = "quid"   =:  Nothing
  & "quname" =:  appFun 'quid -- error in pattern context
idAntis
  = "id"     =:  Nothing
noAntis
  = M.empty

appFun :: ToSyntax b => TH.Name -> Maybe (String -> TH.Q b)
appFun n = Just (\v -> varS n [varS v []])

syntaxTable :: SyntaxTable
syntaxTable =
  [ ''Prog    =:: 'Prog                       !: 'newN       >: (''Id, [0])
  , ''Lit     =:: 'LtAnti    $: 'litAntis
  , ''Patt    =:: 'PaAnti    $: 'pattAntis    !: 'newN
  , ''Expr    =:: 'ExAnti    $: 'exprAntis    !: 'newExpr    >: (''Id, [0])
  , ''Binding =:: 'BnAnti    $: 'bindingAntis !: 'newBinding >: (''Id, [0])
  , ''CaseAlt =:: 'CaAnti    $: 'caseAltAntis !: 'newCaseAlt >: (''Id, [0])
  , ''Type    =:: 'TyAnti    $: 'typeAntis    !: 'newN
  , ''Quant   =:: 'QuantAnti $: 'quantAntis
  , ''QExp    =:: 'QeAnti    $: 'qExpAntis    !: 'newN
  , ''TyVar   =:: 'TVAnti    $: 'tyVarAntis
  , ''Decl    =:: 'DcAnti    $: 'declAntis    !: 'newDecl    >: (''Id, [0])
  , ''TyDec   =:: 'TdAnti    $: 'tyDecAntis   !: 'newN
  , ''AbsTy   =:: 'AbsTyAnti $: 'absTyAntis   !: 'newN
  , ''ModExp  =:: 'MeAnti    $: 'modExpAntis  !: 'newModExp  >: (''Id, [0])
  , ''Lid     =:: 'LidAnti   $: 'lidAntis
  , ''Uid     =:: 'UidAnti   $: 'uidAntis
  , ''QLid    =:: '()
  , ''QUid    =:: '()
  , ''Ident   =:: '()
  ]
