open preamble sptreeTheory reg_allocTheory

val _ = new_theory "linear_scan"

val _ = Datatype`
  live_tree = StartLive (num list)
            | EndLive (num list)
            | Branch live_tree live_tree
            | Seq live_tree live_tree`


val numset_list_insert_def = Define`
  (numset_list_insert [] t = t) ∧
  (numset_list_insert (x::xs) t = numset_list_insert xs (insert x () t))`

val numset_list_insert_nottailrec_def = Define`
  (numset_list_insert_nottailrec [] t = t) ∧
  (numset_list_insert_nottailrec (x::xs) t = insert x () (numset_list_insert_nottailrec xs t))`

val is_subset_def = Define`
    is_subset s1 s2 <=> (domain s1) SUBSET (domain s2)
`

val is_subset_compute_def = Define`
    is_subset_compute s1 s2 <=> EVERY (\(x,y). lookup x s2 <> NONE) (toAList s1)
`

val get_live_tree_def = Define`
    (
      get_live_tree (reg_alloc$Delta wr rd) =
        Seq (EndLive rd) (StartLive wr)
    ) /\ (
      get_live_tree (reg_alloc$Set cutset) =
        let cutlist = MAP FST (toAList cutset) in
        EndLive cutlist
    ) /\ (
      get_live_tree (reg_alloc$Branch optcutset ct1 ct2) =
        let lt1 = get_live_tree ct1 in
        let lt2 = get_live_tree ct2 in
        case optcutset of
        | SOME cutset =>
            let cutlist = MAP FST (toAList cutset) in
            Seq (EndLive cutlist) (Branch lt1 lt2)
        | NONE => (Branch lt1 lt2)
    ) /\ (
      get_live_tree (reg_alloc$Seq ct1 ct2) =
        let lt2 = get_live_tree ct2 in
        let lt1 = get_live_tree ct1 in
        Seq lt1 lt2
    )`

val check_live_tree_def = Define`
    (
      check_live_tree f (StartLive l) live flive =
        case check_partial_col f l live flive of
        | NONE => NONE
        | SOME _ =>
        let live_out = numset_list_delete l live in
        let flive_out = numset_list_delete (MAP f l) flive in
        SOME (live_out, flive_out)
    ) /\ (
      check_live_tree f (EndLive l) live flive =
        check_partial_col f l live flive
    ) /\ (
      check_live_tree f (Branch lt1 lt2) live flive =
        case check_live_tree f lt1 live flive of
        | NONE => NONE
        | SOME (live1, flive1) =>
        case check_live_tree f lt2 live flive of
        | NONE => NONE
        | SOME (live2, flive2) =>
        check_partial_col f (MAP FST (toAList (difference live2 live1))) live1 flive1
    ) /\ (
      check_live_tree f (Seq lt1 lt2) live flive =
        case check_live_tree f lt2 live flive of
        | NONE => NONE
        | SOME (live2, flive2) =>
          check_live_tree f lt1 live2 flive2
    )`

val fix_endlive_def = Define`
    (
      fix_endlive (StartLive l) live =
        (StartLive l, numset_list_delete l live)
    ) /\ (
      fix_endlive (EndLive l) live =
        (EndLive (FILTER (\x. lookup x live = NONE) l), numset_list_insert l live)
    ) /\ (
      fix_endlive (Branch lt1 lt2) live =
        let (lt1', live1) = fix_endlive lt1 live in
        let (lt2', live2) = fix_endlive lt2 live in
        (Branch lt1' lt2', numset_list_insert (MAP FST (toAList (difference live2 live1))) live1)
    ) /\ (
      fix_endlive (Seq lt1 lt2) live =
        let (lt2', live2) = fix_endlive lt2 live in
        let (lt1', live1) = fix_endlive lt1 live2 in
        (Seq lt1' lt2', live1)
    )
`

