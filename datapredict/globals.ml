open Batteries
open Str
open Printf
open Cil
open Utils
open DPGlobs

(* actual program-specific global types and variables *)

type rank = { (* sum or record? *)
  f_P : int;
  s_P : int;
  f_P_obs : int;
  s_P_obs : int;
  numF : int;
  failure_P : float;
  context : float;
  increase : float;
  importance : float;
}

let inc = (fun rank -> rank.increase)
let con = (fun rank -> rank.context)
let imp = (fun rank -> rank.importance)
let failure = (fun rank -> rank.failure_P)

let inc_sort = (fun rank1 -> fun rank2 ->
				  compare rank2.increase rank1.increase)
let con_sort = (fun rank1 -> fun rank2 ->
				  compare rank2.context rank1.context)
let imp_sort = (fun rank1 -> fun rank2 ->
			      compare rank2.importance rank1.importance)
let fail_sort = (fun rank1 -> fun rank2 ->
				   compare rank2.failure_P rank1.failure_P)

(* a state_sequence is a run number, a start state, and a set of state ids of
   states visited along the way
   I THINK that for now it's fine to only add a state once to the run; we just
   want to make sure we visit it when relevant when counting.
   Also the idea of a sequence here is a misnomer because sets don't preserve
   order but if that matters later we can figure it out then.
*) 

type stateSeq = int *  int * IntSet.t

type memV = Int of int | Float of float 
let mval_of_string str = 
  try (Float(float_of_string str)) with _ -> (Int(int_of_string str))

let string_of_mval mval = 
  match mval with
	Int(i) -> Printf.sprintf "Int(%d)" i
  | Float(f) -> Printf.sprintf "Float(%g)" f

let fname_to_run_num : (string, int) Hashtbl.t ref = ref (hcreate 10)
(* inexplicably, "PASS" is 0 and FAIL is 1 in the following hashtable *)
let run_num_to_fname_and_good : (int, (string * int)) Hashtbl.t ref = ref (hcreate 10)

let name = ref "default"

type strategy = Intersect of float | FailureP | Increase | Context | Importance
				  | Random | Uniform

let strat_to_string strat =
  match strat with 
	Intersect(weight) -> sprintf "intersection%02g" weight
  | FailureP -> "failure"
  | Increase -> "increase"
  | Context -> "context"
  | Importance -> "importance"
  | Random -> "random"
  | Uniform -> "uniform"

let num_rand = ref 1
