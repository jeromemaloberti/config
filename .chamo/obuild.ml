let obuild_output = ref None
let obuild_output () = get_output obuild_output "obuild";;

let mode_name = "obuild";;

let build args =
  active_view_apply (fun v ->
    let file = v#file#filename in
    let dir = Filename.dirname file in
    if Filename.check_suffix file ".obuild" then
        begin
          let command = Printf.sprintf "(cd %s && obuild build)" 
            (Filename.quote dir) 
          in
          Ed_ocamlbuild.run ~output: (obuild_output ()) command
        end
      else ())
;;

let _ = Ed_commands.register (Ed_commands.unit_com "obuild_build" build);;

let default_key_bindings = [
  [[`MOD1], GdkKeysyms._b], "obuild_build";
];;

let (read,write,key_bindings) = config_init mode_name default_key_bindings;;

class obuild_mode =
  object
    inherit Ed_sourceview.empty_mode
    method name = "obuild"
    method key_bindings : (Okey.keyhit_state * string) list = key_bindings#get
    method menus : (string * GToolbox.menu_entry list) list = []

    initializer
      read (); write ()
  end
;;

let obuild_mode = new obuild_mode;;
let _ = Ed_sourceview.register_mode obuild_mode;;
let (add_sourceview_mode_obuild_key_binding, 
   add_sourceview_mode_obuild_key_binding_string) = 
  Ed_sourceview_rc.create_add_sourceview_mode_binding_commands key_bindings obuild_mode#name
