# Chibi Character System - Shaders & Animation

## Files Created

### Shaders
- `assets/shaders/chibi_toon.gdshader` - Basic toon/cel shader
- `assets/shaders/chibi_toon_advanced.gdshader` - Advanced toon shader with rim lighting
- `assets/shaders/chibi_outline.gdshader` - Outline shader (render_mode cull_front)

### Materials
- `assets/materials/chibi_material.tres` - Ready-to-use ShaderMaterial

### Scripts
- `scripts/animation_controller.gd` - State machine for animations
- `scripts/animation_setup.gd` - Generates procedural animations
- `scripts/chibi_character_controller.gd` - Player controller with animation integration
- `scripts/chibi_npc_controller.gd` - NPC controller with wandering & interaction
- `scripts/generate_ramp.py` - Python script to create ramp textures

### Scenes
- `scenes/player_enhanced.tscn` - Enhanced player with full animation system
- `scenes/npc_chibi.tscn` - NPC template

## Setup Instructions

### 1. Input Map (Project Settings > Input Map)
Add these actions:
- `move_left` (A / Left)
- `move_right` (D / Right)
- `move_forward` (W / Up)
- `move_back` (S / Down)
- `run` (Shift)
- `jump` (Space)
- `interact` (E)
- `wave` (Q)

### 2. Generate Ramp Textures
```bash
cd scripts
python3 generate_ramp.py
```
This creates:
- `assets/textures/toon_ramp.png` - Color ramp for toon shading
- `assets/textures/outline_ramp.png` - Outline thickness ramp

### 3. Use the Enhanced Player
Replace `player.tscn` with `player_enhanced.tscn` in your main scene, or instance it.

### 4. Add NPCs
Instance `npc_chibi.tscn` in your scenes. They will:
- Wander around their spawn point
- Face the player when nearby
- Wave when player enters interaction range

## Animation Controller Usage

```gdscript
# Get the controller
var anim_ctrl = $AnimationController

# Play states (uses state machine)
anim_ctrl.set_state("walk")      # Auto-blends
anim_ctrl.set_state("run")
anim_ctrl.set_state("interact")  # Auto-returns to idle
anim_ctrl.set_state("wave")      # Auto-returns to idle

# Force transition (bypass state machine)
anim_ctrl.set_state("sit", true)

# Direct animation control
anim_ctrl.play("custom_anim", 0.1, 1.5)  # blend=0.1s, speed=1.5x

# Signals
anim_ctrl.animation_finished.connect(_on_anim_finished)
anim_ctrl.animation_started.connect(_on_anim_started)
```

## Shader Parameters

### chibi_toon_advanced
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| base_color | Color | skin tone | Base albedo |
| shadow_color | Color | darker skin | Shadow color |
| outline_color | Color | dark | Outline color (unused here) |
| rim_color | Color | warm white | Rim light color |
| shadow_threshold | float | 0.5 | Shadow cutoff |
| shadow_softness | float | 0.15 | Shadow transition |
| outline_width | float | 0.035 | Vertex offset for outline |
| rim_power | float | 3.0 | Rim falloff sharpness |
| rim_intensity | float | 0.4 | Rim strength |
| use_ramp | bool | false | Use texture ramp |
| ramp_texture | Texture2D | - | 1D ramp texture |

### chibi_outline
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| outline_width | float | 0.05 | Base outline thickness |
| outline_color | Color | dark | Outline color |
| use_normal_offset | bool | true | Offset along normal vs view dir |

## Creating Custom Animations

### Option 1: Godot Animation Editor
1. Open `AnimationPlayer` in the scene
2. Create new animation
3. Keyframe transforms on `Body` or child bones

### Option 2: Procedural (Code)
```gdscript
var controller = AnimationController.new()
var custom_anim = controller.create_procedural_walk(1.2, 1.2)
$AnimationPlayer.add_animation("custom_walk", custom_anim)
```

### Option 3: Import from Blender
1. Export as glTF with animations
2. Import in Godot
3. Animations appear in `AnimationPlayer` automatically

## Architecture

```
Player (CharacterBody3D)
├── AnimationController (Node) - State machine
├── AnimationSetup (Node) - Creates procedural anims
├── AnimationPlayer - Plays animations
├── CameraPivot (Node3D) - Camera follow target
│   └── Camera3D
├── Body (MeshInstance3D) - Chibi mesh + material
└── CollisionShape3D
```

## Performance Notes
- Shaders use `unshaded` render mode - no lighting calculations
- Outline uses separate mesh with `cull_front` - ~2x vertex cost
- Procedural animations are lightweight (transform only)
- For skinned meshes, use `Skeleton3D` + `AnimationTree` instead

## Extending
- Add new states to `_state_machine` in `animation_controller.gd`
- Add entries to `_animation_map` and `_blend_times`
- Create new procedural animations in `AnimationController`
- Modify shaders for different art styles (anime, pixel, etc.)