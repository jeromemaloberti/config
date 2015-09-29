let output_name = "R";;
let r_output = ref None;;
let r_output () =
  match !r_output with
    None ->
      let o = new Ed_outputs.interactive_output
        ~on_destroy: (fun () -> r_output := None)
          ~name: output_name ~command: "R --no-save --no-readline"
      in
      r_output := Some o ;
      o
  | Some o -> o
;;

let r_eval ?(output=r_output()) args =
  match !Ed_sourceview.active_sourceview with
    None -> ()
  | Some v ->
      let disp_code =
        let (start, stop) = v#file#buffer#selection_bounds in
        let s = v#file#buffer#get_text ~start ~stop () in
        if String.length s > 0 then
          s
        else
          v#file#buffer#get_text ()
      in
      let code = v#file#mode_from_display disp_code in
      let outputs = Ed_outputs.outputs () in
      begin
        try ignore(outputs#output_by_name output#name)
        with Not_found ->
            outputs#add_output (output :> Ed_outputs.output);
      end;
      outputs#show output#name;
      output#run (code^"\n") ignore
;;

let _ = Ed_commands.register ~replace: true
  (Ed_commands.unit_com "r_eval" (r_eval ?output:None));;

let mode_name = "R";;
let rc_file = Ed_sourceview_rc.mode_rc_file mode_name;;

let group = new Config_file.group;;

let default_key_bindings  = [
    [[`CONTROL], GdkKeysyms._p], "r_eval" ;
  ]
;;

let key_bindings = new Config_file.list_cp Ed_config.binding_wrappers ~group
  ["key_bindings"] default_key_bindings "Key bindings"
;;

let read () = group#read rc_file;;
let write () = group#write rc_file;;

class r_mode =
  object
    inherit Ed_sourceview.empty_mode
    method name = "R"
    method key_bindings : (Okey.keyhit_state * string) list = key_bindings#get
    method menus : (string * GToolbox.menu_entry list) list = []

    initializer
      read(); write()
  end;;

let r_mode = new r_mode;;
let _ = Ed_sourceview.register_mode r_mode;;
let (add_sourceview_mode_r_key_binding,
   add_sourceview_mode_r_key_binding_string) =
  Ed_sourceview_rc.create_add_sourceview_mode_binding_commands
        key_bindings r_mode#name
;;
