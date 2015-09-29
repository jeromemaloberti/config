let opencl_output = ref None
let opencl_output () = get_output opencl_output "opencl";;

let mode_name = "opencl";;

let build args =
  match !Ed_sourceview.active_sourceview with
    None -> ()
  | Some v ->
    let file = v#file#filename in
    let dir = Filename.dirname file in
    if Filename.check_suffix file ".cl" then
        begin
          let command = Printf.sprintf "(cd %s && ioc -cmd=compile -input=%s)" 
            (Filename.quote dir) (Filename.quote (Filename.basename file))
          in
          prerr_endline command;
          Ed_ocamlbuild.run ~output: (opencl_output ()) command
        end
      else ()
;;

let _ = Ed_commands.register (Ed_commands.unit_com "opencl_build" build);;

let default_key_bindings = [
  [[`MOD1], GdkKeysyms._b], "opencl_build";
];;

let (read,write,key_bindings) = config_init mode_name default_key_bindings;;

class opencl_mode =
  object
    inherit Ed_sourceview.empty_mode
    method name = "opencl"
    method key_bindings : (Okey.keyhit_state * string) list = key_bindings#get
    method menus : (string * GToolbox.menu_entry list) list = []

    initializer
      read (); write ()
  end
;;

let opencl_mode = new opencl_mode;;
let _ = Ed_sourceview.register_mode opencl_mode;;
let (add_sourceview_mode_opencl_key_binding, 
   add_sourceview_mode_opencl_key_binding_string) = 
  Ed_sourceview_rc.create_add_sourceview_mode_binding_commands key_bindings opencl_mode#name
