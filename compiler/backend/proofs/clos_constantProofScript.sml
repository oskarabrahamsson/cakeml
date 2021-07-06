(*
  Some functions that flatten a closLang/BVL/BVI/dataLang const tree
  into a sequence of operations that share common data.
*)
open preamble closLangTheory;

val _ = new_theory "clos_constantProof";

(* naive implementation *)

Definition make_part_def:
  make_part n p aux =
    case ALOOKUP aux p of
    | SOME k => (n,k,aux)
    | NONE => (n+1n,n,(p,n)::aux)
End

Definition parts_def:
  parts (ConstInt i) n aux = make_part n (Int i) aux ∧
  parts (ConstStr s) n aux = make_part n (Str s) aux ∧
  parts (ConstWord64 w) n aux = make_part n (W64 w) aux ∧
  parts (ConstCons t cs) n aux =
    (let (n, rs, aux) = parts_list cs n aux in
       make_part n (Con t rs) aux) ∧
  parts_list [] n aux = (n,[],aux) ∧
  parts_list (c::cs) n aux =
    let (n,r,aux) = parts c n aux in
    let (n,rs,aux) = parts_list cs n aux in
      (n,r::rs,aux)
End

Definition to_parts_def:
  to_parts (ConstInt i) = [Int i] ∧
  to_parts (ConstStr s) = [Str s] ∧
  to_parts (ConstWord64 w) = [W64 w] ∧
  to_parts (ConstCons t cs) =
    let (n, rs, aux) = parts_list cs 0 [] in
      REVERSE ((Con t rs)::MAP FST aux)
End

(* semantics *)

Definition build_part_def:
  build_part mem (Int i) = ConstInt i ∧
  build_part mem (Str s) = ConstStr s ∧
  build_part mem (W64 w) = ConstWord64 w ∧
  build_part mem (Con t ns) = ConstCons t (MAP mem ns)
End

Definition build_def:
  build mem i [] = ConstInt 0 ∧
  build mem i [p] = build_part mem p ∧
  build mem i (p::rest) = build ((i =+ build_part mem p) mem) (i+1) rest
End

Definition build_const_def:
  build_const xs = build (λx. ConstInt 0) 0 xs
End

(* proof *)

Definition build_map_def:
  build_map mem i [] = mem ∧
  build_map mem i (p::rest) = build_map ((i =+ build_part mem p) mem) (i+1) rest
End

Theorem build_mem_thm:
  ∀mem i xs y.
    build mem i (xs ++ [y]) =
      build (build_map mem i xs) (i + LENGTH xs) [y]
Proof
  Induct_on ‘xs’ \\ fs [build_map_def]
  \\ Cases \\ simp [Once build_def]
  \\ Cases_on ‘xs’ \\ fs [build_def]
QED

Theorem parts_acc:
  (∀c n aux m r res.
     parts c n aux = (m,r,res) ⇒ ∃a. res = a ++ aux) ∧
  (∀cs n aux m rs res.
     parts_list cs n aux = (m,rs,res) ⇒ ∃a. res = a ++ aux)
Proof
  Induct \\ fs [parts_def]
  \\ rpt gen_tac \\ strip_tac
  \\ rpt (pairarg_tac \\ gvs [])
  \\ gvs [make_part_def,AllCaseEqs()]
  \\ res_tac \\ fs []
QED

Definition conses_ok_def:
  conses_ok aux ⇔
    (∀n. n < LENGTH aux ⇒ ∃p. EL n (REVERSE aux) = (p,n)) ∧
    ∀n rs m r. MEM (Con n rs, r) aux ∧ MEM m rs ⇒ m < r
End

Theorem IMP_conses_ok_CONS:
  (∀n rs. x = Con n rs ⇒ EVERY (λm. m < LENGTH aux) rs) ⇒
  conses_ok aux ⇒ conses_ok ((x,LENGTH aux)::aux)
Proof
  fs [conses_ok_def] \\ rw [] \\ res_tac \\ fs [] \\ fs [EVERY_MEM]
  \\ Cases_on ‘n = LENGTH (REVERSE aux)’
  \\ asm_rewrite_tac [Q.SPEC ‘[x]’ EL_LENGTH_APPEND |> REWRITE_RULE [NULL_DEF],HD]
  \\ fs []  \\ ‘n < LENGTH (REVERSE aux)’ by fs []
  \\ drule EL_APPEND1 \\ fs []
