let output_name = "latex"
let latex_output = ref None
let latex_output () =
  match !latex_output with
    None ->
      let o = new Ed_outputs.text_output
        ~on_destroy: (fun () -> latex_output := None)
          output_name
      in
      latex_output := Some o ;
      o
  | Some o -> o
;;

let show_pdf args =
  match !Ed_sourceview.active_sourceview with
    None -> ()
  | Some v ->
      let file = v#file#filename in
      if Filename.check_suffix file ".tex" then
        begin
          let pdf = Printf.sprintf "%s.pdf" (Filename.chop_extension file) in
          let com = Printf.sprintf "xpdf %s &" (Filename.quote pdf) in
          ignore(Sys.command com)
        end
      else
        ()
;;
let _ = Ed_commands.register (Ed_commands.unit_com "show_pdf" show_pdf);;

let pdflatex args =
  match !Ed_sourceview.active_sourceview with
    None -> ()
  | Some v ->
      let file = v#file#filename in
      let dir = Filename.dirname file in
      if Filename.check_suffix file ".tex" then
        begin
          let command = Printf.sprintf
            "(cd %s && pdflatex %s)"
              (Filename.quote dir)
              (Filename.quote (Filename.basename file))
          in
          Ed_ocamlbuild.run ~output: (latex_output()) command
        end
      else
        ()
;;
let _ = Ed_commands.register (Ed_commands.unit_com "pdflatex" pdflatex);;

let make_html args =
  match !Ed_sourceview.active_sourceview with
    None -> ()
  | Some v ->
      let file = v#file#filename in
      let dir = Filename.dirname file in
      if Filename.check_suffix file ".tex" then
        begin
          let command = Printf.sprintf
            "(cd %s && make html)"
              (Filename.quote dir)
          in
          Ed_ocamlbuild.run ~output: (latex_output()) command
        end
      else
        ()
;;
let _ = Ed_commands.register (Ed_commands.unit_com "latex_make_html" make_html);;

let latex_insert_itemize args =
  match !Ed_sourceview.active_sourceview with
    None -> ()
  | Some v ->
      let s = "\\begin{itemize}\n\\item\n\\end{itemize}\n" in
      v#file#buffer#insert s
;;
let _ = Ed_commands.register
  (Ed_commands.unit_com "latex_insert_itemize" latex_insert_itemize);;

type section = [ `Part | `Chapter | `Section | `Subsection | `Subsubsection ];;
let section_strings =
  [ `Part, "part" ; `Chapter, "chapter" ;
    `Section, "section" ; `Subsection, "subsection" ;
    `Subsubsection, "subsubsection"
  ]
;;
let section_strings_inv = List.map (fun (a,b) -> (b,a)) section_strings;;

let compare_section s1 s2 =
  match s1, s2 with
  | _, _ when s1 = s2 -> 0
  | `Part, _
  | `Chapter, _
  | `Section, _
  | `Subsection, _ -> 1
  | _ -> - 1
;;

let find_next_section text pos =
  let re =
    Printf.sprintf "\\\\\\(%s\\)\\({.*\\)$"
      (String.concat "\\|" (List.map (fun (_,s) -> "\\("^s^"\\)") section_strings))
  in
  (*      prerr_endline ("find_next_section, re="^re);*)
  try
    let p = Str.search_forward (Str.regexp re) text pos in
    let s = Str.matched_group 1 text in
    let n = List.length section_strings + 2 in
    let label = Str.matched_group n text in
    Some
      (
       (List.assoc s section_strings_inv, label, p),
       p + String.length (Str.matched_string text)
      )
  with Not_found -> None
;;

let margin_offset_of_section = function
  `Part -> 0
| `Chapter -> 2
| `Section -> 4
| `Subsection -> 6
| `Subsubsection -> 8
;;

let margin_offset l =
  List.fold_left
    (fun acc (kind,_,_) ->
       min acc (margin_offset_of_section kind))
    max_int l

let goto_popup args =
  match !Ed_sourceview.active_sourceview with
    None -> ()
  | Some v ->
      let text = v#source_buffer#get_text () in
      let rec iter acc pos =
        match find_next_section text pos with
          None -> List.rev acc
        | Some ((kind, label, p), pos) -> iter ((kind, label, p)::acc) pos
      in
      match iter [] 0 with
        [] -> ()
      | l ->
          let margin_offset = margin_offset l in
          let entries = List.map
            (fun (kind, label, p) ->
               `I (Printf.sprintf "%s%s%s"
                (String.make (margin_offset_of_section kind - margin_offset) ' ')
                  (List.assoc kind section_strings) label,
                (fun _ -> Ed_commands.eval_command
                   (Printf.sprintf "sourceview_goto_char %d"
                    (Ed_utf8.utf8_char_of_index text p + 1))))
            )
              l
          in
          GToolbox.popup_menu ~entries ~button: 1 ~time: Int32.zero
;;
let _ = Ed_commands.register (Ed_commands.unit_com "latex_goto_section" goto_popup);;

let mode_name = "latex";;
let rc_file = Ed_sourceview_rc.mode_rc_file mode_name;;
let group = new Config_file.group;;
let default_key_bindings  = [
    [[`CONTROL], GdkKeysyms._p], "show_pdf" ;
    [[`CONTROL;`MOD1], GdkKeysyms._g], "latex_goto_section" ;
    [[`MOD1], GdkKeysyms._p], "pdflatex" ;
    [[`CONTROL], GdkKeysyms._i], "latex_insert_itemize" ;
    [[`CONTROL], GdkKeysyms._o], "latex_make_html" ;
    [[`CONTROL;`SHIFT], GdkKeysyms._plus], "sourceview_insert \"\\\\item\"";
  ]
;;
let key_bindings = new Config_file.list_cp Ed_config.binding_wrappers
  ~group
  ["key_bindings"] default_key_bindings "Key bindings"
;;
let read () = group#read rc_file;;
let write () = group#write rc_file;;

class latex_mode =
  object
    inherit Ed_sourceview.empty_mode
    method name = "latex"
    method key_bindings : (Okey.keyhit_state * string) list = key_bindings#get
    method menus : (string * GToolbox.menu_entry list) list = []

    initializer
      read(); write()
  end
;;
let latex_mode = new latex_mode;;
let _ = Ed_sourceview.register_mode latex_mode;;
let (add_sourceview_mode_latex_key_binding,
   add_sourceview_mode_latex_key_binding_string) =
  Ed_sourceview_rc.create_add_sourceview_mode_binding_commands
    key_bindings latex_mode#name
;;
