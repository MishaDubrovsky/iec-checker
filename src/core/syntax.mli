module TI = Tok_info

exception InternalError of string

(** Representation of time interval

    According the IEC61131-3 3rd edition grammar, all interval values defined as
    fix_point. That means that these values could be represented as float values.
*)
module TimeValue : sig
  type t

  val mk :
    ?y:int ->
    ?mo:int ->
    ?d:float ->
    ?h:float ->
    ?m:float ->
    ?s:float ->
    ?ms:float ->
    ?us:float ->
    ?ns:float ->
    unit ->
    t

  val ( + ) : t -> t -> t

  val inv : t -> t
  (** Invert time value to represent a negative duration. *)

  val to_string : t -> string

  val is_zero : t -> bool
end

(* {{{ Operators *)
(** Operators of the ST language *)
type operator =
  | NEG
  | NOT
  | POW
  | MUL
  | DIV
  | MOD
  | AND (** & AND *)
  | ADD (** + *)
  | SUB (** - *)
  | OR (** OR *)
  | XOR (** XOR *)
  | GT (** > *)
  | LT (** < *)
  | GE (** >= *)
  | LE (** <= *)
  | EQ (** = *)
  | NEQ (** <> *)
  | ASSIGN
[@@deriving show]
(* }}} *)

(* {{{ Variables and identifiers *)

(** Description of use -- nondefining occurence of an identifier *)
module type ID = sig
  type t
  val create : string -> TI.t -> t
  val get_name : t -> string
  val get_ti : t -> TI.t
end

(** Identifier of symbolically represented variable *)
module SymVar : ID

(** Identifier of directly represented variable *)
module DirVar : sig
  include ID

  (** Location prefixes for directly represented variables.
      See 6.5.5.2 for explainations. *)
  type location = LocI | LocQ | LocM

  (** Size prefixes for directly represented variables. *)
  type size =
    | SizeX    (** single bit *)
    | SizeNone (** single bit *)
    | SizeB    (** byte *)
    | SizeW    (** word (16 bits) *)
    | SizeD    (** double word (32 bits) *)
    | SizeL    (** quad word (64 bits) *)

  val create : string option -> TI.t -> location -> size option -> int list -> t
  val get_name : t -> string
end

(** Function Block identifier *)
module FunctionBlock : sig
  include ID
  val is_std : t -> bool
end

(** Function identifier *)
module Function : sig
  include ID
  val is_std : t -> bool
  (** Returns true if function declared in standard library. *)
end

type variable = SymVar of SymVar.t | DirVar of DirVar.t

val vget_name : variable -> string
(** Return name of a given variable *)

val vget_ti : variable -> TI.t
(** Return token info of a given variable *)
(* }}} *)

(* {{{ Data types, constants and statements *)
type iec_data_type =
  | TyElementary of elementary_ty
  | TyGeneric of generic_ty
  | TyDerived of derived_ty

and elementary_ty =
  | NIL (* TODO: replace with an empty symbol *)
  | STRING
  | WSTRING
  | CHAR
  | WCHAR
  | TIME
  | LTIME
  | SINT
  | INT
  | DINT
  | LINT
  | USINT
  | UINT
  | UDINT
  | ULINT
  | REAL
  | LREAL
  | DATE
  | LDATE
  | TIME_OF_DAY
  | TOD
  | LTOD
  | DATE_AND_TIME
  | LDATE_AND_TIME
  | DT
  | LDT
  | BOOL
  | BYTE
  | WORD
  | DWORD
  | LWORD

and generic_ty =
  | ANY
  | ANY_DERIVED
  | ANY_ELEMENTARY
  | ANY_MAGNITUDE
  | ANY_NUM
  | ANY_REAL
  | ANY_INT
  | ANY_BIT
  | ANY_STRING
  | ANY_DATE

(** "Use" occurence of a derived type *)
and derived_ty =
  | DTyUseSingleElement of single_element_ty_spec
  (* | DTyUseArrayType *)
  (* | DTyUseStructType *)
  | DTyUseStringType of elementary_ty (** string type spec *) *
                        int (** length *)

(** Declaration of a derived type.
    This include "use" symbol value of a declared type and optional
    initialization values. *)
and derived_ty_decl =
  | DTyDeclSingleElement of single_element_ty_spec (** declaration ty *) *
                            single_element_ty_spec (** initialization ty *) *
                            expr option (** initialization expression *)
  (* | DTyDeclArrayType *)
  (* | DTyDeclStructType *)
  | DTyDeclStringType of string (** ty name *) *
                         derived_ty (** declaration ty *) *
                         string (** initial value *) option

(** Single element type specification (it works like typedef in C). *)
and single_element_ty_spec =
  | DTySpecElementary of elementary_ty
  | DTySpecSimple of string (** derived ty name *)

and constant =
  | CInteger of int * TI.t
  | CBool of bool * TI.t
  | CReal of float * TI.t
  | CString of string * TI.t
  | CTimeValue of TimeValue.t * TI.t
[@@deriving show]

and statement =
  | StmAssign of TI.t *
                 variable *
                 expr
  | StmElsif of TI.t *
                expr * (** condition *)
                statement list (** body *)
  | StmIf of TI.t *
             expr * (** condition *)
             statement list * (** body *)
             statement list * (** elsif statements *)
             statement list (** else *)
  | StmCase of TI.t *
               expr * (** condition *)
               case_selection list *
               statement list (* else *)
  | StmFor of (TI.t *
               SymVar.t * (** control variable *)
               expr * (** range start *)
               expr * (** range end *)
               expr option * (** range step *)
               statement list (** body statements *) [@opaque])
  | StmWhile of TI.t *
                expr * (** condition *)
                statement list (** body *)
  | StmRepeat of TI.t *
                 statement list * (** body *)
                 expr (** condition *)
  | StmFuncParamAssign of string option * (** function param name *)
                          expr * (** assignment expression *)
                          bool (** has inversion in output assignment *)
  | StmFuncCall of TI.t *
                   Function.t *
                   statement list (** params assignment *)
[@@deriving show]

and expr =
  | Variable of variable
  | Constant of constant
  | BinExpr of expr * operator * expr
  | UnExpr of operator * expr
  | FuncCall of statement
[@@deriving show]

and case_selection = {case: expr list; body: statement list}
[@@deriving show]

(* }}} *)

