open Hardcaml
open Signal

module type Config = sig
  val grid_width : int
  val grid_height : int
  val start_column_bits : int
end

module MakeBeamSplitter(Config : Config) = struct
  let grid_width = Config.grid_width
  let grid_height = Config.grid_height
  let start_column_bits = Config.start_column_bits

  module I = struct
    type 'a t = {
      clock : 'a;
      clear : 'a;
      start : 'a; [@bits 1]
      start_column : 'a; [@bits start_column_bits]
      splitters : 'a; [@bits grid_width]
    } [@@deriving sexp_of, hardcaml]
  end

  module O = struct
    type 'a t = {
      split_count : 'a; [@bits 32]
      total_timelines: 'a; [@bits 64]
    } [@@deriving sexp_of, hardcaml]
  end

  let create (i : _ I.t) : _ O.t =
    let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in

    let starting_beam =
      log_shift sll (of_int ~width:grid_width 1) i.start_column
    in

    let beams = reg_fb spec ~width:grid_width ~f:(fun current ->
      mux2 i.start
        (starting_beam)
        (
          let splits = current &: i.splitters in
          let continuing_beams = current &: (~:(i.splitters)) in
          let right_beams = log_shift srl splits (of_int ~width:8 1) in
          let left_beams = log_shift sll splits (of_int ~width:8 1) in
          continuing_beams |: left_beams |: right_beams
        )
    ) in

    let split_counter = reg_fb spec ~width:32 ~f:(fun current ->
      let splits = beams &: i.splitters in
      mux2 i.start
        (of_int ~width:32 0)
        (current +: (uresize (popcount splits) 32))
    ) in

    let timeline_counter_width = 64 in
    let zero_timeline = of_int ~width:timeline_counter_width 0 in

    let current_counter_wires = List.init grid_width (fun _ ->
      wire timeline_counter_width
    ) in

    let next_values = List.mapi (fun col _ ->
      let current_counter = List.nth current_counter_wires col in
      mux2 i.start
        (mux2 (of_int ~width:grid_width col ==: uresize i.start_column grid_width)
          (of_int ~width:timeline_counter_width 1)
          zero_timeline)
        (
          let from_left = if col = 0
            then zero_timeline
            else
              let prev_left = List.nth current_counter_wires (col - 1) in
              let is_left_splitter = bit i.splitters (col - 1) in
              mux2 is_left_splitter prev_left zero_timeline
          in

          let from_right = if col = (grid_width - 1)
            then zero_timeline
            else
              let prev_right = List.nth current_counter_wires (col + 1) in
              let is_right_splitter = bit i.splitters (col + 1) in
              mux2 is_right_splitter prev_right zero_timeline
          in

          let is_splitter = bit i.splitters col in
          let continuing = mux2 is_splitter zero_timeline current_counter in

          continuing +: from_left +: from_right
        )
    ) current_counter_wires in

    let timeline_counters = List.map2 (fun current_wire next_value ->
      let register_out = reg spec next_value in
      current_wire <== register_out;
      register_out
    ) current_counter_wires next_values in

    let total_timelines = 
      List.fold_left (+:) (zero_timeline) timeline_counters 
    in

    {
      split_count = split_counter;
      total_timelines = total_timelines;
    }
end
