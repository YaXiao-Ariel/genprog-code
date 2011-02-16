(* step 1: given a project, a URL, and a start and end revision,
 * collect all changes referencing bugs, bug numbers, or "fix."
 * 1a: diff option 1: tree-based diffs
 * 1b: diff option 2: syntactic (w/alpha-renaming)
 * step 2: process each change
 * step 3: cluster changes (distance metric=what is Ray doing/Hamming
 * distance from Gabel&Su, FSE 10?)
 *)

open Batteries
open List
open Unix
open Utils
open Globals
open Diffs
open Datapoint
open Cluster
open Distance
open Difftypes
open Diffs
open Tprint
open User

let xy_data = ref ""
let test_distance = ref false 
let diff_files = ref []
let test_change_diff = ref false
let test_cabs_diff = ref false
let test_templatize = ref false 
let test_perms = ref false
let test_unify = ref false 

let templatize = ref ""

let fullload = ref ""
let user_feedback_file = ref ""

let ray = ref ""
let htf = ref ""

let _ =
  options := !options @
	[
	  "--test-cluster", Arg.Set_string xy_data, "\t Test data of XY points to test the clustering";
	  "--test-distance", Arg.Set test_distance, "\t Test distance metrics\n";
	  "--test-cd", Arg.String (fun s -> test_change_diff := true; diff_files := s :: !diff_files), "\t Test change diffing.  Mutually  exclusive w/test-cabs-diff\n";
	  "--test-cabs-diff", Arg.String (fun s -> test_cabs_diff := true;  diff_files := s :: !diff_files), "\t Test C snipped diffing\n";
	  "--test-templatize", Arg.String (fun s -> test_templatize := true;  diff_files := s :: !diff_files), "\t test templatizing\n";
	  "--test-unify", Arg.String (fun s -> test_unify := true; diff_files := s :: !diff_files), "\t test template unification, one level\n"; 
	  "--test-perms", Arg.Set test_perms, "\t test permutations";
	  "--user-distance", Arg.Set_string user_feedback_file, "\t Get user input on change distances, save to X.txt and X.bin";
	  "--fullload", Arg.Set_string fullload, "\t load big_diff_ht and big_change_ht from file, skip diff collecton.";
	  "--combine", Arg.Set_string htf, "\t Combine diff files from many benchmarks, listed in X file\n"; 
	  "--ray", Arg.String (fun file -> ray := file), "\t  Ray mode.  X is config file; if you're Ray you probably want \"default\"";
	  "--templatize", Arg.Set_string templatize, "\t Convert diffs/changes into templates\n";
	]

let ray_logfile = ref ""
let ray_htfile = ref ""
let ray_bigdiff = ref ("/home/claire/taxonomy/main/test_data/ray_full_ht.bin")
let ray_reload = ref true

let ray_options =
  [
	"--logfile", Arg.Set_string ray_logfile, "Write to X.txt.  If .ht file is unspecified, write to X.ht.";
	"--htfile", Arg.Set_string ray_htfile, "Write response ht to X.ht.";
	"--bigdiff", Arg.Set_string ray_bigdiff, "Get diff information from bigdiff; if bigdiff doesn't exist, compose existing default hts and write to X.";
	"--no-reload", Arg.Clear ray_reload, "Don't read in response ht if it already exists/add to it; default=false"
  ]

exception Reload

