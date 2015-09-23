open preamble bvl_to_bviTheory bvi_to_targetTheory;

val _ = new_theory "bvl_to_target";

val _ = type_abbrev("bvl_conf", ``:num # 'a bvp_conf``);

val compile_def = Define`
  compile start ((n,c):'a bvl_conf) progs =
    let (start,bvi_progs,n) = bvl_to_bvi$compile_prog start n progs in
      case bvi_to_target$compile start c bvi_progs of
      | NONE => NONE
      | SOME (bytes,c) => SOME (bytes,(n,c))`

val _ = export_theory ();
