let factory_name = "stack_backtraces"

type raise_kind = Raised | Reraised | Called | Primitive
type trace =
  { raise_kind : raise_kind ;
    file : string ;
    line : int ;
    chars : int * int ;
  }

let string_of_raise_kind = function
  Raised -> "Raised at"
| Reraised -> "Re-raised at"
| Called -> "Called from"
| Primitive -> "Raised by primitive operation at";;

let trace_of_line line =
  let f kind _ file line start stop =
    let k =
      match String.lowercase kind with
        "raised" -> Raised
      | "re-raised" -> Reraised
      | "called" -> Called
      | "raised by primitive operation" -> Primitive
      | _ -> invalid_arg (Printf.sprintf "\"%s\" is not a valid raise kind" kind)
    in
    { raise_kind = k ;
      file = file ; line = line ; chars = (start, stop) ; }
  in
  try
    let t = Scanf.sscanf line "%s %s file %S, line %d, characters %d-%d" f in
    Some t
  with _ ->
      try
        let t =
          Scanf.sscanf line
            "Raised by primitive operation at file %S, line %d, characters %d-%d"
            (f "raised by primitive operation" "")
        in
        Some t
      with _ ->
          None
;;

let trace_list_of_file file =
  let s = Ed_extern.string_of_file file in
  let lines = Ed_extern.split_string s ['\n'] in
  let rec iter error prev_line acc = function
    [] -> (error, List.rev acc)
  | line :: q ->
      match trace_of_line line with
        None -> iter error line acc q
      | Some t ->
          match acc with
            [] -> iter prev_line line (t :: acc) q
          | _ -> iter error line (t :: acc) q
  in
  iter "" "" [] lines
;;

class trace_list =
  object(self)
    inherit [trace] Gmylist.plist `SINGLE
      [ None, Gmylist.String (fun t -> string_of_raise_kind t.raise_kind) ;
        Some "File", Gmylist.String (fun t -> Ed_misc.to_utf8 t.file) ;
        Some "Line", Gmylist.String (fun t -> string_of_int t.line) ;
        Some "Characters",
        Gmylist.String (fun t -> Printf.sprintf "%d-%d" (fst t.chars) (snd t.chars));
      ]
      true

    method on_select t =
      let com = Printf.sprintf "open_file %s %d,%d-%d"
        (Filename.quote t.file) (t.line - 1) (fst t.chars) (snd t.chars)
      in
      if Sys.file_exists t.file then Ed_commands.eval_command com;
      prerr_endline (Printf.sprintf "%s %s" (string_of_raise_kind t.raise_kind) t.file)
  end

class view (topwin : Ed_view.topwin) file =
  let box = GPack.vbox () in
  (*let wscroll = GBin.scrolled_window
    ~hpolicy: `AUTOMATIC `vpolicy: `AUTOMATIC ()
  in*)
  let wlabel = GMisc.label
    ~xpad: 4
    ~xalign: 0.0 ~packing: (box#pack ~expand: false) ()
  in
  let wlist = new trace_list in
  let () = box#pack ~expand: true ~fill: true wlist#box in
  object(self)
    inherit Ed_view.dyn_label
    inherit Ed_view.dyn_destroyable (fun () -> box#destroy())

    val mutable time = 0.0
    method update =
      let (error, traces) = trace_list_of_file file in
      wlabel#set_text (Ed_misc.to_utf8 (Printf.sprintf "%s: %s" file error));
      wlist#update_data traces

    method box = box#coerce
    method save : (unit -> unit) option = None
    method save_as : (unit -> unit) option = None
    method close = ()
    method reload = (None : (unit -> unit) option)
    method paste : (unit -> unit) option = None
    method copy : (unit -> unit) option = None
    method cut : (unit -> unit) option = None
    method dup : Ed_view.topwin -> Ed_view.gui_view option = fun _ -> None

    method kind = factory_name
    method filename = file
    method attributes : (string * string) list = []

    method set_on_focus_in (f : unit -> unit) =
      ignore(wlist#view#event#connect#focus_in (fun _ -> f (); false))
    method grab_focus = wlist#view#misc#grab_focus ()

    method key_bindings : (Okey.keyhit_state * string) list = []
    method menus : (string * GToolbox.menu_entry list) list = []

    initializer
      self#set_label (Ed_misc.to_utf8 (Filename.basename file));
      let rec cb () =
        try
          let t = (Unix.stat file).Unix.st_mtime in
          if t > time then
            (
              self#update; time <- t
            );
          ignore(GMain.Timeout.add ~ms: 2000 ~callback: cb);
          false
        with
          Unix.Unix_error (e,s1,s2) ->
            let msg = Printf.sprintf "%s: %s %s. Update delay is now 5s."
              s1 (Unix.error_message e) s2
            in
            wlabel#set_text (Ed_misc.to_utf8 (Printf.sprintf "%s: %s" file msg));
            ignore(GMain.Timeout.add ~ms: 5000 ~callback: cb);
            false
      in
      ignore(cb ())
  end

let create_view topwin file = new view topwin file

let open_file topwin active_view ?attributes filename =
  `New_view (create_view topwin filename :> Ed_view.gui_view)

	(**
Factory
*)


class factory : Ed_view.view_factory =
  object
    method name = factory_name
    method open_file = open_file
    method open_hidden = None
    method on_start = ()
    method on_exit = ()
  end


let _ = Ed_view.register_view_factory factory_name (new factory)
