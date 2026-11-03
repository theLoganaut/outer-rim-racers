## Static game data, converted mechanically from reference.html. Edit freely.
class_name Data

const HZ := { "ICE": 2, "ACID": 3, "LAVA": 4, "WATER": 5, "ROUGH": 6 }

const FONT_SRC := {
  '0':'111/101/101/101/111','1':'010/110/010/010/111','2':'111/001/111/100/111',
  '3':'111/001/111/001/111','4':'101/101/111/001/001','5':'111/100/111/001/111',
  '6':'111/100/111/101/111','7':'111/001/001/010/010','8':'111/101/111/101/111',
  '9':'111/101/111/001/111',
  "A":'010/101/111/101/101',"B":'110/101/110/101/110',"C":'011/100/100/100/011',
  "D":'110/101/101/101/110',"E":'111/100/110/100/111',"F":'111/100/110/100/100',
  "G":'011/100/101/101/011',"H":'101/101/111/101/101',"I":'111/010/010/010/111',
  "J":'001/001/001/101/010',"K":'101/101/110/101/101',"L":'100/100/100/100/111',
  "M":'101/111/111/101/101',"N":'110/101/101/101/101',"O":'010/101/101/101/010',
  "P":'110/101/110/100/100',"Q":'010/101/101/110/011',"R":'110/101/110/101/101',
  "S":'011/100/010/001/110',"T":'111/010/010/010/010',"U":'101/101/101/101/111',
  "V":'101/101/101/101/010',"W":'101/101/111/111/101',"X":'101/101/010/101/101',
  "Y":'101/101/010/010/010',"Z":'111/001/010/100/111',
  ':':'000/010/000/010/000','.':'000/000/000/000/010','-':'000/000/111/000/000',
  '/':'001/001/010/100/100','!':'010/010/010/000/010',' ':'000/000/000/000/000',
  '+':'000/010/111/010/000','=':'000/111/000/111/000','>':'100/010/001/010/100',
  '<':'001/010/100/010/001','?':'111/001/010/000/010',',':'000/000/000/010/100',
  '(':'010/100/100/100/010',')':'010/001/001/001/010','%':'101/001/010/100/101',
  '$':'011/110/010/011/110','#':'101/111/101/111/101','*':'000/101/010/101/000',
  "'":'010/010/000/000/000','_':'000/000/000/000/111','[':'110/100/100/100/110',
  ']':'011/001/001/001/011'
}
const HALF := {
  "sled": [
    "....kkkkkkkk", "...kbbbllccc", "..kbbbbllccc", "..kbbbbbbbbb",
    ".kbbbbbbbbbb", "kbbwwbbbbbbb", "kbrrrrrrrrrr", "kggggggggggg",
    "kgkyyfkkkkkk", "kkkkffkk....", "..kkffk.....", "...kkkk....."
  ],
  "bike": [
    "..........kk", ".........kbb", ".........kbl", "........kbbc",
    ".......kbbcc", "......kbbbcc", ".....kgbbbwc", "....kkggrrrr",
    "....kgkyffkk", "....kkkkffkk", "......kkffk.", ".......kkkk."
  ],
  "skim": [
    "............", "......kkkkkk", "....kkbbbbll", "..kkbbbbllcc",
    "kkbbbbbblccc", "kbbwwbbbbbbb", "kbbbbbrrrrrr", "kgkkggggkkkk",
    "kyyfkkkkkkkk", ".kffk.......", "..kk........", "............"
  ],
  "pod": [
    "............", "kkkkkk......", "kbbbbk....kk", "kbllbk...kbc",
    "kbbbbk..kbcc", "kbwwbk.kbbcc", "kbbbbkkkkgbb", "kgggggkkgrrr",
    "kgyyfgk.....", "kkffkk......", ".kffk.......", "..kk........"
  ]
}
const PROP_HALF := {
  "wreck": [
    "............", "........kkkk", "......kkggdd", "....kkgggddd", "...kgggsgddd",
    "..kggdgggsgd", ".kggddggggdd", ".kgdddgsgggg", "kggdddggsggg", "kgsddkkgggdd",
    "kkkkkkkkkkkk", "...kkkkkkkkk", "............", "............"
  ],
  "rock": [
    "............", "..........kk", "........kkbb", "......kkbbll", "....kkbbbbll",
    "...kbbbbbbbb", "..kbbbddbbbb", ".kbbbbddbbbb", ".kbbbbbbbbdd", "kbbbbbbbbddd",
    "kbbbddbbbddd", "kkkkkkkkkkkk", "............", "............"
  ],
  "pylon": [
    "..........rr", "..........kk", "..........gg", ".........kgg", ".........kgd",
    "........kggd", "........kggd", ".......kkggd", "......kkgggd", ".....kkggddd",
    "....kkgggddd", "...kkkkkkkkk", "..kkkkkkkkkk", "............"
  ],
  "tree": [
    "....kkkkkkkk", "..kkggggllgg", ".kggggllgggg", "kggllggggggg", "kgggggggggdg",
    "kggggdggggdd", ".kggggggdddd", "..kkdddddddd", "....kkkkkkbb", "..........bb",
    "..........bb", "..........bb", "..........kk", "............"
  ],
  "mine": [
    "............", "............", "............", "............", "............",
    "............", "............", "..........kk", "........kkdd", ".......kdddd",
    "......kddrrd", ".....kdddrrg", "......kkddgg", "........kkkk"
  ],
  "crystal": [
    "............", ".........k..", "........kbk.", ".......kbblk", "......kbbbll",
    ".....kbbbblc", ".....kbbbbbl", "....kbbbbbbb", "....kbbddbbb", "...kbbbddbbb",
    "...kbbbbbbbb", "..kkkkkkkkkk", "............", "............"
  ]
}
const PAL_WRECK := { "k": '#14141f', "g": '#9aa0a8', "d": '#5e646c', "s": '#8a5a3a' }
const PAL_MINE := { "k": '#101018', "d": '#383848', "g": '#68687a', "r": '#ff3030' }
const PLANETS := {
  "hullfall": {
    "name": 'HULLFALL', "blurb": 'WHERE THE FLEETS CAME DOWN', "width": 287, "heat": 1.1, "roadGrip": 1.0,
    "ground": ['#c9a35a', '#bf9a50'], "groundStyle": 'dunes',
    "road": ['#8a7a62', '#948470'], "edgeLine": '#e8dcb8', "laneLine": '#d8c898', "curb": ['#e0d0a8', '#a04a2a'],
    "sky": ['#c88c50', '#d49c5c', '#dcac68', '#e4bc78', '#ecca88', '#f0d498', '#f4dca8', '#f8e4b4'],
    "fog": '#f0d8a8', "mtn": [{ "col": '#b88a5a', "base": 6, "a1": 3, "f1": 4, "a2": 2, "f2": 9, "par": 1 }, { "col": '#9a7048', "base": 4, "a1": 3, "f1": 7, "a2": 2, "f2": 13, "par": 1.6 }],
    "scenery": 'destroyer',
    "gen": { "dents": 0.3, "verts": [7, 9], "fillet": [380, 620], "sq": 0.85, "bumps": [1, 2], "amp": 0.20, "kmax": 4, "stretch": [1.0, 1.35], "haz": [], "fume": 0, "cave": 0, "shortcuts": 0, "obst": { "kind": 'wreck', "on": 9, "decor": 70 } },
    "props": { "wreck": PAL_WRECK },
    "decorKinds": [{ "kind": 'wreck', "w": 44, "ah": 1.0 }, { "kind": 'wreck', "w": 28, "ah": 0.9 }]
  },
  "rime": {
    "name": 'VESPER RIME', "blurb": 'TREACHEROUS ICE', "width": 308, "heat": 0.6, "roadGrip": 0.95,
    "ground": ['#dfe8f4', '#d0dcec'], "groundStyle": 'snow',
    "road": ['#8ea6c8', '#9cb2d2'], "edgeLine": '#ffffff', "laneLine": '#dff0ff', "curb": ['#ffffff', '#4a88c8'],
    "sky": ['#6c8cc0', '#7c9ccc', '#8caad6', '#9cb8de', '#acc6e6', '#bcd2ee', '#cde0f4', '#dcecfa'],
    "fog": '#dce8f8', "mtn": [{ "col": '#f0f6ff', "base": 12, "a1": 8, "f1": 3, "a2": 5, "f2": 7, "par": 1 }, { "col": '#a8bcd8', "base": 9, "a1": 5, "f1": 5, "a2": 3, "f2": 11, "par": 1.6 }],
    "scenery": 'aurora',
    "gen": { "dents": 0.2, "verts": [6, 8], "fillet": [500, 800], "sq": 0.5, "bumps": [0, 1], "amp": 0.17, "kmax": 4, "stretch": [1.1, 1.5], "haz": [{ "type": 2, "count": 4, "len": [26, 46], "side": 'full' }], "fume": 0, "cave": 0, "shortcuts": 0, "obst": { "kind": 'ice', "on": 6, "decor": 80 } },
    "props": { "ice": { "k": '#203050', "b": '#9cc8f0', "l": '#e8f6ff', "d": '#6aa0d8', "c": '#ffffff' } },
    "decorKinds": [{ "kind": 'crystal', "w": 26, "ah": 1.4, "pal": { "k": '#203050', "b": '#9cc8f0', "l": '#e8f6ff', "d": '#6aa0d8', "c": '#ffffff' } }, { "kind": 'rock', "w": 22, "ah": 0.9, "pal": { "k": '#203050', "b": '#c8d8ec', "l": '#ffffff', "d": '#8aa2c8' } }]
  },
  "sentinel": {
    "name": 'SENTINEL I', "blurb": 'TOXIC WASTELAND', "width": 276, "heat": 1.0, "roadGrip": 1.0,
    "ground": ['#3a3a42', '#32323a'], "groundStyle": 'acidrock',
    "road": ['#5a5a68', '#646472'], "edgeLine": '#e8d820', "laneLine": '#b8b8c8', "curb": ['#e8d820', '#202028'],
    "sky": ['#161c12', '#202a14', '#2c3a18', '#3c4c1c', '#506220', '#68782a', '#80922e', '#98a838'],
    "fog": '#6a7a28', "mtn": [{ "col": '#2a2a30', "base": 8, "a1": 4, "f1": 5, "a2": 3, "f2": 12, "par": 1 }, { "col": '#1c1c22', "base": 6, "a1": 4, "f1": 9, "a2": 2, "f2": 17, "par": 1.6 }],
    "scenery": 'antennas',
    "gen": { "dents": 0.42, "verts": [7, 10], "fillet": [320, 520], "sq": 0.9, "bumps": [2, 3], "amp": 0.22, "kmax": 5, "stretch": [1.0, 1.3], "haz": [{ "type": 3, "count": 4, "len": [5, 8], "side": 'full' }], "fume": 2, "cave": 0, "shortcuts": 0, "obst": { "kind": 'rock', "on": 7, "decor": 40 } },
    "props": { "rock": { "k": '#101014', "b": '#5a5a66', "l": '#8a8a98', "d": '#34343c' }, "pylon": { "r": '#ff3030', "k": '#101018', "g": '#8a8e98', "d": '#50545e' } },
    "decorKinds": [{ "kind": 'pylon', "w": 12, "ah": 3.2 }, { "kind": 'rock', "w": 24, "ah": 1.0, "pal": { "k": '#101014', "b": '#4a4a56', "l": '#707080', "d": '#2c2c34' } }]
  },
  "lantaana": {
    "name": 'LANTAANA', "blurb": 'RIVERS AND CAVES', "width": 270, "heat": 1.15, "roadGrip": 0.95,
    "ground": ['#2e6e3a', '#285f33'], "groundStyle": 'jungle',
    "road": ['#6a5a44', '#746450'], "edgeLine": '#c8b890', "laneLine": '#a89870', "curb": ['#8a6a40', '#3a2a1a'],
    "sky": ['#2a6a7a', '#34788a', '#3e8698', '#4a94a4', '#5aa4b0', '#72b4bc', '#8cc4c4', '#a8d4cc'],
    "fog": '#a8d8c0', "mtn": [{ "col": '#2a6a50', "base": 10, "a1": 5, "f1": 4, "a2": 3, "f2": 10, "par": 1 }, { "col": '#184a38', "base": 7, "a1": 4, "f1": 8, "a2": 4, "f2": 21, "par": 1.6 }],
    "scenery": 'mist',
    "gen": { "dents": 0.42, "verts": [7, 10], "fillet": [340, 560], "sq": 0.5, "bumps": [2, 3], "amp": 0.24, "kmax": 5, "stretch": [1.0, 1.25], "haz": [{ "type": 5, "count": 3, "len": [5, 8], "side": 'full' }, { "type": 4, "count": 2, "len": [12, 22], "side": 'half' }], "fume": 0, "cave": 2, "shortcuts": 0, "obst": { "kind": 'rock', "on": 7, "decor": 90 } },
    "props": { "rock": { "k": '#1c1408', "b": '#7a6a50', "l": '#a89878', "d": '#4e4230' } },
    "decorKinds": [{ "kind": 'tree', "w": 30, "ah": 1.7 }, { "kind": 'tree', "w": 22, "ah": 1.5 }]
  },
  "quarez": {
    "name": 'QUAREZ', "blurb": 'TWIN-SUN CANYONS', "width": 253, "heat": 1.2, "roadGrip": 1.0,
    "ground": ['#d8a860', '#cf9e56'], "groundStyle": 'dunes',
    "road": ['#9a7a52', '#a48460'], "edgeLine": '#f0e0b0', "laneLine": '#d0b880', "curb": ['#e8d098', '#8a4a28'],
    "sky": ['#5a98d8', '#6ca6de', '#80b4e2', '#98c2e4', '#b0d0e4', '#c8dce0', '#dce4d8', '#ecead0'],
    "fog": '#ecd8a8', "mtn": [{ "col": '#c08a50', "base": 11, "a1": 5, "f1": 3, "a2": 3, "f2": 8, "par": 1, "mesa": true }, { "col": '#a87040', "base": 8, "a1": 4, "f1": 6, "a2": 2, "f2": 13, "par": 1.6, "mesa": true }],
    "scenery": 'twinsuns',
    "gen": { "dents": 0.45, "verts": [7, 10], "fillet": [320, 500], "sq": 0.95, "bumps": [2, 3], "amp": 0.25, "kmax": 5, "stretch": [1.0, 1.4], "haz": [], "fume": 0, "cave": 0, "shortcuts": 0, "obst": { "kind": 'rock', "on": 10, "decor": 70 } },
    "props": { "rock": { "k": '#241810', "b": '#b07a46', "l": '#d8a468', "d": '#7a5030' } },
    "decorKinds": [{ "kind": 'rock', "w": 34, "ah": 1.5, "pal": { "k": '#241810', "b": '#b07a46', "l": '#d8a468', "d": '#7a5030' } }, { "kind": 'rock', "w": 22, "ah": 1.0, "pal": { "k": '#241810', "b": '#c28a52', "l": '#e4b078', "d": '#8a5a38' } }]
  },
  "cinnabar": {
    "name": 'CINNABAR VEIL', "blurb": 'RED SALT FLATS', "width": 353, "heat": 1.0, "roadGrip": 0.85,
    "ground": ['#e6ddd2', '#d8cdc0'], "groundStyle": 'salt',
    "road": ['#a83226', '#b43c2e'], "edgeLine": '#f4ece4', "laneLine": '#e8c8bc', "curb": ['#f4ece4', '#a83226'],
    "sky": ['#9a7c78', '#aa8a84', '#b89a92', '#c6aaa2', '#d4bab2', '#e0cac2', '#ecdad2', '#f4e8e0'],
    "fog": '#f0e4dc', "mtn": [{ "col": '#d0b0a6', "base": 9, "a1": 4, "f1": 3, "a2": 2, "f2": 7, "par": 1, "mesa": true }, { "col": '#b88a80', "base": 6, "a1": 3, "f1": 6, "a2": 2, "f2": 11, "par": 1.6, "mesa": true }],
    "scenery": 'mesas',
    "gen": { "dents": 0.22, "verts": [6, 8], "fillet": [450, 800], "sq": 1.0, "bumps": [0, 1], "amp": 0.27, "kmax": 4, "stretch": [1.2, 1.6], "haz": [], "fume": 0, "cave": 0, "shortcuts": 0, "obst": { "kind": 'crystal', "on": 4, "decor": 60 } },
    "props": { "crystal": { "k": '#4a2018', "b": '#e8e0d8', "l": '#ffffff', "c": '#f0c0b0', "d": '#c0a8a0' } },
    "decorKinds": [{ "kind": 'crystal', "w": 20, "ah": 1.4, "pal": { "k": '#4a2018', "b": '#e8e0d8', "l": '#ffffff', "c": '#f0c0b0', "d": '#c0a8a0' } }, { "kind": 'rock', "w": 26, "ah": 1.0, "pal": { "k": '#4a2018', "b": '#b84a3a', "l": '#d8786a', "d": '#7a2c24' } }]
  },
  "derven": {
    "name": 'DERVEN ACOS', "blurb": 'THE FINAL GAUNTLET', "width": 298, "heat": 1.1, "roadGrip": 1.0,
    "ground": ['#4a3a5a', '#42344f'], "groundStyle": 'arena',
    "road": ['#605a78', '#6a6484'], "edgeLine": '#40e8ff', "laneLine": '#a090d0', "curb": ['#40e8ff', '#2a2040'],
    "sky": ['#0c0820', '#14102c', '#1c1838', '#282048', '#38285c', '#4c3070', '#66408a', '#8a58a8'],
    "fog": '#5a3a78', "mtn": [{ "col": '#2a1c44', "base": 9, "a1": 5, "f1": 4, "a2": 3, "f2": 9, "par": 1 }, { "col": '#180f2c', "base": 6, "a1": 4, "f1": 7, "a2": 3, "f2": 15, "par": 1.6 }],
    "scenery": 'ringplanet',
    "gen": { "dents": 0.45, "verts": [8, 11], "fillet": [320, 520], "sq": 0.9, "bumps": [2, 3], "amp": 0.26, "kmax": 5, "stretch": [1.05, 1.4], "haz": [{ "type": 2, "count": 2, "len": [20, 34], "side": 'full' }, { "type": 3, "count": 2, "len": [5, 8], "side": 'full' }, { "type": 4, "count": 2, "len": [12, 20], "side": 'half' }, { "type": 5, "count": 1, "len": [5, 7], "side": 'full' }], "fume": 1, "cave": 1, "shortcuts": 0, "obst": { "kind": 'wreck', "on": 9, "decor": 50 } },
    "props": { "wreck": { "k": '#0c0818', "g": '#7a6a9a', "d": '#42385a', "s": '#40e8ff' } },
    "decorKinds": [{ "kind": 'pylon', "w": 12, "ah": 3.4, "pal": { "r": '#40e8ff', "k": '#0c0818', "g": '#6a5a8a', "d": '#3a2e52' } }, { "kind": 'crystal', "w": 24, "ah": 1.5, "pal": { "k": '#0c0818', "b": '#7a58c8', "l": '#c0a0ff', "c": '#40e8ff', "d": '#4a3490' } }]
  }
}
const PROP_SHAPE := { "wreck": 'wreck', "rock": 'rock', "ice": 'rock', "crystal": 'crystal', "pylon": 'pylon', "tree": 'tree' }
const PROP_RADIUS := { "wreck": 9, "rock": 6.5, "ice": 6.5, "crystal": 6, "pylon": 5, "tree": 6.5 }
const VEH := {
  "sled": { "name": 'GRAVSLED', "top": 1.00, "acc": 1.00, "turn": 1.00, "grip": 6.0, "drift": 0.7, "armor": 1.35, "hitR": 8.5, "wmul": 1.15, "shove": 1.0, "absorb": 0.5, "cost": 0,
    "blurb": ['HEAVY AND STABLE.', 'SOAKS UP CONTACT. DRIFTS.'], "cb": ['#3a62d8', '#8aa8ff', '#e8c030'] },
  "bike": { "name": 'WASPJET', "top": 1.07, "acc": 1.15, "turn": 1.25, "grip": 4.2, "armor": 0.75, "hitR": 6, "wmul": 0.85, "shove": 0.7, "absorb": 0, "drift": 1, "cost": 10,
    "blurb": ['FAST AND FRAGILE.', 'SPACE DRIFTS FOR A BURST.'], "cb": ['#d83a3a', '#ff9a9a', '#ffffff'] },
  "skim": { "name": 'KEELSKIMMER', "drift": 0.9, "top": 1.10, "acc": 0.72, "turn": 1.05, "grip": 3.6, "armor": 1.0, "hitR": 9.5, "wmul": 1.3, "shove": 1.6, "absorb": 0.2, "momentum": 1, "cost": 10,
    "blurb": ['BUILDS MOMENTUM.', 'SPACE DRIFTS FOR A BURST.'], "cb": ['#30b070', '#90f0b8', '#ffffff'] },
  "pod": { "name": 'TETHERJET', "top": 1.20, "acc": 0.90, "turn": 0.85, "grip": 5.0, "armor": 0.85, "hitR": 10, "wmul": 1.45, "shove": 1.2, "absorb": 0, "drift": 0.6, "cost": 25,
    "blurb": ['FASTEST CLASS.', 'HARD TO TURN. DRIFTS.'], "cb": ['#e8a020', '#ffe080', '#d03030'] }
}
const STYLES := {
  "survivor": { "name": 'SURVIVOR', "ability": 'shield', "top": 1.04, "blurb": ['SHIELD BLOCKS HITS.', '+4% TOP SPEED.'] },
  "tenacious": { "name": 'TENACIOUS', "ability": 'autopilot', "crash": 1, "blurb": ['AUTOPILOT DRIVES.', '+1 CRASH ALLOWED.'] },
  "ramjetrider": { "name": 'RAMJET RIDER', "ability": 'vent', "cool": 1.35, "blurb": ['VENT DUMPS HEAT.', 'COOLER ENGINE.'] },
  "brawler": { "name": 'BRAWLER', "ability": 'mines', "shove": 1.5, "ion": true, "blurb": ['ION MINES. ION BLAST.', 'HITS HARD.'], "unlock": { "stat": 'takedowns', "n": 5, "label": '5 TAKEDOWNS' } },
  "hacker": { "name": 'HACKER', "ability": 'hack', "blurb": ['HACK A "RIVAL": JAMS', 'THEIR BOOSTS.'], "unlock": { "stat": 'wins', "n": 3, "label": '3 RACE WINS' } },
  "gambler": { "name": 'GAMBLER', "ability": 'gamble', "blurb": ['ROLL FOR A BOOST.', 'JACKPOT, SURGE OR BUST.'], "unlock": { "stat": 'nearmiss', "n": 40, "label": '40 NEAR MISSES' } },
  "drifter": { "name": 'DRIFTER', "ability": 'flash', "driftMul": 1.3, "blurb": ['DRIFTS CHARGE 30% FASTER.', 'FLASH: INSTANT TURBO.'], "unlock": { "stat": 'turbos', "n": 30, "label": '30 DRIFT TURBOS' } },
  "phantom": { "name": 'PHANTOM', "ability": 'phase', "blurb": ['PHASE: SLIP THROUGH', 'ROCKS, CRAWLERS, RIVALS.'], "unlock": { "stat": 'goals', "n": 12, "label": '12 GOALS DONE' } }
}
const ABILITY := {
  "shield": { "name": 'SHIELD', "cd": 14 }, "autopilot": { "name": 'AUTOPILOT', "cd": 18 }, "vent": { "name": 'VENT', "cd": 9 },
  "mines": { "name": 'MINES', "cd": 5 }, "hack": { "name": 'HACK', "cd": 12 },
  "gamble": { "name": 'GAMBLE', "cd": 11 }, "flash": { "name": 'FLASH', "cd": 8 }, "phase": { "name": 'PHASE', "cd": 16 }
}
const PARTS := {
  "engine": { "name": 'ENGINE MK2', "desc": '+6% TOP SPEED', "top": 0.06 },
  "thruster": { "name": 'THRUSTERS', "desc": '+12% ACCELERATION', "acc": 0.12 },
  "gyro": { "name": 'GYRO', "desc": '+10% TURN, +10% GRIP', "turn": 0.10, "grip": 0.10 },
  "coolant": { "name": 'COOLANT', "desc": 'ENGINE RUNS 20% COOLER', "cool": 0.20 },
  "plating": { "name": 'PLATING', "desc": '+25% ARMOR', "armor": 0.25 },
  "cell": { "name": 'AB CELL', "desc": 'AFTERBURNER RECHARGES FASTER', "abRegen": 0.4 },
  "ioncore": { "name": 'ION CORE', "desc": 'CRASH "SKILL": ION BLAST', "ion": true },
  "capacitor": { "name": 'CAPACITOR', "desc": 'ABILITY COOLDOWN -30%', "cd": 0.3 },
  "frame": { "name": 'FRAME', "desc": '+1 CRASH ALLOWED', "crash": 1 },
  "magnet": { "name": 'MAGNET', "desc": 'NEAR MISSES REFILL 2X BOOST', "magnet": true }
}
## Owning both parts of a pair unlocks a synergy (see Race / Meta for what each does).
const SYNERGIES := {
  "overclock": { "name": 'OVERCLOCK', "needs": ['engine', 'coolant'], "desc": 'RAMJET 15% COOLER, +4% SPEED ON RAMJET' },
  "chain": { "name": 'CHAIN BLAST', "needs": ['ioncore', 'capacitor'], "desc": 'ABILITY FIRES AN ION PULSE, BIGGER BLAST' },
  "sling": { "name": 'SLINGSHOT', "needs": ['thruster', 'gyro'], "desc": 'DRIFT TURBOS LAST 35% LONGER' },
  "bulwark": { "name": 'BULWARK', "needs": ['plating', 'frame'], "desc": 'TAKEDOWNS REPAIR 30 HULL' },
  "feedback": { "name": 'FEEDBACK', "needs": ['cell', 'capacitor'], "desc": 'BOOSTING RECHARGES YOUR ABILITY' },
  "stunt": { "name": 'STUNT PILOT', "needs": ['magnet', 'thruster'], "desc": 'NEAR MISSES GIVE A SPEED BURST' }
}
## "tier": the middle of the field's BOT_TIERS spread (each bot rolls within about +-1.5 of it).
const DIFFS := [
  { "name": 'EASY', "crashes": 4, "skill": 0.93, "tier": 1.3 }, { "name": 'NORMAL', "crashes": 3, "skill": 1.0, "tier": 2.8 },
  { "name": 'HARD', "crashes": 2, "skill": 1.06, "tier": 4.0 }, { "name": 'EXPERT', "crashes": 1, "skill": 1.12, "tier": 5.0 }
]
## Bot pilot tiers, worst to best. pace: base speed. err: running wide into the wall in bends (per sec).
## look: how far ahead rocks are seen. dodge: chance of steering round hazards. ab / ram / drift / shield:
## chance the pilot uses that tool at all, and (higher = better) how well. ramMax +- ramVar: the heat they hold
## the ramjet to (over 100 = boom). aggro: how keen they are to hunt and ram other racers.
const BOT_TIERS := [
  { "name": 'NOOB',         "tag": 'NOOB', "pace": 0.86, "err": 0.45, "look": 110.0, "dodge": 0.3,  "ab": 0.0,  "ram": 0.0,  "ramMax": 0.0,  "ramVar": 0.0,  "drift": 0.0,  "shield": 0.0,  "aggro": 0.0 },
  { "name": 'BEGINNER',     "tag": 'BGN', "pace": 0.91, "err": 0.25, "look": 170.0, "dodge": 0.5,  "ab": 0.3,  "ram": 0.1,  "ramMax": 95.0, "ramVar": 14.0, "drift": 0.0,  "shield": 0.1,  "aggro": 0.0 },
  { "name": 'NOVICE',       "tag": 'NOV', "pace": 0.95, "err": 0.13, "look": 240.0, "dodge": 0.7,  "ab": 0.6,  "ram": 0.35, "ramMax": 88.0, "ramVar": 10.0, "drift": 0.25, "shield": 0.25, "aggro": 0.05 },
  { "name": 'STANDARD',     "tag": 'STD', "pace": 0.99, "err": 0.06, "look": 320.0, "dodge": 0.85, "ab": 0.85, "ram": 0.6,  "ramMax": 78.0, "ramVar": 8.0,  "drift": 0.5,  "shield": 0.5,  "aggro": 0.15 },
  { "name": 'ADVANCED',     "tag": 'ADV', "pace": 1.02, "err": 0.03, "look": 400.0, "dodge": 0.95, "ab": 1.0,  "ram": 0.85, "ramMax": 84.0, "ramVar": 5.0,  "drift": 0.7,  "shield": 0.7,  "aggro": 0.3 },
  { "name": 'PROFESSIONAL', "tag": 'PRO', "pace": 1.04, "err": 0.01, "look": 480.0, "dodge": 1.0,  "ab": 1.0,  "ram": 1.0,  "ramMax": 89.0, "ramVar": 3.0,  "drift": 0.9,  "shield": 0.9,  "aggro": 0.55 },
  { "name": 'STAR',         "tag": 'STAR', "pace": 1.06, "err": 0.0,  "look": 560.0, "dodge": 1.0,  "ab": 1.0,  "ram": 1.0,  "ramMax": 94.0, "ramVar": 1.0,  "drift": 1.0,  "shield": 1.0,  "aggro": 1.0 }
]
const BOT_NAMES := ['VEX', 'ORRIN', 'DASH', 'KIRA', 'ZED', 'MOKK', 'TALA', 'RUUK', 'SKIV', 'JUNO', 'BRAX', 'NYX']
const BOT_COLORS := [['#d03030', '#ff8080', '#ffe040'], ['#20a040', '#80e090', '#ffffff'], ['#d8b020', '#fff080', '#d03030'],
  ['#8a3ad0', '#d0a0ff', '#ffffff'], ['#e060a0', '#ffb0d8', '#4040ff'], ['#20a0c0', '#90e8ff', '#ffffff'],
  ['#e07020', '#ffc080', '#202020'], ['#707890', '#c0c8e0', '#d03030'], ['#a0d020', '#e0ff80', '#303030']]


