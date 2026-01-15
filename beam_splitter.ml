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

    {
      split_count = split_counter;
    }
end
