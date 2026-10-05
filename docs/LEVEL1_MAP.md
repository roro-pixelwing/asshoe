# Level 1: "Admin Wing" (map design)

Goal: power is cut and the exit gate is shut. Find **2 fuses**, put them in the **fuse box**,
then reach the **exit**. The Orderly patrols the central corridor that connects everything.

The map is literally this grid. `scripts/level/level_data.gd` holds it and the game builds the
geometry from it, so editing this text edits the level. One cell = 2.5 m.

```
###############################X##
#P...#..........#........#.......#     row 1: Reception | Lobby | Office | Fuse/exit room
#.*..#....*.....#....*...#...*...#
#....+..........+........+.......#
#.L..#.....B....#.L......#...G...#
##.###########.####.######.#######
#..........a...1...........2.....#     rows 6-8: main corridor (Orderly's patrol)
#..*.............*.............*.#
#.......####.........#####.......#
###.#######.#######.######.###.###
#....#......#....L#.......#....#.#
#.*..#...F..#..b..*#...L..#..*.#.#     rows 10-13: Records | Ward | Storage | Lounge
#....+......+......+......+......#
#L...#.4.B..#..3...#...c..#.F..L.#
##################################
```

| Symbol | Meaning |
|---|---|
| `#` | wall · `.` / `+` floor / doorway |
| `P` | player start |
| `*` | ceiling light (flickering). Standing under one makes you visible from far away |
| `L` | locker (hide spot) |
| `B` | battery · `F` fuse · `G` fuse box · `X` exit gate |
| `1`–`4` | Orderly patrol waypoints (loop 1→2→3→4) |
| `a` `b` `c` | scare triggers (see below) |

## Flow & pacing (≈10–15 min)
1. **Safe start (reception).** Dark, quiet. Teaches night vision; there's a locker to teach hiding.
2. **Corridor, scare `a` (false alarm):** a crash behind you and the lights die for 2 s. Nothing's there.
3. **First sighting:** the Orderly's patrol crosses the corridor ahead. If the player is careful they
   watch him pass. That is the tutorial: *he can't see you in the dark unless you're close.*
4. **Ward, scare `b` (reveal):** a patient stands motionless in the ward. You only notice him with
   night vision. Stinger. He's gone the next time you look.
5. **Fuse #1 (Records, west):** low risk, it's near the start.
6. **Storage, scare `c` (the hunt):** entering it makes the Orderly hear you **wherever he is** →
   scripted chase. Lockers in the lounge and records rooms are the escape plan. Fuse #2 is in the lounge.
7. **Fuse box (NE room)** → gate opens with a loud clank that alerts the Orderly → final sprint to `X`.

## Design rules applied
- **Loops:** the corridor connects to every room through at least two routes (rows 5 and 9 have
  multiple gaps), so chases never dead-end.
- **Hide spots** within ~6 cells of every point on the patrol route.
- **Light/dark contrast:** lights sit on the corridor and in doorways. Crossing them is a risk you choose.
