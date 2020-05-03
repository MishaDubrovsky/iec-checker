(* Demo check: Find division to a zero constant. *)

open Core_kernel
module S = IECCheckerCore.Syntax
module TI = IECCheckerCore.Tok_info
module AU = IECCheckerCore.Ast_util
module Warn = IECCheckerCore.Warn

let rec collect_warnings (e: S.expr) : Warn.t list =
  match e with
  | S.ExprBin (_, e1, op, e2) -> (
      match (e1, op, e2) with
      | S.ExprBin _, _, _ -> collect_warnings e1
      | _, _, S.ExprBin _ -> collect_warnings e2
      | S.ExprVariable(_, lhs), S.DIV, S.ExprConstant(_, rhs) ->
        if S.c_is_zero rhs then
          let name = S.vget_name lhs in
          let ti = S.vget_ti lhs in
          let msg = (Printf.sprintf "Variable %s is divided by zero!" name) in
          let w = Warn.mk ti.linenr ti.col "ZeroDivision" msg in
          [w]
        else
          []
      | S.ExprConstant(_,lhs), S.DIV, S.ExprConstant(_,rhs) ->
        if S.c_is_zero rhs then
          let v_str = S.c_get_str_value lhs in
          let ti = S.c_get_ti lhs in
          let msg = (Printf.sprintf "Constant %s is divided by zero!" v_str) in
          let w = Warn.mk ti.linenr ti.col "ZeroDivision" msg in
          [w]
        else
          []
      | _ -> [] )
  | _ -> []

let do_check elems =
  let all_exprs = AU.get_exprs elems in
  List.fold_left all_exprs
    ~init:[]
    ~f:(fun acc ws -> acc @ (collect_warnings ws))
