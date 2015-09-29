let output_name = "make";;
let make_output = ref None;;
let make_output () =
  match !make_output with
    None ->
      let o = new Ed_outputs.text_output
        ~on_destroy: (fun () -> make_output := None)
          output_name
      in
      make_output := Some o ;
      o
  | Some o -> o
;;

let ocaml_make args =
  let (dir, targets) =
    match Array.length args with
      n when n <= 0 -> (Sys.getcwd (), "")
    | 1 -> (args.(1), "")
    | n -> (args.(1), String.concat " " (Array.to_list (Array.sub args 1 (n-1))))
  in
  let command = Printf.sprintf "cd %s ; make %s"
    (Filename.quote dir) targets
  in
  begin
    match !Ed_sourceview.active_sourceview with
      None -> ()
    | Some v -> v#file#write_file ()
  end;
  Ed_ocamlbuild.run ~output: (make_output()) command;

;;

Ed_commands.register (Ed_commands.create_com "ocaml_make" [| "directory ; targets"|] ocaml_make);;