val check_endlive_fixed_def = Define`
    (
      check_endlive_fixed (StartLive l) live =
        (T, numset_list_delete l live)
    ) /\ (
      check_endlive_fixed (EndLive l) live =
        (EVERY (\x. lookup x live = NONE) l, numset_list_insert l live)
    ) /\ (
      check_endlive_fixed (Branch lt1 lt2) live =
        let (r1, live1) = check_endlive_fixed lt1 live in
        let (r2, live2) = check_endlive_fixed lt2 live in
        (r1 /\ r2, numset_list_insert (MAP FST (toAList (difference live2 live1))) live1)
    ) /\ (
      check_endlive_fixed (Seq lt1 lt2) live =
        let (r2, live2) = check_endlive_fixed lt2 live in
        let (r1, live1) = check_endlive_fixed lt1 live2 in
        (r1 /\ r2, live1)
    )`

val check_endlive_fixed_forward_def = Define`
    (
      check_endlive_fixed_forward (StartLive l) live =
        (T, numset_list_insert l live)
    ) /\ (
      check_endlive_fixed_forward (EndLive l) live =
        (EVERY (\x. lookup x live = SOME ()) l, numset_list_delete l live)
    ) /\ (
      check_endlive_fixed_forward (Branch lt1 lt2) live =
        let (r1, live1) = check_endlive_fixed_forward lt1 live in
        let (r2, live2) = check_endlive_fixed_forward lt2 live in
        (r1 /\ r2, numset_list_insert (MAP FST (toAList (difference live2 live1))) live1)
    ) /\ (
      check_endlive_fixed_forward (Seq lt1 lt2) live =
        let (r1, live1) = check_endlive_fixed_forward lt1 live in
        let (r2, live2) = check_endlive_fixed_forward lt2 live1 in
        (r1 /\ r2, live2)
    )`


val check_live_tree_forward_def = Define`
    (
      check_live_tree_forward f (StartLive l) live flive =
        check_partial_col f l live flive
    ) /\ (
      check_live_tree_forward f (EndLive l) live flive =
        let live_out = numset_list_delete l live in
        let flive_out = numset_list_delete (MAP f l) flive in
        SOME (live_out, flive_out)
    ) /\ (
      check_live_tree_forward f (Branch lt1 lt2) live flive =
        case check_live_tree_forward f lt1 live flive of
        | NONE => NONE
        | SOME (live1, flive1) =>
        case check_live_tree_forward f lt2 live flive of
        | NONE => NONE
        | SOME (live2, flive2) =>
        check_partial_col f (MAP FST (toAList (difference live2 live1))) live1 flive1
    ) /\ (
      check_live_tree_forward f (Seq lt1 lt2) live flive =
        case check_live_tree_forward f lt1 live flive of
        | NONE => NONE
        | SOME (live1, flive1) =>
          check_live_tree_forward f lt2 live1 flive1
    )`

val get_live_backward_def = Define`
    (
      get_live_backward (StartLive l) live =
        numset_list_delete l live
    ) /\ (
      get_live_backward (EndLive l) live =
        numset_list_insert l live
    ) /\ (
      get_live_backward (Branch lt1 lt2) live =
        let live1 = get_live_backward lt1 live in
        let live2 = get_live_backward lt2 live in
        numset_list_insert (MAP FST (toAList (difference live2 live1))) live1
    ) /\ (
      get_live_backward (Seq lt1 lt2) live =
        get_live_backward lt1 (get_live_backward lt2 live)
    )`

val get_live_forward_def = Define`
    (
      get_live_forward (StartLive l) live =
        numset_list_insert l live
    ) /\ (
      get_live_forward (EndLive l) live =
        numset_list_delete l live
    ) /\ (
      get_live_forward (Branch lt1 lt2) live =
        let live1 = get_live_forward lt1 live in
        let live2 = get_live_forward lt2 live in
        numset_list_insert (MAP FST (toAList (difference live2 live1))) live1
    ) /\ (
      get_live_forward (Seq lt1 lt2) live =
        let live1 = get_live_forward lt1 live in
        get_live_forward lt2 (get_live_forward lt1 live)
    )`

val fix_domination_def = Define`
    fix_domination lt =
        let live = get_live_backward lt LN in
        if live = LN then lt
        else Seq (StartLive (MAP FST (toAList live))) lt
`

