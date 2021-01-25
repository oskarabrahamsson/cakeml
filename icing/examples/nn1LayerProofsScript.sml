(**
  InvertedPendulum program proofs
**)

open compilerTheory fromSexpTheory cfTacticsLib ml_translatorLib;
open RealIntervalInferenceTheory ErrorIntervalInferenceTheory CertificateCheckerTheory;
open source_to_sourceTheory source_to_sourceProofsTheory CakeMLtoFloVerTheory
     CakeMLtoFloVerProofsTheory icing_optimisationProofsTheory
     icing_optimisationsLib nn1LayerProgCompTheory
     nn1LayerProgErrorTheory cfSupportTheory;
open machine_ieeeTheory binary_ieeeTheory realTheory realLib RealArith;
open astToSexprLib fromSexpTheory basis_ffiTheory cfHeapsBaseTheory basis;
open preamble supportLib;

val _ = new_theory "nn1LayerProofs";

val _ = translation_extends "nn1LayerProgComp";

(** Build a backwards simulation theorem for the optimisations and show that they are real-valued ids **)
Theorem nn1Layer_opts_icing_correct =
  mk_opt_correct_thm [fp_sub_add_correct, Q.SPEC ‘FP_Add’ fp_comm_gen_correct, fp_neg_push_mul_r_correct, fp_fma_intro_correct];

Theorem nn1Layer_opts_real_id =
  mk_real_id_thm [fp_sub_add_real_id, SIMP_RULE (srw_ss()) [] (Q.SPEC ‘FP_Add’ fp_comm_gen_real_id), fp_neg_push_mul_r_real_id, fma_intro_real_id];

val st = get_ml_prog_state ();

val local_opt_run_thm = mk_local_opt_thm theAST_opt theAST_def;

val (fname, fvars, body) =
  EVAL (Parse.Term ‘getDeclLetParts ^(theOptProg_def |> concl |> rhs)’)
  |> concl |> rhs |> dest_pair
  |> (fn (x,y) => let val (y,z) = dest_pair y in (x,y,z) end)

val (_, fvars_before, body_before) =
  EVAL (Parse.Term ‘getDeclLetParts ^(theAST_def |> concl |> rhs)’)
  |> concl |> rhs |> dest_pair
  |> (fn (x,y) => let val (y,z) = dest_pair y in (x,y,z) end)

Definition nn1Layer_real_spec_def:
  nn1Layer_real_spec (w1,w2,w3,w4) =
    real_spec_prog ^body_before nn1Layer_env ^fvars [w1;w2;w3;w4]
End

Definition nn1Layer_opt_float_option_noopt_def:
  nn1Layer_opt_float_option_noopt w1 w2 w3 w4 =
   case evaluate
     (empty_state with fp_state := empty_state.fp_state with canOpt := FPScope NoOpt)
   (nn1Layer_env with v := extend_env_with_vars (REVERSE ^fvars) (REVERSE [w1;w2;w3;w4]) (nn1Layer_env).v)
   [^body] of
   | (st, Rval [FP_WordTree fp]) =>
     if st = (empty_state with fp_state := empty_state.fp_state with canOpt := FPScope NoOpt)
     then SOME fp else NONE
   | _ => NONE
End

Definition nn1Layer_opt_float_option_def:
  nn1Layer_opt_float_option w1 w2 w3 w4 =
   case evaluate empty_state
   (nn1Layer_env with v := extend_env_with_vars (REVERSE ^fvars) (REVERSE [w1;w2;w3;w4]) (nn1Layer_env).v)
   [^body] of
   | (st, Rval [FP_WordTree fp]) =>
     if st = empty_state then SOME fp else NONE
   | _ => NONE
End

Definition nn1Layer_float_returns_def:
  nn1Layer_float_returns (w1,w2,w3,w4) w ⇔
  ∃ fpOpts st2 fp.
    evaluate (empty_state with fp_state :=
              empty_state.fp_state with
                <| rws := theOpts.optimisations ; opts := fpOpts; canOpt := FPScope NoOpt |>)
   (nn1Layer_env with v :=
     extend_env_with_vars (REVERSE ^fvars) (REVERSE [w1;w2;w3;w4]) (nn1Layer_env).v)
   [^body_before] = (st2, Rval [FP_WordTree fp]) ∧ compress_word fp = w
End

