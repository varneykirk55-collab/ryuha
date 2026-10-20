# Ryūha: Clash of Schools

A 2.5D samurai platform fighter for **Godot 4.3+ (GDScript)**. Smash-style percent and knockback, four fighters built from your sprite sheets, and one dojo stage built from your stage art.

Open `project.godot` in Godot 4.3 or newer and press **F5**. Godot imports the assets on first open, which takes a few seconds.

---

## What's in the first playable

| Area | Included |
|---|---|
| Core rules | Percent damage, Smash knockback formula, weight, hitstun, tumble, DI, tech (in place, roll, wall/ceiling), missed-tech knockdown with get-up options, ledges (intangibility, regrab decay, getup/roll/jump/attack/drop), blast zones, respawn platform, sudden death |
| Defence | Shield (shrinks, breaks, shield stun, pushback), roll, spot dodge, directional air dodge |
| Combat feel | Hitlag on attacker and victim, victim shake during hitlag, screen shake scaled by knockback, hit sparks, KO streaks, slash trails, clanks between grounded attacks |
| Input | 7-frame input buffer that stores the stick direction at press time; tilt / smash / flick-smash / C-stick; tap-jump on pads; short hop; fast fall; platform drop |
| Modes | Main menu → Versus setup → best-of-3 set → results (rematch / change fighters / menu). Training mode with dummy. Pause menu. Optional CPU opponent (levels 3–9) |
| Players | Local 1v1 with two keyboard layouts, keyboard + gamepad, or two gamepads |
| HUD | Damage % (counts up and reddens), stocks, portrait, timer, round score, banners |
| Training | Dummy behaviour (stand / crouch / jump / shield / walk / CPU), dummy DI (none / survival / combo / random), dummy % ±10, reset, 1x / ½x / ¼x speed, combo counter, knockback/hitstun readout, live frame data |
| Debug | **F1** anywhere toggles hitboxes (red, with id and launch angle), hurtboxes (yellow; blue when intangible), collision box (green), ledge-grab region (cyan), state + frame text, blast zone and camera bounds |
| Audio | Event-based hooks (`Sfx.play(&"hit_heavy")`) with generated placeholder sounds for swings, hits, clank, shield, jump, land, tech, charge, KO, menus |

## Controls

| Action | Keyboard (solo) | Keyboard L (shared) | Keyboard R (shared) | Gamepad |
|---|---|---|---|---|
| Move | WASD | WASD | Arrows | Left stick / D-pad |
| Jump | Space | Space | Num0 / M | X / Y (or tap up) |
| Attack (jab, tilts, aerials) | J | F | Num1 / , | A |
| Special | K | G | Num2 / . | B |
| Smash attack | I | H | Num3 / / | Right stick, or flick + A |
| Shield / dodge / tech | L | R | NumEnter / ' | LB, RB, LT, RT |
| Pause | Esc | Esc | Backspace | Start |

- **Tilts** are attack + direction. **Smashes** use the smash button, the right stick, or a quick stick flick with attack. Hold to charge.
- **Specials** are special + neutral, side, down, or up. Up is the recovery move.
- Shield in the air performs an **air dodge**. Shield with left/right performs a roll, and shield with down performs a spot dodge.
- To **tech**, press shield shortly before you hit the ground while tumbling. Hold left or right to tech-roll.
- **Down tap** drops through platforms, and after your jump peaks it fast-falls.
- **DI** means holding a direction as you are launched to bend the trajectory by up to 18°.
- Pick each player's controls on the Versus screen. Gamepads show whether they're connected.

## The roster

| Fighter | Archetype | Weight | Signature (slot) |
|---|---|---|---|
| **Hayato** | Katana Specialist: fast, precise, strong neutral; spiking down-air for edge-guards; counter stance | 90 | *Iaijutsu: Quick Draw* (neutral special): hold to charge up to 2× damage, lunges further when charged |
| **Tomoe** | Naginata Wielder: longest reach, sour-spots up close | 88 | *Whirlwind Arc* (neutral special): four-part spin sweeping front-low → front → overhead → behind, ending in a launcher |
| **Kage** | Dual-Wield Ronin: fastest frame data and highest damage, weak double jump and recovery | 85 | *Thousand Cuts Rush* (side special): multi-hit dash that drags the target and ends in a launcher; helpless if used in the air |
| **Gozan** | Nodachi Wielder: heavy, slow, huge anti-air (up tilt, up smash, up air) | 118 | *Heaven-Splitting Overhead* (down special, grounded): super-armoured overhead with massive knockback. In the air it becomes *Falling Cleave*, a plunge that ends in a shockwave |

