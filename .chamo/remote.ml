type remote_file =
  { rem_filename : string ;
    rem_host : string ;
    rem_login : string ;
  }

let tmp_dir = ".chamo.remote_files"
let table_file = Filename.concat tmp_dir "index"
let (table : (string, remote_file) Hashtbl.t) = Hashtbl.create 19

	(** create a new temp file and add it to the table. by now, temp files are created in /tmp even if we specify a different TMPDIR environment variable. It's a known bug/feature wish (PR#4003 in ocaml mantis system. *)

let new_temp_file remote =
  let old_tmpdir =
    try Unix.getenv "TMPDIR"
    with Not_found -> ""
  in
  Unix.putenv "TMPDIR" tmp_dir;
  let t = Filename.temp_file
    (Printf.sprintf "%s-%s-"
     (Filename.basename remote.rem_filename)
       remote.rem_host
    )
      ""
  in
  Unix.putenv "TMPDIR" old_tmpdir;
  Hashtbl.add table t remote;
  t


let retrieve_file ?tmpfile remote =
  let tmpfile =
    match tmpfile with
      Some f -> f (* so it's already in the table *)
    | None -> new_temp_file remote
      in
  let com = Printf.sprintf "scp %s@%s:%s %s"
    remote.rem_login remote.rem_host (Filename.quote remote.rem_filename)
      (Filename.quote tmpfile)
  in
  match Sys.command com with
    0 -> tmpfile
  | n -> failwith
      (Printf.sprintf "Error code %d with command %s" n com)


let send_file tmpfile remote =
  let com = Printf.sprintf "scp %s %s@%s:%s"
    (Filename.quote tmpfile)
      remote.rem_login remote.rem_host
      (Filename.quote remote.rem_filename)
  in
  match Sys.command com with
    0 -> ()
  | n -> failwith
      (Printf.sprintf "Error code %d with command %s" n com)


let get_existing_tmp_file remote =
  let tmp = ref None in
  Hashtbl.iter
    (fun tmpfile rem ->
       if rem.rem_host = remote.rem_host &&
         rem.rem_filename = remote.rem_filename
       then
         tmp := Some tmpfile
    )
    table;
  !tmp


let remote_of_filename filename =
  let f login host name =
    prerr_endline (Printf.sprintf "login=%s, host=%s, name=%s" login host name);
    { rem_login = login ;
      rem_host = host ;
      rem_filename = name ;
    }
  in
  try Some (Scanf.sscanf filename "ssh://%[^@]@@%[^:]:%s" f)
  with
    Scanf.Scan_failure _
  | End_of_file ->
      try Some (Scanf.sscanf filename "ssh://%[^:]:%s" (f Ed_installation.login))
      with Scanf.Scan_failure _ ->
          None


let on_open_file f_open args =
  if Array.length args < 1 then
    f_open args
  else
    (
     let args = Array.copy args in
     let filename = args.(0) in
     begin
       match remote_of_filename filename with
         Some remote ->
           let tmpfile = get_existing_tmp_file remote in
           let tmpfile = retrieve_file ?tmpfile remote in
           args.(0) <- tmpfile
       | None -> ()
     end;
     f_open args
    )


let on_save_active_view _ =
  let f w =
    match w#active_view with
      None -> ()
    | Some v ->
        let filename = v#filename in
        try
          let remote = Hashtbl.find table filename in
          send_file filename remote
        with
          Not_found -> ()
  in
  Ed_gui.on_active_window f ()


let _ =
  if not (Sys.file_exists tmp_dir) then (Unix.mkdir tmp_dir 0o700);
  let com_open = Ed_commands.get_com "open_file" in
  let f_open = com_open.Ed_commands.com_f in
  let com_open = { com_open with Ed_commands.com_f = (on_open_file f_open) } in
  Ed_commands.register ~replace: true com_open;
  let com_save = Ed_commands.get_com "save_active_view" in
  let com_save = { com_save with Ed_commands.com_f = on_save_active_view } in
  Ed_commands.register_after com_save
