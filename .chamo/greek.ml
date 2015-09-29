let mode_ocaml = Ed_sourceview.get_mode "ocaml";;
let substs =
  [ 945, "alpha", 'a' ;
    946, "beta", 'b' ;
    947, "gamma", 'c' ;
    948, "delta", 'd' ;
    949, "epsilon", 'e' ;
    950, "zeta", 'z' ;
    951, "eta", 'g' ;
    952, "theta", 'h' ;
    953, "iota", 'i' ;
    954, "kappa", 'k' ;
    955, "lambda", 'l' ;
    956, "mu", 'm' ;
    957, "nu", 'n' ;
    958, "xi", 'x' ;
    959, "omicron", 'o' ;
    960, "pi", 'p' ;
    961, "rho", 'r' ;
    962, "sigma", 's' ;
    964, "tau", 't' ;
    965, "upsilon", 'u' ;
    966, "phi", 'f' ;
    967, "chi", 'q' ;
    968, "psi", 'y' ;
    969, "omega", 'w' ;
  ]
;;
let substs =
  (List.map (fun (c, s, k) -> (c, "__"^s^"__", k)) substs) @
    (List.map (fun (c, s, k) -> (c - 32, "__"^(String.capitalize s)^"__", Char.uppercase k)) substs) @
    [ 
      8730, "sqrt ", 'V' ;
      178, "**2.0", '2' ;
    ]

let to_display =
  let l = List.map
    (fun (c,s,_) -> (Pcre.regexp (Pcre.quote s), Pcre.subst (Ed_utf8.utf8_char_of_code c)))
      substs
  in
  let f (rex, itempl) acc = Pcre.replace ~rex ~itempl acc in
  List.fold_right f l
;;
let from_display =
  let l = List.map
    (fun (c,s,_) -> (Pcre.regexp (Pcre.quote (Ed_utf8.utf8_char_of_code c)), Pcre.subst s))
      substs
  in
  let f (rex,itempl) acc = Pcre.replace ~rex ~itempl acc in
  List.fold_right f l
;;
mode_ocaml#set_to_display to_display;;
mode_ocaml#set_from_display from_display;;
let add_k (c,_,k) =
  let shift =
    match k with
      'A'..'Z' -> "S-"
    | _ -> ""
  in
  let com =
    Printf.sprintf "add_sourceview_mode_ocaml_key_binding '[\"C-i\";\"%s%c\"]' 'sourceview_insert_utf8 %d'"
      shift k c
  in
  Ed_commands.eval_command com
;;
List.iter add_k substs;;
