#directory "/root/.opam/4.02.0/lib/chamo";;
#mod_use "/root/.chamo/emacs.ml";;

let get_output r name =
  match !r with
    None -> let o = new Ed_outputs.text_output ~on_destroy: (fun () -> r := None) name in
    r := Some o;
    o
  | Some o -> o
;;


let maybe_apply f = function
    None -> ()
  | Some v -> f v;;

let active_view_apply f = maybe_apply f !Ed_sourceview.active_sourceview
;;

let config_init mode_name default_key_bindings =
  let rc_file = Ed_sourceview_rc.mode_rc_file mode_name in
  let group = new Config_file.group in
  let read () = group#read rc_file in
  let write () = group#write rc_file in
  let key_bindings = new Config_file.list_cp Ed_config.binding_wrappers ~group
    ["key_bindings"] default_key_bindings "Key bindings" in
  (read , write, key_bindings)
;;

let show_spaces _ =
  active_view_apply (fun v ->
      let tags = if (List.length v#source_view#draw_spaces) = 0 then
          [`SPACE; `TAB; `LEADING; `TRAILING]
        else
          []
      in
      v#source_view#set_draw_spaces tags
    )
;;

let args_1int default args =
  if (Array.length args) <> 1 then
    default
  else
    int_of_string args.(0)
;;


let _ = Ed_commands.register (Ed_commands.unit_com "show_spaces" show_spaces);;
let _ = Ed_commands.register (Ed_commands.unit_com "line_numbers"
                                (fun _ -> active_view_apply (fun v -> v#switch_line_numbers ())))
;;
let _ = Ed_commands.register (Ed_commands.unit_com "line_markers"
                                (fun _ -> active_view_apply (fun v -> v#switch_line_markers ())))
;;
let _ = Ed_commands.register (Ed_commands.unit_com "show_right_margin"
                                (fun _ -> active_view_apply (fun v -> v#source_view#set_show_right_margin true)))
;;
let _ = Ed_commands.register (Ed_commands.create_com "set_right_margin" [| "position" |]
                                (fun args -> active_view_apply (fun v -> v#source_view#set_right_margin_position (args_1int 80 args))))
;;
let _ = Ed_commands.register (Ed_commands.unit_com "center_buffer"
                                (fun _ -> active_view_apply (fun v -> v#source_view#scroll_to_mark ~use_align:true ~yalign:0.5 `INSERT)))
;;
let _ = Ed_commands.register (Ed_commands.unit_com "top_buffer"
                                (fun _ -> active_view_apply (fun v -> v#source_view#scroll_to_mark ~use_align:true ~yalign:0.0 `INSERT)))
;;
let _ = Ed_commands.register (Ed_commands.unit_com "bottom_buffer"
                                (fun _ -> active_view_apply (fun v -> v#source_view#scroll_to_mark ~use_align:true ~yalign:1.0 `INSERT)))
;;
let _ = Ed_commands.register (Ed_commands.unit_com "revert_buffer"
                                (fun _ -> Ed_commands.eval_command "reload_active_view"))
;;
let _ = Ed_commands.register (Ed_commands.unit_com "eval_region"
                                (fun _ -> active_view_apply (fun v ->
                                     let b = v#source_view#buffer in
                                     let (start,stop) = b#selection_bounds in
                                     (*     let start = b#get_iter `INSERT in
                                            let stop = b#get_iter `SEL_BOUND in *)
                                     let code = b#get_text ~start ~stop () in
                                     if (String.length code > 0) then
                                       Ed_eval.eval_ocaml [|code|])))
;;

let get_selection_lines (b:GText.buffer) =
  let (start,stop) = b#selection_bounds in
  let start_line = start#line in
  let stop_line = if (stop#line > start_line) && (stop#line_offset = 0) then stop#line - 1 else stop#line in
  let bol = b#get_iter (`LINE start_line) in
  let eol = (b#get_iter (`LINE stop_line))#forward_to_line_end in
  (bol,eol)
;;

(*
let call_ocp_indent code start stop =
  let temp_file = Filename.temp_file "chamo" ".ml" in
  Ed_extern.file_of_string ~file:temp_file code;
  let com = Printf.sprintf "ocp-indent %s " (Filename.quote temp_file) in
  prerr_endline ("command: " ^ com);
  match Sys.command com with
    0 ->
    let indented = Ed_extern.string_of_file temp_file in
    Ed_extern.safe_remove_file temp_file;
    indented
  | _ -> Ed_extern.safe_remove_file temp_file;
    prerr_endline (Printf.sprintf "command failed: %s" com);
code
;;
*)
let call_ocp_indent_region (buf:GText.buffer) start stop =
  let whole = buf#get_text () in
  let lines = Printf.sprintf "%d-%d" (start+1) (stop+1) in
  let p = Emacs.call_process ~in_string:whole [ "ocp-indent"; "--numeric"; "-l"; lines ] in
  match p with
  | Emacs.Failure s -> prerr_endline (Printf.sprintf "ocp-indent failed: %s" (String.concat "\n" s));
    []
  | Emacs.Success (s_out,s_err) ->
    if(List.length s_err) > 0 then
      List.iter (fun l ->
          prerr_endline (Printf.sprintf "ocp-indent err: %s" l)) s_err;
    s_out
;;

let call_ocp_indent_buffer (buf:GText.buffer) =
  let whole = buf#get_text () in
  let p = Emacs.call_process ~in_string:whole [ "ocp-indent" ] in
  match p with
  | Emacs.Failure s -> prerr_endline (Printf.sprintf "ocp-indent failed: %s" (String.concat "\n" s));
    []
  | Emacs.Success (s_out,s_err) ->
    if(List.length s_err) > 0 then
      List.iter (fun l ->
          prerr_endline (Printf.sprintf "ocp-indent err: %s" l)) s_err;
    s_out
;;

let is_space = function
  | ' ' | '\012' | '\n' | '\r' | '\t' -> true
  | _ -> false
;;

let beginning_of_line line =
  let len = String.length line in
  let i = ref 0 in
  while !i < len && is_space (line.[!i]) do
    incr i
  done;
  if !i > 0 then
    String.sub line !i (len - !i)
  else
    line
;;

let indent_selection (buf:GText.buffer) (v:Ed_sourceview.sourceview) =
  let (bol,eol) = get_selection_lines buf in
  let indents = call_ocp_indent_region buf bol#line eol#line in
  let start_line = bol#line in
  let lines = Ed_extern.split_string (v#file#of_utf8
                                        (v#file#mode_from_display
                                           (buf#get_text ~start:bol ~stop:eol ()))) ['\n'] in
  let new_lines = List.map2 (fun line indent ->
      let ind = int_of_string indent in
      let trimmed_line = beginning_of_line line in
      if ind > 0 then ((String.make ind ' ') ^ trimmed_line) else trimmed_line)
      lines indents in
  buf#delete ~start:bol ~stop:eol;
  let pos = buf#get_iter (`LINE start_line) in
  v#place_cursor pos;
  buf#insert (v#file#mode_to_display (v#file#to_utf8 (String.concat "\n" new_lines)));
  let pos = buf#get_iter (`LINE start_line) in
  v#place_cursor pos
;;

let _ = Ed_commands.register (Ed_commands.unit_com "indent_region"
                                (fun _ -> active_view_apply (fun v ->
                                     let b = v#source_view#buffer in
                                     indent_selection b v
                                   )))
;;

let _ = Ed_commands.register (Ed_commands.unit_com "indent_buffer"
                                (fun _ -> active_view_apply (fun v ->
                                     let buf = v#source_view#buffer in
                                     let new_lines = call_ocp_indent_buffer buf in
                                     let (start,stop) = buf#bounds in
                                     buf#delete ~start ~stop;
                                     let pos = buf#get_iter (`LINE 0) in
                                     v#place_cursor pos;
                                     buf#insert (v#file#mode_to_display (v#file#to_utf8 (String.concat "\n" new_lines)));
                                     let pos = buf#get_iter (`LINE 0) in
                                     v#place_cursor pos
                                   )))
;;

(*
  let temp_file = Filename.temp_file "chamo" ".txt" in
  let com = Printf.sprintf "%s query -r %s > %s" Ed_installation.ocamlfind
    (String.concat " " packages) (Filename.quote temp_file)
  in
  match Sys.command com with
    0 ->
      let default_dirs = Ed_extern.split_string (Ed_extern.string_of_file temp_file) ['\n'] in
      Ed_extern.safe_remove_file temp_file;
      List.iter
      (fun d ->
         eval_ocaml
         [| Printf.sprintf "#directory \"%s\";;" d |])
      default_dirs
  | n ->
      Ed_extern.safe_remove_file temp_file;
      prerr_endline (Printf.sprintf "Command failed: %s" com)


let edit ?char file =
  let com = "emacsclient -n "^
    (match char with
      None -> ""
    | Some c ->
	let line = (Cam_misc.line_of_char file.Cam_types.f_name c) + 1 in
	(* + 1 because emacs start line numbers at 1 *)
	"+"^(string_of_int line)^" "
    )^
    (Filename.quote file.Cam_types.f_name)
  in
  let n = Sys.command com in
  if n = 0 then ()
  else raise (Failure (Cam_messages.error_exec com))

(** Make the user give an url and launch mozilla with this url.
   If no url is given, make the user type it. In this case,
   the default url begins with http:// or file:///, depending
   on whether a directory is selected or not.
   @command mozilla
*)
let mozilla args =
  let url_opt =
    match args with
      url :: _ -> Some url
    | [] ->
	GToolbox.input_string ~title: "mozilla"
	  ~text: (match selected_dir() with None -> "http://" | Some s -> "file:///"^s)
	  "url: "
  in
  match url_opt with
    None -> ()
  | Some s -> ignore (Sys.command ("mozilla "^(Filename.quote s)^" &"))

*)

(* TODO
   X eval_region -> get selection et appelle eval_ocaml ?
   let code = get_selection in
   Ed_eval.eval_ocaml [| code |]
   X revert_buffer -> delete ? buffer + open_file
   alias reload_active_view?
 * center_screen -> C-l
   command avec etat (copier interactive search)
   X home/end -> smart-home-end : ctrl+
 * selection -> C-space -> bouger la mark correspondante
   emacs -> call emacsclient -c
   diff files/buffers (ocamldiff)
   indent -> ocp-indent
   macros
   set_mode
   set_language

*)

(* #mod_use "/root/.chamo/greek.ml";; *)
#mod_use "/root/.chamo/make.ml";;
#mod_use "/root/.chamo/remote.ml";;
#mod_use "/root/.chamo/whitespace.ml";;
(* #mod_use "/root/.chamo/latex.ml";; *)
(* #mod_use "/root/.chamo/r.ml";; *)
#mod_use "/root/.chamo/backtraces.ml";;
#mod_use "/root/.chamo/obuild.ml";;
#mod_use "/root/.chamo/opencl.ml";;