Every fighter has jab, dash attack, forward/up/down tilt, forward/up/down smash, neutral/forward/back/up/down air, and neutral/side/down specials. Each fighter also gets an up special: the brief lists three specials, but without a fourth recovery move the ledge system has nothing to recover with.

---

## Project layout

```
assets/
  characters/<id>/*.png     sprite frames cut from your sheets (transparent, feet-anchored)
  stages/dojo/              stage background (extended for camera zoom-out) + reference
  audio/sfx/*.wav           placeholder sound effects
  shaders/fighter_flash.gdshader   player outline, hit flash, mirror-match tint
data/                       ALL tuning lives here (.tres, edit in the Inspector)
  roster.tres               selectable fighters and stages
  combat_config.tres        knockback, hitlag, tech, ledge, shield and respawn constants
  audio_library.tres        audio event → stream mapping
  characters/<id>/<id>.tres           CharacterData (stats, body, move slots)
  characters/<id>/moves/<slot>.tres   one MoveData per move
  moves/                    generic get-up / ledge attacks
scenes/
  menus/  match/  stages/dojo.tscn
  fighters/fighter_base.tscn          the one fighter scene
  fighters/<id>.tscn                  per-fighter scenes inheriting the base
scripts/
  autoload/   game.gd (session, F1 toggle, navigation) · sfx.gd · match_setup.gd · audio_library.gd
  combat/     move_data.gd · hitbox_data.gd · combat_config.gd · combat_resolver.gd · hit_info.gd · projectile.gd
  combat/behaviors/   pluggable move mechanics (charge, motion, armor, counter, projectile, landing follow-up)
  fighter/    fighter.gd (controller) · character_data.gd · fighter_state.gd · fighter_overlay.gd · roster.gd
  fighter/states/     idle, walk, run, crouch, jump_squat, air, landing, attack, hitstun, knockdown,
                      dodge, shield, shield_break, ledge, helpless, rebound, dead, respawn
  input/      input_state · input_buffer · device_input · cpu_input · dummy_input · control_schemes
  match/      match.gd (game loop and rules) · fight_camera.gd · training_controller.gd
  stage/      stage.gd · ledge.gd
  ui/         main_menu · versus_setup · hud · pause_menu · results_screen · cycler · ui_style
  vfx/        slash_trail · hit_spark · ko_burst
tools/        data generator, automated tests, sprite extraction
```

## How it fits together

**One fixed-step loop.** `Match._physics_process` runs at 60 Hz and does the following in order:
1. Every fighter's `tick()`: poll input, buffer it, advance the state.
2. Projectiles.
3. `CombatResolver.resolve()`.
4. Blast-zone checks.
5. Effects.

Fighters never tick themselves. That keeps hitlag (`fighter.hitstop`), training slow-motion, game-end slow-motion and pause trivial and deterministic.

**Data, not code, makes characters.** `Fighter` reads only `CharacterData` and `MoveData`, and no file under `scripts/` knows which character is playing. Special mechanics are `MoveBehavior` resources attached to a move:

| Behaviour | Used for |
|---|---|
| `ChargeBehavior` | All smash attacks, Hayato's quick draw, Gozan's thrust |
| `MotionBehavior` | Dashes, lunges, Kage's rush, recoveries, Kage's backstep |
| `ArmorBehavior` | Gozan's overhead (super armour) and Avalanche Step (heavy armour) |
| `CounterBehavior` | Hayato's Iaido Counter → Riposte |
| `ProjectileBehavior` | Kage's Kunai Toss |
| `LandingFollowupBehavior` | Gozan's Falling Cleave → shockwave |

**Frame-driven hitboxes.** `AttackState` switches each `HitboxData` on during its frame window. `CombatResolver` then tests active hitboxes against hurtboxes with direct geometry. Compared with Area2D overlap signals this has no one-frame lag and keeps frame data exact. Lower hitbox `id` wins when several overlap, `group` controls hit-once tracking, `rehit_rate` makes multi-hits, and simultaneous hits trade. Grounded attacks whose hitboxes meet clank.

**Knockback** follows the Smash formula in `CombatConfig.compute_knockback()`. The launch is applied on the first frame after hitlag, so DI reads the stick at that moment. Launch speed, decay, hitstun-per-knockback and tumble threshold live in `combat_config.tres`. Blast zones were tuned so an average forward smash KOs at about 105% from centre stage and about 70% near the ledge.