## Moving hazards that crawl across the road: sprite (side view), and a palette + name per planet.
const CRAWLER_HALF := [
	"............", "..........kk", "......kkkkkk", "......kbbbll", "...kkkkbbbll", "..kddddbbbbb", ".kddddddbbbb",
	".kbbbbbbbbbb", ".kbbrrbbbbbb", ".kbbbbbbbbbb", ".kgggggggggg", "kkgkkgkkgkkg", "kkkkkkkkkkkk", "............"]
const MOVERS := {
	"hullfall": {"name": "SALVAGE RIG", "pal": {"k": "#241810", "b": "#8a5a3a", "l": "#c08a5a", "d": "#5a3a24", "r": "#ffd040", "g": "#4a4a50"}},
	"rime": {"name": "ICE HAULER", "pal": {"k": "#203050", "b": "#9cc8f0", "l": "#e8f6ff", "d": "#6aa0d8", "r": "#ff4040", "g": "#506080"}},
	"sentinel": {"name": "ACID TANKER", "pal": {"k": "#101014", "b": "#5a6a3a", "l": "#8a9a50", "d": "#34402a", "r": "#ff3030", "g": "#3a3a44"}},
	"lantaana": {"name": "LOG HAULER", "pal": {"k": "#1c1408", "b": "#6a7a50", "l": "#a0b078", "d": "#3e4a30", "r": "#ffd040", "g": "#4a4030"}},
	"quarez": {"name": "ORE CRAWLER", "pal": {"k": "#241810", "b": "#b07a46", "l": "#d8a468", "d": "#7a5030", "r": "#ffd040", "g": "#4a4a50"}},
	"cinnabar": {"name": "SALT HAULER", "pal": {"k": "#4a2018", "b": "#b84a3a", "l": "#d8786a", "d": "#7a2c24", "r": "#ffffff", "g": "#6a5a58"}},
	"derven": {"name": "ARENA DRONE", "pal": {"k": "#0c0818", "b": "#7a58c8", "l": "#c0a0ff", "d": "#4a3490", "r": "#40e8ff", "g": "#3a2e52"}},
}