QED

Theorem build_map_APPEND:
  ∀xs ys m n.
    build_map m n (xs ++ ys) =
    build_map (build_map m n xs) (n + LENGTH xs) ys
Proof
  Induct \\ fs [build_map_def,ADD1]
QED

Triviality LIST_REL_eq:
  ∀l rs. LIST_REL (λc r. f r = c) l rs ⇔ l = MAP f rs
Proof
  Induct \\ Cases_on ‘rs’ \\ fs [] \\ metis_tac []
QED

Theorem build_map_ignore:
  ∀xs m n k. k < n ⇒ build_map m n xs k = m k
Proof
  Induct \\ fs [build_map_def,APPLY_UPDATE_THM]
QED

Theorem ALOOKUP_conses_ok_IMP:
  ALOOKUP aux x = SOME r ∧ conses_ok aux ⇒
  ∃xs:(const_part # num) list ys:(const_part # num) list.
    MAP FST (REVERSE aux) = MAP FST (REVERSE xs) ++ [x] ++ MAP FST (REVERSE ys) ∧
    LENGTH xs = r ∧ r < LENGTH aux ∧
    (∀t ys y. x = Con t ys ∧ MEM y ys ⇒ y < r)
Proof
  rw [conses_ok_def]
  \\ imp_res_tac ALOOKUP_MEM
  \\ ‘MEM (x,r) (REVERSE aux)’ by fs []
  \\ pop_assum mp_tac
  \\ rewrite_tac [MEM_EL]
  \\ strip_tac
  \\ rewrite_tac [GSYM MEM_EL]
  \\ fs []
  \\ first_x_assum drule
  \\ Cases_on ‘EL n (REVERSE aux)’ \\ gvs []
  \\ strip_tac \\ gvs []
  \\ qexists_tac ‘REVERSE (TAKE n (REVERSE aux))’
  \\ fs []
  \\ qexists_tac ‘REVERSE (DROP (SUC n) (REVERSE aux))’
  \\ reverse conj_tac
  THEN1 (Cases_on ‘q’ \\ fs [] \\ res_tac)
  \\ fs []
  \\ ‘n < LENGTH (REVERSE aux)’ by fs []
  \\ pop_assum mp_tac
  \\ ‘FST (EL n (REVERSE aux)) = q’ by fs []
  \\ pop_assum mp_tac
  \\ qspec_tac (‘n’,‘n’)
  \\ qspec_tac (‘REVERSE aux’,‘l’)
  \\ Induct \\ fs [] \\ strip_tac \\ Cases \\ fs []
QED

Theorem parts_thm:
  (∀c n aux m r res.
     parts c n aux = (m,r,res) ∧
     ALL_DISTINCT (MAP SND aux) ∧
     conses_ok aux ∧ n = LENGTH aux ∧
     EVERY (λ(p,k). k < n) aux ⇒
     build_map (λx. ConstInt 0) 0 (MAP FST (REVERSE res)) r = c ∧
     n ≤ m ∧ r < m ∧
     ALL_DISTINCT (MAP SND res) ∧
     conses_ok res ∧ m = LENGTH res ∧
     EVERY (λ(p,k). k < m) res) ∧
  (∀cs n aux m rs res.
     parts_list cs n aux = (m,rs,res) ∧
     ALL_DISTINCT (MAP SND aux) ∧
     conses_ok aux ∧ n = LENGTH aux ∧
     EVERY (λ(p,k). k < n) aux ⇒
     LIST_REL (λc r. build_map (λx. ConstInt 0) 0 (MAP FST (REVERSE res)) r = c) cs rs ∧
     n ≤ m ∧ ALL_DISTINCT (MAP SND res) ∧
     EVERY (λk. k < m) rs ∧
     conses_ok res ∧ m = LENGTH res ∧
     EVERY (λ(p,k). k < m) res)
Proof
  reverse Induct \\ fs [parts_def]
  \\ rpt gen_tac \\ strip_tac
  \\ rpt (pairarg_tac \\ full_simp_tac std_ss [])
  THEN1
   (fs [PULL_EXISTS]
    \\ first_x_assum drule_all \\ strip_tac \\ gvs []
    \\ first_x_assum drule \\ gvs [] \\ rw []
    \\ drule (CONJUNCT2 parts_acc) \\ strip_tac \\ gvs []
    \\ fs [REVERSE_APPEND,build_map_APPEND]
    \\ fs [build_map_ignore])
  \\ TRY
   ((rename [‘_ = ConstInt _’] ORELSE
     rename [‘_ = ConstStr _’] ORELSE
     rename [‘_ = ConstWord64 _’])
    \\ fs [PULL_EXISTS]
    \\ reverse (gvs [make_part_def,AllCaseEqs()])
    THEN1
     (drule_all ALOOKUP_conses_ok_IMP \\ strip_tac
      \\ fs [build_map_APPEND] \\ fs [build_map_def,build_part_def]
      \\ fs [build_map_ignore,APPLY_UPDATE_THM])
    \\ gvs [EVERY_MEM,FORALL_PROD,MEM_MAP,EXISTS_PROD]
    \\ rw [] \\ res_tac \\ gvs []
    \\ CCONTR_TAC \\ gvs [] \\ res_tac \\ fs []
    \\ pop_assum mp_tac \\ fs []
    \\ TRY (irule IMP_conses_ok_CONS \\ fs [EVERY_MEM])
    \\ fs [build_map_APPEND]
    \\ fs [build_map_def,APPLY_UPDATE_THM,build_part_def] \\ NO_TAC)
  \\ rename [‘_ = ConstCons _ _’]
  \\ fs [PULL_EXISTS]
  \\ first_x_assum drule_all \\ strip_tac
  \\ reverse (gvs [make_part_def,AllCaseEqs()])
  THEN1
   (drule_all ALOOKUP_conses_ok_IMP \\ strip_tac
    \\ fs [build_map_APPEND] \\ fs [build_map_def,build_part_def]
    \\ fs [build_map_ignore,APPLY_UPDATE_THM,LIST_REL_eq,MAP_EQ_f]
    \\ rpt strip_tac
    \\ fs [EVERY_MEM] \\ first_x_assum drule \\ strip_tac
    \\ gvs [build_map_ignore,APPLY_UPDATE_THM])
  \\ gvs [EVERY_MEM,FORALL_PROD,MEM_MAP,EXISTS_PROD]
  \\ rw [] \\ res_tac \\ gvs []
  \\ CCONTR_TAC \\ gvs [] \\ res_tac \\ fs []
  \\ pop_assum mp_tac \\ fs []
  \\ TRY (irule IMP_conses_ok_CONS \\ fs [EVERY_MEM])
  \\ fs [build_map_APPEND]
  \\ fs [build_map_def,APPLY_UPDATE_THM,build_part_def]
  \\ fs [LIST_REL_eq, SF ETA_ss]
QED

(*
  EVAL “let c1 = ConstInt 1 in
        let c2 = ConstCons 2 [c1;c1] in
        let c3 = ConstCons 3 [c2;c2] in
        let c4 = ConstCons 4 [c3;c3] in
          to_parts c4”

*)

Theorem build_const_to_parts:
  ∀c. build_const (to_parts c) = c
Proof
  Cases \\ TRY (EVAL_TAC \\ NO_TAC)
  \\ rw [to_parts_def]
  \\ pairarg_tac \\ fs []
  \\ drule (CONJUNCT2 parts_thm)
  \\ impl_tac THEN1 fs [conses_ok_def]
  \\ rw [build_const_def,build_mem_thm]
  \\ fs [build_def,build_part_def,MAP_REVERSE]
  \\ fs [LIST_REL_eq,MAP_EQ_f]
QED

(* an efficent version *)

Overload PRIME[local] = “999983:num”;

Definition part_hash_def:
  part_hash (Int i) = Num (ABS i) MOD PRIME ∧
  part_hash (Str s) = (LENGTH s + 3 * SUM (MAP ORD s)) MOD PRIME ∧
  part_hash (W64 w) = (17 + w2n w) MOD PRIME ∧
  part_hash (Con t ns) = (18 + 5 * t + 7 * SUM ns) MOD PRIME
End

Definition add_part_def:
  add_part n p aux acc =
    let h = part_hash p in
      case lookup h aux of
      | NONE => (n+1n,n,insert h [(p,n)] aux,p::acc)
      | SOME bucket =>
          case ALOOKUP bucket p of
          | NONE => (n+1n,n,insert h ((p,n)::bucket) aux,p::acc)
          | SOME k => (n,k,aux,acc)
End

Definition add_parts_def:
  add_parts (ConstInt i) n aux acc = add_part n (Int i) aux acc ∧
  add_parts (ConstStr s) n aux acc = add_part n (Str s) aux acc ∧
  add_parts (ConstWord64 w) n aux acc = add_part n (W64 w) aux acc ∧
  add_parts (ConstCons t cs) n aux acc =
    (let (n, rs, aux, acc) = add_parts_list cs n aux acc in
       add_part n (Con t rs) aux acc) ∧
  add_parts_list [] n aux acc = (n,[],aux,acc) ∧
  add_parts_list (c::cs) n aux acc =
    let (n,r,aux,acc) = add_parts c n aux acc in
    let (n,rs,aux,acc) = add_parts_list cs n aux acc in
      (n,r::rs,aux,acc)
End

Definition const_to_parts_def:
  const_to_parts (ConstInt i) = [Int i] ∧
  const_to_parts (ConstStr s) = [Str s] ∧
  const_to_parts (ConstWord64 w) = [W64 w] ∧
  const_to_parts (ConstCons t cs) =
    let (n, rs, aux, acc) = add_parts_list cs 0 LN [] in
      REVERSE ((Con t rs)::acc)
End

Definition good_hash_table_def:
  good_hash_table m aux =
    ∀k v. ALOOKUP aux k = SOME v ⇔
          ∃bucket. lookup (part_hash k) m = SOME bucket ∧
                   ALOOKUP bucket k = SOME v
End

Theorem add_part_thm:
  add_part n x m (MAP FST aux) = (n1,rs,m1,acc1) ∧
  make_part n x aux = (n2,rs1,aux1) ∧
  good_hash_table m aux ⇒
  n1 = n2 ∧ rs = rs1 ∧ MAP FST aux1 = acc1 ∧ good_hash_table m1 aux1
Proof
  fs [add_part_def,AllCaseEqs()] \\ reverse strip_tac \\ gvs []
  THEN1
   (‘ALOOKUP aux x = SOME rs’ by metis_tac [good_hash_table_def]
    \\ gvs [make_part_def])
  \\ ‘∀v. ALOOKUP aux x ≠ SOME v’ by fs [good_hash_table_def]
  \\ Cases_on ‘ALOOKUP aux x’ \\ gvs []
  \\ gvs [make_part_def]
  \\ fs [good_hash_table_def] \\ rw []
  \\ fs [lookup_insert] \\ IF_CASES_TAC \\ fs []
QED

Theorem add_parts_thm:
  (∀l n m acc n1 m1 rs m1 acc1 aux n2 rs1 aux1.
    add_parts l n m acc = (n1,rs,m1,acc1) ∧
    parts l n aux = (n2,rs1,aux1) ∧
    MAP FST aux = acc ∧ good_hash_table m aux ⇒
    n1 = n2 ∧ rs = rs1 ∧ MAP FST aux1 = acc1 ∧ good_hash_table m1 aux1) ∧
  (∀l n m acc n1 m1 rs m1 acc1 aux n2 rs1 aux1.
    add_parts_list l n m acc = (n1,rs,m1,acc1) ∧
    parts_list l n aux = (n2,rs1,aux1) ∧
    MAP FST aux = acc ∧ good_hash_table m aux ⇒
    n1 = n2 ∧ rs = rs1 ∧ MAP FST aux1 = acc1 ∧ good_hash_table m1 aux1)
Proof
  reverse Induct \\ rpt gen_tac \\ strip_tac
  \\ gvs [add_parts_def,parts_def]
  \\ rpt (pairarg_tac \\ gvs [])
  THEN1
   (last_x_assum drule_all \\ strip_tac \\ gvs []
    \\ last_x_assum drule_all \\ strip_tac \\ gvs [])
  \\ TRY (drule_all add_part_thm \\ fs [])
  \\ rename [‘Con’]
  \\ last_x_assum drule_all \\ strip_tac \\ gvs []
  \\ drule_all add_part_thm \\ fs []
QED

Theorem const_to_parts_thm:
  const_to_parts c = to_parts c
Proof
  Cases_on ‘c’ \\ fs [const_to_parts_def,to_parts_def]
  \\ rpt (pairarg_tac \\ fs [])
  \\ drule_then drule (add_parts_thm |> CONJUNCT2)
  \\ impl_tac \\ fs []
  \\ fs [good_hash_table_def,lookup_def]
QED

val _ = export_theory();
