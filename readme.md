# Advent of Code - Day 7
### How to run

1. Build with `dune build`
2. Run with `dune exec ./beam_splitter_test.exe <path-to-input-file>`. Example: `dune exec ./beam_splitter_test.exe input.txt` (where input.txt is in the same directory as `beam_splitter_test.ml`)

Split count, total timelines and whether there was an overflow while calculating the timeline count will be printed.

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

## Part - 2
### How it works
Assuming that Q number of timelines have reached a point (x, y). The number of timelines at this point will change as
1. If there is a splitter at (x, y), then Q timelines will continue from (x - 1, y) and another Q will continue from (x + 1, y).
1. If there is no splitter at (x, y), then Q timelines will continue from (x, y).

This means, in order to calculate total number of timelines, we need to store number of timelines in each point, and whenever there is a split, we need to add the timelines on that point to left and right neighbour. 

To accomplish this
1. `BeamSplitter` keeps an array of `wire`s, one for each column. `wire` is needed to be able to access neighbor's register values.
1. `BeamSplitter` initializes with a single timeline on the start position
1. On each column on the subsequent given rows, `BeamSplitter` calculates how many timelines from: 
    - Left, if left had a splitter
    - Right, if right had a splitter
    - Same point, if it doesn't have a splitter.
1. Total number of timelines after the final row then gives total timelines possible in the entire grid.


## Scaling
As long as the timeline counter widths is updated, this can scale up 100x+ times. However, due to timelines count increasing exponentially, `BeamSplitter` uses 64 bits by default, but does flag whether an overflow happened.