let main () = 
  begin
	Random.init (Random.bits ());
	let config_files = ref [] in
	let handleArg1 str = config_files := str :: !config_files in 
	let handleArg str = configs := str :: !configs in
	let aligned = Arg.align !options in
	  Arg.parse aligned handleArg1 usageMsg ; 
	  liter (parse_options_in_file ~handleArg:handleArg aligned usageMsg) !config_files;
	  (* If we're testing stuff, test stuff *)
	  if !test_distance then
	    (StringDistance.levenshtein (String.to_list "kitten") (String.to_list "sitting");
	     StringDistance.levenshtein (String.to_list "Saturday") (String.to_list "Sunday"))
	  else if !xy_data <> "" then 
	    let lines = File.lines_of !xy_data in
	    let points = 
	      Set.of_enum 
			(Enum.map 
			   (fun line -> 
				 let split = Str.split comma_regexp line in
				 let x,y = int_of_string (hd split), int_of_string (hd (tl split)) in
				   XYPoint.create x y 
			   ) lines)
		in
		  ignore(TestCluster.kmedoid !k points)
	  else if !test_cabs_diff then begin
		Treediff.test_diff_cabs (lrev !diff_files)
	  end
	  else if !test_change_diff then 
		Treediff.test_diff_change (lrev !diff_files)
	  else if !test_templatize then
		Template.test_template (lrev !diff_files)
	  else if !test_perms then
		ignore(test_permutation ())
	  else if !test_unify then
		Template.testWalker (lrev !diff_files)
	  else begin (* all the real stuff *)
	    if !templatize <> "" then (* templates and clustering! *) begin
	      let diff_ht,_,cabs_ht = just_one_load (List.hd !configs) in
		hiter (fun k -> fun v -> hadd cabs_id_to_diff_tree_node k v) cabs_ht;
		pprintf "Number of diffs: %d\n" (llen (List.of_enum (Hashtbl.keys diff_ht)));
	      let diffs = Template.diffs_to_templates diff_ht !templatize false in (* FIXME: make this an actual flag *)
		pprintf "Number of templates: %d\n" (llen (List.of_enum (Hashtbl.keys diffs)));
		(* can we save halfway through clustering if necessary? *)
		(* FIXME: flattening down to individual changes for testing! *)
	      let diffsenum = List.enum (lflat (List.of_enum (Hashtbl.values diffs))) in
	      let asenum = List.enum (lflat (lflat (List.of_enum (Hashtbl.values diffs)))) in
	      let rand = Random.shuffle asenum in
	      let portion = Array.sub rand 0 50 in
	      let diffs1 = Set.of_enum (Array.enum portion) in
	      let rand2 = Random.shuffle diffsenum in
	      let portion2 = Array.sub rand2 0 50 in
	      let diffs2 = Set.of_enum (Array.enum portion2) in
		if !cluster then begin
		  pprintf "Template cluster1, set:\n";
		  let num = ref 0 in
		  Set.iter (fun t -> pprintf "T%d:\n %s\n" !num (itemplate_to_str t); incr num) diffs1;
		  pprintf "End template cluster1\n";
		  ignore(TemplateCluster.kmedoid !k diffs1);
		  pprintf "Template cluster2, set:\n";
		  Set.iter (fun diffs -> pprintf "SET:\n"; liter print_itemplate diffs; pprintf "END SET\n") diffs2;
		  pprintf "End template cluster2\n";
		  ignore(ChangesCluster.kmedoid !k diffs2)
		end
	    end else begin
	      if !ray <> "" then begin
		pprintf "Hi, Ray!\n";
		pprintf "%s" ("I'm going to parse the arguments in the specified config file, try to load a big hashtable of all the diffs I've collected so far, and then enter the user feedback loop.\n"^
				"Type 'h' at the prompt when you get there if you want more help.\n");
		  let handleArg _ = 
			failwith "unexpected argument in RayMode config file\n"
		  in
		  let aligned = Arg.align ray_options in
		  let config_file  =
			if !ray = "default" 
			then "/home/claire/taxonomy/main/ray_default.config"
			else !ray
		  in
			parse_options_in_file ~handleArg:handleArg aligned "" config_file
		end;
		let big_diff_ht,big_diff_id,benches = 
		  if (!ray_bigdiff <> "" && Sys.file_exists !ray_bigdiff && !ray <> "") || !fullload <> "" then begin
			let bigfile = if !ray_bigdiff <> "" then !ray_bigdiff else !fullload 
			in
			  pprintf "ray bigdiff: %s, fulload: %s\n"  !ray_bigdiff !fullload; Pervasives.flush Pervasives.stdout;
			  full_load_from_file bigfile 
		  end else hcreate 10, 0, []
		in
		let big_diff_ht,big_diff_id = 
		  if !htf <> "" || (llen !configs) > 0 then
			let fullsave = 
			  if !ray <> "" && !ray_bigdiff <> "" then Some(!ray_bigdiff) 
			  else if !fullsave <> "" then Some(!fullsave)
			  else None
			in
			  get_many_diffs !configs !htf fullsave big_diff_ht big_diff_id benches
		  else big_diff_ht,big_diff_id
		in
		  begin (* User input! *)
			let ht_file = 
			  if !ray <> "" then
				if !ray_htfile <> "" then !ray_htfile else !ray_logfile ^".ht"
			  else
				!user_feedback_file^".ht"
			in
			let logfile = 
			  if !ray <> "" then
				let localtime = Unix.localtime (Unix.time ()) in
				  Printf.sprintf "%s.h%d.m%d.d%d.y%d.txt" !ray_logfile localtime.tm_hour (localtime.tm_mon + 1) localtime.tm_mday (localtime.tm_year + 1900)
			  else
				!user_feedback_file^".txt"
			in
			let reload = if !ray <> "" then !ray_reload else false in
			  if !ray <> "" || !user_feedback_file <> "" then
				get_user_feedback logfile ht_file big_diff_ht reload
		  end
	    end
	  end 
  end ;;

main () ;;