Theorem nn1Layer_opt_backward_sim:
  ∀ w1 w2 w3 w4 w.
  nn1Layer_opt_float_option_noopt w1 w2 w3 w4 = SOME w ⇒
  nn1Layer_float_returns (w1,w2,w3,w4) (compress_word w)
Proof
  simp[nn1Layer_opt_float_option_noopt_def, nn1Layer_float_returns_def]
  \\ rpt gen_tac
  \\ ntac 5 (TOP_CASE_TAC \\ fs[])
  \\ strip_tac \\ rveq
  \\ fs[GSYM local_opt_run_thm]
  \\ first_x_assum (mp_then Any assume_tac no_optimisations_eval_sim)
  \\ fs[]
  \\ first_x_assum (qspecl_then [‘NoOpt’, ‘empty_state.fp_state.choices’] assume_tac)
  \\ fs[] \\ imp_res_tac noopt_sim_val \\ rveq
  \\ imp_res_tac noopt_sim_val_fp \\ rveq \\ fs[]
  \\ pop_assum mp_tac \\ impl_tac
  >- (EVAL_TAC)
  \\ strip_tac
  \\ qpat_x_assum `evaluate _ _ _ = _` mp_tac
  \\ qmatch_goalsub_abbrev_tac ‘evaluate emp_upd dEnv [optimise theOpts e_init] = (emp_res, _)’
  \\ strip_tac
  \\ assume_tac (INST_TYPE [“:'a” |-> “:unit”] nn1Layer_opts_icing_correct)
  \\ imp_res_tac noopt_sim_val \\ rveq \\ imp_res_tac noopt_sim_val_fp \\ rveq
  \\ first_x_assum
       (qspecl_then [‘emp_upd’, ‘emp_res’, ‘dEnv’, ‘theOpts’, ‘[e_init]’, ‘[FP_WordTree fp2]’] mp_tac)
  \\ simp[is_optimise_correct_def]
  \\ impl_tac
  >- (
   unabbrev_all_tac
   \\ fs[empty_state_def, theOpts_def, extend_conf_def, no_fp_opt_conf_def, nn1Layer_env_def])
  \\ rpt strip_tac
  \\ unabbrev_all_tac \\ fs[empty_state_def, semanticPrimitivesTheory.state_component_equality]
  \\ pop_assum mp_tac
  \\ qmatch_goalsub_abbrev_tac ‘evaluate newSt newEnv _ = _’
  \\ strip_tac
  \\ qexists_tac ‘newSt.fp_state.opts’
  \\ unabbrev_all_tac
  \\ first_x_assum (mp_then Any (qspec_then ‘0’ assume_tac) (CONJUNCT1 evaluate_add_choices))
  \\ fs[theOpts_def, no_fp_opt_conf_def, extend_conf_def,
        config_component_equality, nn1Layer_env_def]
QED

val nn1Layer_opt = theAST_opt |> concl |> rhs;

val nn1Layer_pre = nn1Layer_pre_def |> concl |> rhs;

Definition nn1Layer_side_def:
  nn1Layer_side w1 w2 w3 w4 = (is_precond_sound ^fvars [w1; w2; w3;w4] ^nn1Layer_pre)
End

Definition nn1Layer_real_fun_def:
  nn1Layer_real_fun w1 w2 w3 w4 =
    (nn1Layer_real_spec (w1, w2, w3, w4))
End

Theorem nn1Layer_spec:
  ∀ w1 w2 w3 w4 d1 d2 d3 d4.
    nn1Layer_side w1 w2 w3 w4 ∧
    DOUBLE (Fp_const w1) d1 ∧
    DOUBLE (Fp_const w2) d2 ∧
    DOUBLE (Fp_const w3) d3 ∧
    DOUBLE (Fp_const w4) d4 ⇒
    let result = (nn1Layer_opt_float_option w1 w2 w3 w4) in
      (∀ p.
        app (p:'ffi ffi_proj) ^(fetch_v "nn1Layer" st)
          [d1; d2; d3; d4]
          (emp)
          (POSTv v.
           &DOUBLE_RES result v)) ∧
      nn1Layer_float_returns (w1,w2,w3,w4) (compress_word (THE result)) ∧
      real$abs (fp64_to_real (compress_word (THE result)) - nn1Layer_real_fun w1 w2 w3 w4) ≤ theErrBound
Proof
  rpt gen_tac \\ simp[app_def, nn1Layer_side_def]
  \\ rpt (disch_then assume_tac)
  \\ simp[app_basic_def]
  \\ rpt (gen_tac ORELSE (disch_then assume_tac)) \\ fs[]
  \\ mp_tac errorbounds_AST
  \\ fs[isOkError_def, option_case_eq, pair_case_eq, getErrorbounds_def, stripFuns_def, PULL_EXISTS]
  \\ rpt gen_tac
  \\ TOP_CASE_TAC \\ fs[option_case_eq, pair_case_eq]
  \\ rpt (gen_tac ORELSE (disch_then assume_tac)) \\ fs[] \\ rveq
  \\ first_assum (mp_then Any mp_tac CakeML_FloVer_infer_error)
  \\ fs[checkErrorbounds_succeeds_def, PULL_EXISTS]
  \\ qpat_x_assum ‘toFloVerCmd _ _ _ = SOME _’ mp_tac
  \\ qmatch_goalsub_abbrev_tac ‘toFloVerCmd _ _ nn1Layer_body = _’
  \\ disch_then assume_tac
  \\ disch_then (qspecl_then
                 [‘nn1Layer_env’,
                  ‘Fun "x1" (Fun "x2" (Fun "x3" (Fun "x4" nn1Layer_body)))’] mp_tac)
  \\ unabbrev_all_tac
  \\ fs[stripFuns_def, nn1Layer_pre_def]
  \\ strip_tac
  \\ simp[semanticPrimitivesTheory.do_opapp_def, nn1Layer_v_def]
  \\ reverse conj_tac
  >- (
   rpt (pop_assum mp_tac) \\ simp[] \\ rpt (disch_then assume_tac)
   \\ rveq
   \\ ‘nn1Layer_opt_float_option_noopt w1 w2 w3 w4 = SOME fp’
      by (fs[nn1Layer_opt_float_option_noopt_def])
   \\ imp_res_tac nn1Layer_opt_backward_sim
   \\ rfs[nn1Layer_opt_float_option_def, nn1Layer_real_fun_def,
          real_spec_prog_def, nn1Layer_real_spec_def]
   \\ assume_tac (INST_TYPE [“:'a” |-> “:unit”] nn1Layer_opts_real_id)
   \\ qpat_x_assum `evaluate _ _ [realify _] = _` mp_tac
   \\ unabbrev_all_tac
   \\ simp[GSYM local_opt_run_thm]
   \\ qmatch_goalsub_abbrev_tac ‘evaluate _ _ [realify (no_optimisations theOpts e_opt)] = _’
   \\ disch_then (mp_then Any mp_tac evaluate_no_optimisations)
   \\ fs[]
   \\ disch_then (qspecl_then [‘NoOpt’, ‘empty_state.fp_state.choices’] mp_tac)
   \\ impl_tac \\ unabbrev_all_tac
   >- (EVAL_TAC)
   \\ qmatch_goalsub_abbrev_tac ‘evaluate emptyWithReals realEnv [realify (optimise theOpts e_init)] = _’
   \\ strip_tac
   \\ fs[is_real_id_optimise_def]
   \\ first_x_assum (
      qspecl_then [ ‘emptyWithReals’, ‘emptyWithReals’, ‘realEnv’, ‘theOpts’, ‘[e_init]’, ‘[Real r]’] mp_tac)
   \\ simp[MAP]
   \\ ‘theOpts with optimisations := [fp_sub_add; fp_comm_gen FP_Add; fp_neg_push_mul_r;
                     fp_fma_intro] = theOpts’
      by (simp[theOpts_def, extend_conf_def, no_fp_opt_conf_def])
   \\ pop_assum (fs o single)
   \\ unabbrev_all_tac \\ fs[theOpts_def, no_fp_opt_conf_def]
   \\ rpt strip_tac \\ rveq
   \\ imp_res_tac evaluate_realify_state
   \\ pop_assum mp_tac \\ impl_tac >- EVAL_TAC
   \\ strip_tac \\ rveq
   \\ fs[empty_state_def, semanticPrimitivesTheory.fpState_component_equality, semanticPrimitivesTheory.state_component_equality]
   \\ irule REAL_LE_TRANS \\ asm_exists_tac \\ fs[])
  \\ rpt strip_tac \\ fs[] \\ rveq
  \\ Q.REFINE_EXISTS_TAC ‘Val v’
  \\ simp[evaluate_to_heap_def, evaluate_ck_def, terminationTheory.evaluate_def]
  \\ qexists_tac ‘EMPTY’ \\ qexists_tac ‘EMPTY’
  \\ fs[emp_def, set_sepTheory.SPLIT_def, cfHeapsBaseTheory.SPLIT3_def]
  \\ simp[set_sepTheory.SEP_EXISTS]
  \\ qexists_tac ‘emp’ \\ simp[set_sepTheory.STAR_def]
  \\ ntac 2 (qexists_tac ‘EMPTY’)
  \\ fs[emp_def, set_sepTheory.SPLIT_def, cfHeapsBaseTheory.SPLIT3_def]
  \\ simp[set_sepTheory.cond_def]
  \\ rpt strip_tac
  \\ Q.REFINE_EXISTS_TAC ‘Val v’ \\ simp[]
  \\ ntac 2 (qexists_tac ‘EMPTY’) \\ rpt conj_tac \\ TRY (simp[DISJOINT_DEF] \\ NO_TAC)
  \\ qexists_tac ‘emp’ \\ simp[emp_def]
  \\ rpt strip_tac
  \\ Q.REFINE_EXISTS_TAC ‘Val v’ \\ simp[Once terminationTheory.evaluate_def]
  \\ ntac 2 (qexists_tac ‘EMPTY’) \\ rpt conj_tac \\ TRY (simp[DISJOINT_DEF] \\ NO_TAC)
  \\ qexists_tac ‘emp’ \\ simp[emp_def]
  \\ rpt strip_tac
  \\ Q.REFINE_EXISTS_TAC ‘Val v’ \\ simp[]
  \\ ‘DISJOINT (st2heap p st'3') EMPTY’ by (simp[DISJOINT_DEF])
  \\ asm_exists_tac \\ simp[DOUBLE_RES_def]
  \\ rveq \\ simp[nn1Layer_opt_float_option_def]
  \\ first_x_assum
     (mp_then Any mp_tac
      (INST_TYPE [“:'a”|->“:unit”, “:'b”|->“:'ffi”] isPureExpList_swap_state))
  \\ disch_then (qspec_then ‘st'3' with clock := 0’ mp_tac)
  \\ impl_tac \\ fs[]
  >- (unabbrev_all_tac \\ EVAL_TAC)
  \\ strip_tac \\ qexists_tac ‘0’ \\ fs[extend_env_with_vars_def, DOUBLE_def, nn1Layer_env_def]
QED

Theorem main_spec:
  ∀ p.
  cl = [fname; cst1s; cst2s; cst3s; cst4s] ∧
  is_float_string cst1s c1 ∧
  is_float_string cst2s c2 ∧
  is_float_string cst3s c3 ∧
  is_float_string cst4s c4 ∧
  nn1Layer_side c1 c2 c3 c4 ⇒
  let
    result = nn1Layer_opt_float_option c1 c2 c3 c4
  in
  app p ^(fetch_v "main" st)
    [Conv NONE []]
    (STDIO fs * COMMANDLINE cl)
    (POSTv uv. &UNIT_TYPE () uv *
     STDIO (add_stdout fs (mlint$toString (&w2n (compress_word (THE result))))))
    ∧
    nn1Layer_float_returns (c1,c2,c3,c4) (compress_word (THE result)) ∧
    real$abs (fp64_to_real (compress_word (THE result)) -
      nn1Layer_real_fun c1 c2 c3 c4) ≤ theErrBound
Proof
  simp[] \\ rpt strip_tac
  \\ first_x_assum (mp_then Any assume_tac (SIMP_RULE std_ss [] (INST_TYPE [“:'ffi”|->“:'a”] nn1Layer_spec)))
  >- (
   xcf "main" st
   \\ xlet_auto >- (xcon \\ xsimpl)
   \\ ‘5 = LENGTH cl’ by (rveq \\ fs[])
   \\ rveq
   \\ xlet_auto_spec (SOME reader4_spec)
   >- (xsimpl \\ qexists_tac ‘emp’ \\ xsimpl
       \\ qexists_tac ‘fs’ \\ xsimpl)
   \\ xmatch
   \\ fs[PAIR_TYPE_def] \\ reverse conj_tac
   >- (EVAL_TAC \\ fs[])
   \\ rveq \\ fs[is_float_string_def]
   \\ xlet_auto_spec (SOME intToFP_spec)
   >- (xsimpl \\ qexists_tac ‘emp’ \\ xsimpl
       \\ qexists_tac ‘fs’ \\ xsimpl)
   \\ xlet ‘POSTv uv. &(DOUBLE (Fp_const ((n2w (Num i')):word64)) uv) * STDIO fs’
   >- (xapp \\ xsimpl \\ asm_exists_tac \\ fs[])
   \\ xlet ‘POSTv uv. &(DOUBLE (Fp_const ((n2w (Num i'')):word64)) uv) * STDIO fs’
   >- (xapp \\ xsimpl \\ asm_exists_tac \\ fs[])
   \\ xlet ‘POSTv uv. &(DOUBLE (Fp_const ((n2w (Num i'3')):word64)) uv) * STDIO fs’
   >- (xapp \\ xsimpl \\ asm_exists_tac \\ fs[])
   \\ rveq
   \\ first_x_assum (qspecl_then [‘uv'’, ‘uv''’, ‘uv'3'’, ‘uv'4'’] mp_tac)
   \\ impl_tac \\ fs[] \\ strip_tac
   \\ xlet_auto >- xsimpl
   \\ qpat_x_assum ‘DOUBLE_RES _ _’ mp_tac
   \\ simp[DOUBLE_RES_def] \\ TOP_CASE_TAC \\ fs[]
   \\ rpt strip_tac \\ rveq
   \\ qmatch_goalsub_abbrev_tac ‘compress_word f’
   \\ xlet ‘POSTv v. &WORD (compress_word f) v * STDIO fs’
   >- (
    fs[cf_fptoword_def, cfHeapsTheory.local_def, cfNormaliseTheory.exp2v_def,
       cfTheory.app_fptoword_def]
    \\ rpt strip_tac
    \\ fs[WORD_def]
    \\ qexists_tac ‘STDIO fs’ \\ qexists_tac ‘emp’
    \\ fs[set_sepTheory.STAR_def]
    \\ qexists_tac ‘POSTv v. &WORD (compress_word f) v * STDIO fs’ \\ rpt conj_tac
    >- (
     qexists_tac ‘h’ \\ qexists_tac ‘EMPTY’ \\ fs[SPLIT_def, emp_def])
    >- (
     fs[DOUBLE_def, set_sepTheory.SEP_IMP_def]
     \\ rpt strip_tac \\ fs[set_sepTheory.cond_def, set_sepTheory.STAR_def]
     \\ qexists_tac ‘s’ \\ fs[SPLIT_def])
    \\ xsimpl \\ rveq \\ rpt strip_tac
    \\ fs[set_sepTheory.SEP_IMP_def, set_sepTheory.STAR_def] \\ rpt strip_tac
    \\ qexists_tac ‘s’ \\ qexists_tac ‘EMPTY’
    \\ fs[SPLIT_def, GC_def] \\ conj_tac
    >- (rveq \\ rewrite_tac [CONJ_ASSOC]
        \\ once_rewrite_tac [CONJ_COMM] \\ asm_exists_tac \\ fs[]
        \\ qexists_tac ‘EMPTY’
        \\ fs[set_sepTheory.cond_def, WORD_def])
    \\ fs[set_sepTheory.SEP_EXISTS] \\ qexists_tac ‘emp’ \\ fs[emp_def])
   \\ xapp \\ xsimpl)
  \\ fs[DOUBLE_def]
QED

Theorem main_whole_prog_spec:
  cl = [fname; cst1s; cst2s; cst3s; cst4s] ∧
  is_float_string cst1s c1 ∧
  is_float_string cst2s c2 ∧
  is_float_string cst3s c3 ∧
  is_float_string cst4s c4 ∧
  nn1Layer_side c1 c2 c3 c4 ⇒
  whole_prog_spec ^(fetch_v "main" st) cl fs
  NONE
  ((=)
   (add_stdout fs (mlint$toString (&w2n (compress_word (THE (nn1Layer_opt_float_option c1 c2 c3 c4)))))))
  ∧
  nn1Layer_float_returns (c1,c2,c3,c4) (compress_word (THE (nn1Layer_opt_float_option c1 c2 c3 c4))) ∧
  real$abs (fp64_to_real (compress_word (THE (nn1Layer_opt_float_option c1 c2 c3 c4))) -
            nn1Layer_real_fun c1 c2 c3 c4) ≤ theErrBound
Proof
  simp[whole_prog_spec_def]
  \\ qmatch_goalsub_abbrev_tac`fs1 = _ with numchars := _`
  \\ rpt (strip_tac)
  \\ qspec_then ‘(basis_proj1, basis_proj2)’ mp_tac main_spec
  \\ impl_tac \\ fs[]
  \\ strip_tac
  \\ qexists_tac`fs1`
  \\ simp[Abbr`fs1`,GSYM add_stdo_with_numchars,with_same_numchars]
  \\ first_x_assum (fn main_spec => irule (MP_CANON (MATCH_MP app_wgframe main_spec)))
  \\ xsimpl
QED

val spec = main_whole_prog_spec;
val name = "main";

val (prog_rewrite, semantics_prog_thm) = mk_whole_prog_spec_thm spec name (get_ml_prog_state());

val nn1Layer_prog_tm = rhs (concl prog_rewrite);

val nn1Layer_prog_def = Define`nn1Layer_prog = ^nn1Layer_prog_tm`;

val full_semantics_prog_thm =
  LIST_CONJ [
    DISCH_ALL semantics_prog_thm,
    CONJUNCT2 (SIMP_RULE std_ss [cfSupportTheory.IMP_SPLIT] main_whole_prog_spec)
              |> SIMP_RULE std_ss [GSYM cfSupportTheory.IMP_SPLIT]
              |> REWRITE_RULE [CONJ_ASSOC]
              |> ONCE_REWRITE_RULE [CONJ_COMM]
              |> ONCE_REWRITE_RULE [GSYM AND_IMP_INTRO]
              |> ONCE_REWRITE_RULE [CONJ_COMM]
              |> ONCE_REWRITE_RULE [GSYM AND_IMP_INTRO]
              |> ONCE_REWRITE_RULE [CONJ_COMM]
              |> ONCE_REWRITE_RULE [GSYM AND_IMP_INTRO]
              |> ONCE_REWRITE_RULE [CONJ_COMM]
              |> ONCE_REWRITE_RULE [GSYM AND_IMP_INTRO]
              |> ONCE_REWRITE_RULE [CONJ_COMM]
              |> ONCE_REWRITE_RULE [GSYM AND_IMP_INTRO]
  ]
  |> SIMP_RULE std_ss [GSYM AND_IMP_INTRO]
  |> SIMP_RULE std_ss [GSYM cfSupportTheory.IMP_SPLIT];

Theorem nn1Layer_semantics =
  full_semantics_prog_thm |> ONCE_REWRITE_RULE[GSYM nn1Layer_prog_def]
  |> DISCH_ALL |> SIMP_RULE std_ss [AND_IMP_INTRO,GSYM CONJ_ASSOC];

Definition nn1Layer_semantics_side_def:
  nn1Layer_semantics_side (s1,s2,s3,s4) (c1,c2,c3,c4) ⇔
    is_float_string s1 c1 ∧
    is_float_string s2 c2 ∧
    is_float_string s3 c3 ∧
    is_float_string s4 c4 ∧
    nn1Layer_side c1 c2 c3 c4
End

Theorem nn1Layer_semantics_final:
  nn1Layer_semantics_side (s1,s2,s3,s4) (c1,c2,c3,c4) ∧ init_ok ([fname;s1;s2;s3;s4],fs) ⇒
  ∃ (w:word64).
    CakeML_evaluates_and_prints ([fname;s1;s2;s3;s4],fs,nn1Layer_prog) (toString w) ∧
    nn1Layer_float_returns (c1,c2,c3,c4) w ∧
    real$abs (fp64_to_real w - nn1Layer_real_fun c1 c2 c3 c4) ≤ theErrBound
Proof
  rpt strip_tac
  \\ fs[init_ok_def, CakeML_evaluates_and_prints_def, nn1Layer_semantics_side_def]
  \\ first_x_assum (mp_then Any mp_tac nn1Layer_semantics)
  \\ rpt (disch_then drule)
  \\ strip_tac \\ fs[]
  \\ first_x_assum (qspecl_then [‘fs’,‘fname’] mp_tac)
  \\ strip_tac \\ rfs[]
  \\ qexists_tac ‘compress_word (THE (nn1Layer_opt_float_option c1 c2 c3 c4))’ \\ fs[]
  \\ asm_exists_tac \\ fs[toString_def]
QED

val _ = export_theory();