(* {{{ Functions to work with constants *)
val c_is_zero : constant -> bool
(** Return true if constant value is zero, false otherwise *)

val c_get_str_value : constant -> string
(** Return string representation for value of a given constant *)

val c_get_ti : constant -> TI.t
(** Return token info of a given constant *)

val c_add : constant -> constant -> constant
(** Add value to existing constant. *)

val c_from_expr : expr -> constant option
(** Convert given expr to const. *)

val c_from_expr_exn : expr -> constant
(** Convert given expr to const. Raise an InternalError exception if given expr is not constant.  *)
(* }}} *)

(* {{{ Configuration objects *)
(** Task configuration.
    See: 6.8.2 Tasks *)
module Task : sig
  type t

  (** Data sources used in task configruation *)
  type data_source =
    | DSConstant of constant
    | DSGlobalVar of variable
    | DSDirectVar of variable
    | DSProgOutput of string (** program name *) * variable

  val create : string -> TI.t -> t

  val set_interval : t -> data_source -> t
  (** Set task interval input. *)

  val set_single : t -> data_source -> t
  (** Set task single input. *)

  val set_priority : t -> int -> t
  (** Set task priority value. *)
end

module ProgramConfig : sig
  type t

  (** Qualifier of IEC program *)
  type qualifier = QRetain | QNonRetain | QConstant

  val create : string -> TI.t -> t

  val set_qualifier : t -> qualifier -> t
  (** Set program qualifier. *)

  val set_task : t -> Task.t -> t
  (** Set task configuration. *)

  val set_conn_vars : t -> variable list -> t
  (** Set connected variables. *)

  val get_name : t -> string
  (** Get name of a program. *)
end
(* }}} *)

(* {{{ Declarations *)
(** Declaration of the IEC variable *)
module VarDecl : sig
  type t

  (** Variable could be connected to input/output data flow of POU. *)
  type direction = Input | Output

  (** Qualifier of IEC variable *)
  type qualifier = QRetain | QNonRetain | QConstant

  (** Variable specification *)
  type spec =
    | Spec of qualifier option
    | SpecDirect of qualifier option
    | SpecOut of qualifier option
    | SpecIn of qualifier option
    | SpecInOut
    | SpecExternal of qualifier option
    | SpecGlobal of qualifier option
    | SpecAccess of string (** access name *)
    | SpecTemp
    | SpecConfig of
        string (** resource name *) * string (** program name *) * string (** fb name *)

  val create : variable -> spec -> t

  val get_var : t -> variable

  val get_var_name : t -> string

  val set_qualifier_exn : t -> qualifier -> t
  (** Set qualifier for variable. Raise an exception if this variable doesn't support qualifiers. *)

  val get_direction : t -> direction option

  val set_direction : t -> direction -> t
end

(** Function declaration *)
type function_decl = {
  id : Function.t;
  return_ty : iec_data_type;
  variables : VarDecl.t list;
  statements : statement list;
}

(** Function block declaration *)
type fb_decl = {
  id : FunctionBlock.t;
  variables : VarDecl.t list;
  statements : statement list;
}

type program_decl = {
  is_retain : bool;
  name : string;
  variables : VarDecl.t list; (** Variables declared in this program *)
  statements : statement list;
}

type resource_decl = {
  name : string option; (** Resource name. Can be is skipped in case of single resource *)
  tasks : Task.t list;
  variables : VarDecl.t list; (** Global variables *)
  programs : ProgramConfig.t list; (** Configuration of program instances. *)
}

(** Configuration element.
    See: 2.7 Configuration elements *)
type configuration_decl = {
  name : string;
  resources : resource_decl list;
  variables : VarDecl.t list; (** Global variables and access lists *)
  access_paths : string list;
}

(* }}} *)

type iec_library_element =
  | IECFunction of function_decl
  | IECFunctionBlock of fb_decl
  | IECProgram of program_decl
  | IECConfiguration of configuration_decl
  | IECType of derived_ty_decl list

val get_pou_vars_decl : iec_library_element -> VarDecl.t list
(** Return variables declared for given POU *)

(* vim: set foldmethod=marker foldlevel=0 foldenable : *)
