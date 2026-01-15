open Stdlib

let load_grid filename =
  let input_file = open_in filename in
  let rows = ref [] in

  try
    while true do
      let current_line = input_line input_file in
      rows := current_line :: !rows
    done;
    assert false
  with End_of_file ->
    close_in input_file;
    let rows = List.rev !rows in
    let first_line = List.nth rows 0 in
    let start_column = String.index first_line 'S' in
    let height = List.length rows in
    let width = String.length (List.hd rows) in
    Printf.printf "Grid size: %d × %d\n" width height;
    (rows, width, height, width - start_column - 1)

let row_to_splitter_bitmask_string row =
  let len = String.length row in
  let result = Bytes.create len in
  for i = 0 to len - 1 do
    Bytes.set result i (if row.[i] = '^' then '1' else '0')
  done;
  Bytes.to_string result
