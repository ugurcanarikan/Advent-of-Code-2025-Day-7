open Hardcaml
open Beam_splitter

let test () =
  let (rows, width, height, start_column) = Grid_loader.load_grid "input.txt" in
  let splitter_bitmask_strings = Array.of_list (List.map Grid_loader.row_to_splitter_bitmask_string rows) in

  let start_column_bits =
    let rec log2_ceil n acc =
      if n <= 1 then acc
      else log2_ceil ((n + 1) / 2) (acc + 1)
    in
    max 1 (log2_ceil width 0)
  in

  let module Config = struct
    let grid_width = width
    let start_column_bits = start_column_bits
  end in

  let module BeamSplitter = MakeBeamSplitter(Config) in

  let module Sim = Cyclesim.With_interface(BeamSplitter.I)(BeamSplitter.O) in
  let sim = Sim.create BeamSplitter.create in
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in

  inputs.clear := Bits.vdd;
  Cyclesim.cycle sim;
  inputs.clear := Bits.gnd;

  for row = 0 to height - 1 do
    inputs.start := if row = 0 then Bits.vdd else Bits.gnd;
    inputs.start_column := Bits.of_int ~width:start_column_bits start_column;
    let splitter_bitmask = Constant.of_binary_string splitter_bitmask_strings.(row) in
    inputs.splitters := Bits.of_constant splitter_bitmask;

    Cyclesim.cycle sim;
  done;

  Printf.printf "\nTotal split count: %d" (Bits.to_int !(outputs.split_count));
  Printf.printf "\nTotal timeline count: %d, total timeline overflow: %b\n"
    (Bits.to_int !(outputs.total_timelines)) (Bits.to_bool !(outputs.timeline_count_overflow))

let () = test ()
