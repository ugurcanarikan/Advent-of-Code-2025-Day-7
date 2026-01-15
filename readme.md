# Advent of Code - Day 7
### How to run

1. Put the input into a file called `input.txt`
2. Build with `dune build beam_splitter_test.exe`
3. Run with `dune exec ./beam_splitter_test.exe`. Split count will be printed. 

## Part - 1
### How it works
1. `beam_splitter_test.ml` reads the input file, gets all the rows, width, column and starting position. Then it converts rows to bitmask strings based on the locations of splitters (1 if there is a splitter and 0 otherwise), and feeds into the `BeamSplitter` one row at a time.
2. `BeamSplitter` keeps an internal register with feedback for `beams` (current beams in the row) and another register with feedback for `split_counter` (cumulative sum of all the splits, needed for Part-1).
3. `splits` in a row is calculated as `beams AND splitters`. This gives the positions where a split happened.
4. In order to find the beams that form on the right hand side of the splitter, `BeamSplitter` does shift right logical on the splits.
5. In order to find the beams that form on the left hand side of the splitter, `BeamSplitter` does shift left logical on the splits.
6. In order to find the continuing beams that didn't hit a splitter in that row, `BeamSplitter` does `beams AND (NOT splitters)`
7. Beams in the next round are then calculated as `left OR right OR continuing`
8. `split_counter` is increased by the number of 1 bits in the `splits`