open Hardcaml
open Signal

module type Config = sig
  val grid_width : int
  val start_column_bits : int
end

module MakeBeamSplitter(Config : Config) = struct
  let grid_width = Config.grid_width
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
      timeline_count_overflow: 'a; [@bits 1]
    } [@@deriving sexp_of, hardcaml]
  end

  let create_beams spec ~start ~start_column ~splitters = 
    let starting_beam =
      log_shift sll (of_int ~width:grid_width 1) start_column
    in
    reg_fb spec ~width:grid_width ~f:(fun current ->
      mux2 start
        (starting_beam)
        (
          let splits = current &: splitters in
          let continuing_beams = current &: (~:splitters) in
          let right_beams = log_shift srl splits (of_int ~width:8 1) in
          let left_beams = log_shift sll splits (of_int ~width:8 1) in
          continuing_beams |: left_beams |: right_beams
        )
    )
  
  let create_split_counter spec ~beams ~start ~splitters = reg_fb spec ~width:32 ~f:(fun current ->
      let splits = beams &: splitters in
      mux2 start
        (of_int ~width:32 0)
        (current +: (uresize (popcount splits) 32))
    )
  
  let create_total_timelines spec ~start ~start_column ~splitters =
    let timeline_counter_width = 64 in
    let zero_timeline = of_int ~width:timeline_counter_width 0 in

    let current_counter_wires = List.init grid_width (fun _ ->
      wire timeline_counter_width
    ) in

    let next_values = List.mapi (fun col _ ->
      let current_counter = List.nth current_counter_wires col in
      mux2 start
        (mux2 (of_int ~width:grid_width col ==: uresize start_column grid_width)
          (of_int ~width:timeline_counter_width 1)
          zero_timeline)
        (
          let from_left = if col = 0
            then zero_timeline
            else
              let prev_left = List.nth current_counter_wires (col - 1) in
              let is_left_splitter = bit splitters (col - 1) in
              mux2 is_left_splitter prev_left zero_timeline
          in

          let from_right = if col = (grid_width - 1)
            then zero_timeline
            else
              let prev_right = List.nth current_counter_wires (col + 1) in
              let is_right_splitter = bit splitters (col + 1) in
              mux2 is_right_splitter prev_right zero_timeline
          in

          let is_splitter = bit splitters col in
          let continuing = mux2 is_splitter zero_timeline current_counter in

          continuing +: from_left +: from_right
        )
    ) current_counter_wires in

    let timeline_counters = List.map2 (fun current_wire next_value ->
      let register_out = reg spec next_value in
      current_wire <== register_out;
      register_out
    ) current_counter_wires next_values in

    List.fold_left (+:) (zero_timeline) timeline_counters 
  
  let create_timeline_count_overflow spec ~total_timelines ~start =
    let total_timelines_register = reg spec total_timelines in
    let total_timelines_overflow = (~:start) &: (total_timelines <: total_timelines_register) in
    reg_fb spec ~width:1 ~f:(fun current ->
      mux2 start gnd (current |: total_timelines_overflow)
    ) 

  let create (i : _ I.t) : _ O.t =
    let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in

    let beams = create_beams spec ~start:i.start ~start_column:i.start_column ~splitters:i.splitters in
    let split_counter = create_split_counter spec ~beams:beams ~start:i.start ~splitters:i.splitters in
    let total_timelines = create_total_timelines spec ~start:i.start ~start_column:i.start_column ~splitters:i.splitters in
    let timeline_count_overflow = create_timeline_count_overflow spec ~start:i.start ~total_timelines:total_timelines in

    {
      split_count = split_counter;
      total_timelines = total_timelines;
      timeline_count_overflow = timeline_count_overflow
    }
end
