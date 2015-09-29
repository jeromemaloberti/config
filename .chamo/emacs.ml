type result = Success of string list (* stdout *) * string list (* stderr *)
            | Failure of string list (* sterr *)

let verbose fmt = Printf.eprintf fmt

let read_lines in_channel =
  let lines = ref [] in
  begin
    try
      while true do
        let line = input_line in_channel in
        lines := line :: !lines
      done;
    with End_of_file ->
      close_in in_channel
  end;
  List.rev !lines

let write_fd fd buf =
  let len = ref (String.length buf) in
  let ofs = ref 0 in
  while !len > 0 do
    let written = Unix.write fd buf !ofs !len in
    if written = 0 then failwith "Cannot write file.";
    ofs := !ofs + written;
    len := !len - written
  done

let write_output path s =
  let fd = Unix.openfile path [Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC] 0o644 in
  write_fd fd s;
  Unix.close fd

let wait ?save_out_buf ?in_string in_ch out_ch err_ch =
  try
    (match in_string with
       None -> ()
     | Some i ->
       output_string in_ch i;
       flush in_ch;
       close_out in_ch;
    );
    let out_str = read_lines out_ch in
    let err_str = read_lines err_ch in
    (match save_out_buf with
     None -> ()
     | Some f -> write_output f (String.concat "\n" out_str)
    );
    Success (out_str, err_str)
  with _ ->
    let err_str = read_lines err_ch in
    Failure err_str

let call_process ?env ?in_string ?save_out_buf args =
  let env = match env with
    | None -> Unix.environment ()
    | Some e -> Array.append (Unix.environment ()) e in
  let com = String.concat " " args in
  verbose "  [CMD]: %s\n%!" com;
  let (out_ch,in_ch,err_ch) = Unix.open_process_full com env in
  let res = wait ?save_out_buf ?in_string in_ch out_ch err_ch in
  ignore(Unix.close_process_full (out_ch,in_ch,err_ch));
  res