**Animation.** `AnimatedSprite2D` frames are stepped by game frames, so they freeze in hitlag. Moves pick a pose per phase (`pose_startup`, `pose_active`, `pose_recovery`) plus an optional `pose_tilt`, which lets one drawn attack pose read as an up-air or down-air. If a SpriteFrames lacks an animation, the fighter falls back automatically (crouch → attack_startup, ledge → fall, and so on). Adding real `crouch`, `ledge` or `shield` animations later needs no code.

## Adding a fifth fighter

1. Put the frames in `assets/characters/<id>/`. Every frame of a character must share one canvas size with the feet at the same pixel. `tools/extract.py` does this from a sprite sheet.
2. Create a **SpriteFrames** with animations `idle`, `walk`, `jump`, `fall`, `hurt`, `attack_startup`, `attack_active`, `attack_recovery`.
3. Duplicate an existing `data/characters/<id>/<id>.tres`. Set identity, `sprite_frames`, `sprite_foot` (feet pixel), `sprite_scale`, stats, hurtbox, and colours.
4. Duplicate move `.tres` files into `data/characters/<id>/moves/`, edit them, and assign them to the slots.
5. Optionally duplicate `scenes/fighters/katana.tscn` and set `scene_path` if the fighter needs extra nodes, such as a 3D model in a SubViewport.
6. Add the CharacterData to `data/roster.tres` → `characters`. It appears in every menu.

## Adding or changing a move

Open the move's `.tres` and edit startup, active, recovery, landing lag, hitboxes (offset, radius or rect, frame window, damage, angle, base and growth knockback), poses and trail. Press **F1** in training to see it. If the move needs a new mechanic, write a `MoveBehavior` subclass in `scripts/combat/behaviors/` (the hooks are documented in `move_behavior.gd`) and attach it to the move's `behaviors` list. Every fighter can then use it.

## Adding a stage

Duplicate `scenes/stages/dojo.tscn`. Move the `StaticBody2D` floor, the one-way platforms (group `platform`, layer 2), the two `Ledge` markers, and the spawn and respawn markers. Set `blast_zone` and `camera_bounds` on the root, then add the scene path to `roster.tres → stages` (Match reads `Game.setup.stage_path`).

## Audio

Gameplay calls `Sfx.play(&"event")`. `data/audio_library.tres` maps each event to one or more streams, picks one at random, and applies a dB offset. Replace the placeholder `.wav` files or add streams there. A hitbox can override its hit sound with `hit_sfx`, and a move sets `swing_sfx`.

## Tools and tests

Run from the project folder with a Godot 4.3+ binary:

```bash
godot --headless --import                                      # first time only
godot --headless res://tools/check_scripts.tscn                # compile every script
godot --headless --fixed-fps 60 res://tools/mechanics_test.tscn  # 21 gameplay checks
godot --headless --fixed-fps 60 res://tools/flow_test.tscn     # menus → match → pause → training
godot --headless --fixed-fps 60 res://tools/sim_test.tscn -- 0 3 3 180 7   # CPU vs CPU set
godot --headless res://tools/build_data.tscn                   # regenerate data/ (overwrites!)
```

`mechanics_test` covers the following, and all 21 checks currently pass on Godot 4.3:
- every move of every fighter completes
- damage and knockback scaling
- high-percent KO and respawn
- ledge grab and getup
- tech and missed tech
- DI changing the angle
- buffering through landing lag
- jab chains
- charged smash damage
- platform drop-through
- each fighter recovering from off-stage

`tools/build_data.gd` is the readable source for the starter move set. Once you start tuning in the Inspector, treat the `.tres` files as the source of truth and stop re-running the generator.

## Known gaps

- **Animation coverage.** The sheets provide one attack pose set (startup / active / recovery) per fighter. Every move reuses it with tilts and procedural slash trails, so moves read differently but don't have unique animation yet.
- **Missing poses.** Ledge-hang, crouch, shield and knockdown use fallback poses. Kage has no dedicated fall frame.
- **Painted VFX.** Some active frames include the sheet's painted slash effect, which doesn't always match the move's direction.
- **Not built yet:** grabs and throws, ledge trumping, items, rollback netcode, input remapping UI.
- **CPU.** The opponent is intentionally simple: approach, poke, anti-air, shield and recover.
- **Audio.** Sounds are synthesized placeholders.