val fix_live_tree_def = Define`
    fix_live_tree lt = fix_domination (FST (fix_endlive lt LN))
`

val numset_list_add_if_def = Define`
    (
      numset_list_add_if [] (v:int) s P = s
    ) /\ (
      numset_list_add_if (x::xs) v s P =
        case lookup x s of
        | (SOME v') =>
            if P v v' then numset_list_add_if xs v (insert x v s) P
            else numset_list_add_if xs v s P
        | NONE =>
            numset_list_add_if xs v (insert x v s) P
    )
`

val numset_list_add_if_lt_def = Define`
    numset_list_add_if_lt l (v:int) s = numset_list_add_if l v s $<=
`

val numset_list_add_if_gt_def = Define`
    numset_list_add_if_gt l (v:int) s = numset_list_add_if l v s (\a b. b <= a)
`

val size_of_live_tree_def = Define`
    (
      size_of_live_tree (StartLive l) =
        1 : int
    ) /\ (
      size_of_live_tree (EndLive l) =
        1 : int
    ) /\ (
      size_of_live_tree (Branch lt1 lt2) =
        size_of_live_tree lt1 + size_of_live_tree lt2
    ) /\ (
      size_of_live_tree (Seq lt1 lt2) =
        size_of_live_tree lt1 + size_of_live_tree lt2
    )
`

val get_intervals_def = Define`
    (
      get_intervals (StartLive l) (n : int) int_beg int_end =
        (n-1, numset_list_add_if_lt l n int_beg, numset_list_add_if_gt l n int_end)
    ) /\ (
      get_intervals (EndLive l) (n : int) int_beg int_end =
        (n-1, int_beg, numset_list_add_if_gt l n int_end)
    ) /\ (
      get_intervals (Branch lt1 lt2) (n : int) int_beg int_end =
        let (n2, int_beg2, int_end2) = get_intervals lt2 n int_beg int_end in
        get_intervals lt1 n2 int_beg2 int_end2
    ) /\ (
      get_intervals (Seq lt1 lt2) (n : int) int_beg int_end =
        let (n2, int_beg2, int_end2) = get_intervals lt2 n int_beg int_end in
        get_intervals lt1 n2 int_beg2 int_end2
    )
`

(* compute the same thing as `get_intervals` (as says the `get_intervals_withlive_beg_eq_get_intervals_beg` theorem), but has better invariants for the proofs *)
val get_intervals_withlive_def = Define`
    (
      get_intervals_withlive (StartLive l) (n : int) int_beg int_end live =
        (n-1, numset_list_add_if_lt l n int_beg, numset_list_add_if_gt l n int_end)
    ) /\ (
      get_intervals_withlive (EndLive l) (n : int) int_beg int_end live =
        (n-1, numset_list_delete l int_beg, numset_list_add_if_gt l n int_end)
    ) /\ (
      get_intervals_withlive (Branch lt1 lt2) (n : int) int_beg int_end live =
        let (n2, int_beg2, int_end2) = get_intervals_withlive lt2 n int_beg int_end live in
        let (n1, int_beg1, int_end1) = get_intervals_withlive lt1 n2 (numset_list_delete (MAP FST (toAList live)) int_beg2) int_end2 live in
        (n1, numset_list_delete (MAP FST (toAList (union (get_live_backward lt1 live) (get_live_backward lt2 live)))) int_beg1, int_end1)
    ) /\ (
      get_intervals_withlive (Seq lt1 lt2) (n : int) int_beg int_end live =
        let (n2, int_beg2, int_end2) = get_intervals_withlive lt2 n int_beg int_end live in
        let (n1, int_beg1, int_end1) = get_intervals_withlive lt1 n2 int_beg2 int_end2 (get_live_backward lt2 live) in
        (n1, int_beg1, int_end1)
    )
`

