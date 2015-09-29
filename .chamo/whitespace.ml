let remove_trailing_whitespace args =
  match !Ed_gui.active_window with
    None -> ()
  | Some w ->
      match w#active_view with
        None -> ()
      | Some av ->
          begin
            match !Ed_sourceview.active_sourceview with
              None -> ()
            | Some v ->
                if Oo.id av = Oo.id v then
                  begin
                    let old_loc = v#file#location in
                    v#file#buffer#place_cursor v#file#buffer#start_iter;
                    let com = "sourceview_query_replace_re \"[ \t]+\n\" \"\n\"" in
                    Ed_commands.eval_command com;
                    v#set_location old_loc;
                  end
          end
;;
let _ =
  let com name = Ed_commands.create_com
    name [| |] remove_trailing_whitespace
  in
  Ed_commands.register_before (com "save_active_view");
  Ed_commands.register_before (com "save_active_view_as")