val check_number_property_def = Define`
  (
    check_number_property (P : int -> num_set -> bool) (StartLive l) n live =
        let n_out = n-1 in
        let live_out = numset_list_delete l live in
        P n_out live_out
  ) /\ (
    check_number_property P (EndLive l) n live =
        let n_out = n-1 in
        let live_out = numset_list_insert l live in
        P n_out live_out
  ) /\ (
    check_number_property P (Branch lt1 lt2) n live =
        let r2 = check_number_property P lt2 n live in
        let r1 = check_number_property P lt1 (n-(size_of_live_tree lt2)) live in
        r1 /\ r2
  ) /\ (
    check_number_property P (Seq lt1 lt2) n live =
        let r2 = check_number_property P lt2 n live in
        let r1 = check_number_property P lt1 (n-size_of_live_tree lt2) (get_live_backward lt2 live) in
        r1 /\ r2
  )
`

val check_number_property_strong_def = Define`
  (
    check_number_property_strong (P : int -> num_set -> bool) (StartLive l) n live =
        let n_out = n-1 in
        let live_out = numset_list_delete l live in
        P n_out live_out
  ) /\ (
    check_number_property_strong P (EndLive l) n live =
        let n_out = n-1 in
        let live_out = numset_list_insert l live in
        P n_out live_out
  ) /\ (
    check_number_property_strong P (Branch lt1 lt2) n live =
        let r2 = check_number_property_strong P lt2 n live in
        let r1 = check_number_property_strong P lt1 (n-(size_of_live_tree lt2)) live in
        r1 /\ r2 /\ P (n - (size_of_live_tree (Branch lt1 lt2))) (get_live_backward (Branch lt1 lt2) live)
  ) /\ (
    check_number_property_strong P (Seq lt1 lt2) n live =
        let r2 = check_number_property_strong P lt2 n live in
        let r1 = check_number_property_strong P lt1 (n-size_of_live_tree lt2) (get_live_backward lt2 live) in
        r1 /\ r2
  )
`

val check_startlive_prop_def = Define`
  (
    check_startlive_prop (StartLive l) n beg end ndef =
        !r. MEM r l ==> (option_CASE (lookup r beg) ndef (\x.x) <= n /\
                        (?v. lookup r end = SOME v /\ n <= v))
  ) /\ (
    check_startlive_prop (EndLive l) n beg end ndef =
        T
  ) /\ (
    check_startlive_prop (Branch lt1 lt2) n beg end ndef =
        let r2 = check_startlive_prop lt2 n beg end ndef in
        let r1 = check_startlive_prop lt1 (n-(size_of_live_tree lt2)) beg end ndef in
        r1 /\ r2
  ) /\ (
    check_startlive_prop (Seq lt1 lt2) n beg end ndef =
        let r2 = check_startlive_prop lt2 n beg end ndef in
        let r1 = check_startlive_prop lt1 (n-size_of_live_tree lt2) beg end ndef in
        r1 /\ r2
  )`

val live_tree_registers_def = Define`
    (live_tree_registers (StartLive l) = set l) /\
    (live_tree_registers (EndLive l) = EMPTY) /\
    (live_tree_registers (Branch lt1 lt2) = live_tree_registers lt1 UNION live_tree_registers lt2) /\
    (live_tree_registers (Seq lt1 lt2) = live_tree_registers lt1 UNION live_tree_registers lt2)
`

val opt_compare_def = Define`
    (
        opt_compare (SOME (n1:int)) (SOME (n2:int)) = (n1 <= n2)
    ) /\ (
        opt_compare _ _ = T
    )
`

val interval_intersect_def = Define`
    interval_intersect (l1, r1) (l2, r2) = (opt_compare l1 r2 /\ opt_compare l2 r1)
`

val point_inside_interval_def = Define`
    point_inside_interval (l, r) n = (opt_compare l (SOME n) /\ opt_compare (SOME n) r)
`

val check_intervals_def = Define`
    check_intervals f int_beg int_end = !r1 r2.
      r1 IN domain int_beg /\ r2 IN domain int_beg /\
      interval_intersect (lookup r1 int_beg, lookup r1 int_end) (lookup r2 int_beg, lookup r2 int_end) /\
      f r1 = f r2
      ==>
      r1 = r2
`

val _ = export_theory ();
