package main

import "core:fmt"
import math "core:math/linalg"
import rl "vendor:raylib"


SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450
PLAYER_SPEED :: 7
PLAYER_LERP_FACTOR :: 6
TETHER_LERP_FACTOR :: 6
FRICTION :: 0.7
BG_COLOR :: rl.BLACK
FG_COLOR :: rl.WHITE
PLAYER_COLOR :: rl.WHITE
PLAYER_RADIUS :: 12
ROPE_LENGTH :: 15
REST_LENGTH :: 1
EXTENDED_REST_LENGTH :: 15
ROPE_MAX_DIST :: 70
EXTENDED_ROPE_MAX_DIST :: 300
ENEMY_RADIUS :: 10
ENEMY_COLOR :: rl.RED
ENEMY_SPEED :: 0.5
TETHER_RADIUS :: 10
mat :: distinct matrix[2, 2]f32

PhysicsObject :: struct {
	pos:      rl.Vector2,
	prev_pos: rl.Vector2,
}


verlet_integrate :: proc(segment: ^PhysicsObject, dt: f32) {
	temp := segment.pos
	velocity := segment.pos - segment.prev_pos
	velocity = velocity * FRICTION
	segment.pos = segment.pos + velocity
	segment.prev_pos = temp
}

constrain_rope :: proc(rope: []PhysicsObject, rest_length: f32) {
	for i in 1 ..= len(rope) - 2 {
		vec2prev := rope[i].pos - rope[i - 1].pos
		vec2next := rope[i + 1].pos - rope[i].pos
		dist2prev := rl.Vector2Length(vec2prev)
		dist2next := rl.Vector2Length(vec2next)
		if dist2prev > rest_length {
			vec2prev = rl.Vector2Normalize(vec2prev) * rest_length
		}
		if dist2next > rest_length {
			vec2next = rl.Vector2Normalize(vec2next) * rest_length
		}
		rope[i].pos = (rope[i - 1].pos + vec2prev + rope[i + 1].pos - vec2next) / 2
	}
}

initialize_rope :: proc(rope: []PhysicsObject, length: int, anchor: rl.Vector2) {
	for i in 0 ..= length - 1 {
		rope[i] = PhysicsObject{anchor, anchor}
	}
}

update_rope :: proc(rope: []PhysicsObject, ball_pos: rl.Vector2, rest_length: f32) {
	for i in 0 ..= len(rope) - 1 {
		verlet_integrate(&rope[i], 1.0 / 60.0)
	}
	rope[0].pos = ball_pos
	constrain_rope(rope, rest_length)
}

handle_input :: proc(
	player_targ: ^rl.Vector2,
	isClicking: ^bool,
	enemies: ^[dynamic]PhysicsObject,
) {
	direction := rl.Vector2{0, 0}
	if rl.IsKeyDown(.W) {direction.y -= 1}
	if rl.IsKeyDown(.S) {direction.y += 1}
	if rl.IsKeyDown(.D) {direction.x += 1}
	if rl.IsKeyDown(.A) {direction.x -= 1}
	if rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
		isClicking^ = true
	} else {
		isClicking^ = false
	}
	if rl.IsMouseButtonPressed(rl.MouseButton.RIGHT) {
		spawn_enemy(rl.GetMousePosition(), enemies)
	}

	if direction.x != 0 || direction.y != 0 {
		length := rl.Vector2Length(direction)
		direction = direction * (PLAYER_SPEED / length)
	}

	player_targ.x += direction.x
	player_targ.y += direction.y
}

update_ball_position :: proc(ball_pos, player_targ: ^rl.Vector2) {
	ball_pos.x += (player_targ.x - ball_pos.x) / PLAYER_LERP_FACTOR
	ball_pos.y += (player_targ.y - ball_pos.y) / PLAYER_LERP_FACTOR
}

update_tether_position :: proc(
	ball_pos, tether_pos: ^rl.Vector2,
	isClicking: ^bool,
	max_dist: int,
) {
	mouse_pos := rl.GetMousePosition()
	to_mouse := mouse_pos - ball_pos^
	distance := rl.Vector2Length(to_mouse)

	if distance > f32(max_dist) {
		rope_end := ball_pos^ + rl.Vector2Normalize(to_mouse) * f32(max_dist)
		tether_pos^ = rope_end
	} else {
		tether_pos^ = mouse_pos
	}
}

spawn_enemy :: proc(spawn_pos: rl.Vector2, enemies: ^[dynamic]PhysicsObject) {
	append(enemies, PhysicsObject{pos = spawn_pos, prev_pos = spawn_pos})
}

update_enemies :: proc(enemies: ^[dynamic]PhysicsObject, player_pos: rl.Vector2) {
	for &enemy in enemies {
		// Calculate direction towards the player
		direction := rl.Vector2Normalize(player_pos - enemy.pos)
		enemy.pos += direction * ENEMY_SPEED // Adjust speed as necessary
		verlet_integrate(&enemy, 1.0 / 60.0)
	}
}

solve_collisions :: proc(
	ball_pos: ^rl.Vector2,
	ball_rad: int,
	rope: []PhysicsObject,
	tether_rad: int,
	enemies: ^[dynamic]PhysicsObject,
	enemy_rad: int,
) {
	// Ball vs Enemies
	for i := 0; i < len(enemies); i += 1 {
		dir := ball_pos^ - enemies[i].pos
		distance := rl.Vector2Length(dir)
		min_dist := f32(ball_rad + enemy_rad)
		if distance < min_dist {
			normal := rl.Vector2Normalize(dir)
			depth := min_dist - distance
			ball_pos^ = ball_pos^ + (normal * depth * 0.5)
			enemies[i].pos = enemies[i].pos - (normal * depth * 0.5)
		}
	}

	// Rope segments vs Enemies
	for i := 0; i < len(rope); i += 1 {
		for j := 0; j < len(enemies); j += 1 {
			dir := rope[i].pos - enemies[j].pos
			distance := rl.Vector2Length(dir)
			min_dist := f32(tether_rad + enemy_rad)

			if distance < min_dist {
				normal := rl.Vector2Normalize(dir)
				depth := min_dist - distance
				rope[i].pos = rope[i].pos + (normal * depth * 0.5)
				enemies[j].pos = enemies[j].pos - (normal * depth * 0.5)

			}
		}
	}

	// Enemies vs Enemies
	for i := 0; i < len(enemies) - 1; i += 1 {
		for j := i + 1; j < len(enemies); j += 1 {
			dir := enemies[i].pos - enemies[j].pos
			distance := rl.Vector2Length(dir)
			min_dist := f32(enemy_rad * 2)

			if distance < min_dist {
				normal := rl.Vector2Normalize(dir)
				depth := min_dist - distance
				enemies[i].pos = enemies[i].pos + (normal * depth * 0.5)
				enemies[j].pos = enemies[j].pos - (normal * depth * 0.5)
			}
		}
	}
}

// Helper function to check if two line segments intersect
line_intersect :: proc(p1, p2, p3, p4: rl.Vector2, EPSILON: f32) -> bool {
	d := (p1.x - p2.x) * (p3.y - p4.y) - (p1.y - p2.y) * (p3.x - p4.x)
	if math.abs(d) < EPSILON {
		return false // Lines are parallel or coincident
	}
	t := ((p1.x - p3.x) * (p3.y - p4.y) - (p1.y - p3.y) * (p3.x - p4.x)) / d
	u := -((p1.x - p2.x) * (p1.y - p3.y) - (p1.y - p2.y) * (p1.x - p3.x)) / d
	if t > EPSILON && t < 1 - EPSILON && u > EPSILON && u < 1 - EPSILON {
		return true // Intersection found
	}
	return false
}

isClosed :: proc(rope: []PhysicsObject) -> bool {
	EPSILON :: 1e-5
	ENDPOINT_OFFSET :: 0.01
	for i in 0 ..< len(rope) {
		for j in i + 2 ..< len(rope) - 1 {
			if j == len(rope) - 1 && i == 0 {
				continue // Skip checking the first and last segments
			}
			p1 := rope[i].pos
			p2 := rope[i + 1].pos
			p3 := rope[j].pos
			p4 := rope[j + 1].pos
			// Adjust endpoints slightly inward
			dir12 := rl.Vector2Normalize(p2 - p1)
			dir34 := rl.Vector2Normalize(p4 - p3)
			p1 = p1 + dir12 * ENDPOINT_OFFSET
			p2 = p2 - dir12 * ENDPOINT_OFFSET
			p3 = p3 + dir34 * ENDPOINT_OFFSET
			p4 = p4 - dir34 * ENDPOINT_OFFSET
			if line_intersect(p1, p2, p3, p4, EPSILON) {
				return true // Intersection found, rope is closed
			}
		}
	}
	return false // No intersection found, rope is open
}

// kill_interior(rope, enemies: []PhysicsObject) {
// 	for i in 0 ..< len(rope) {
// 		for j in i + 2 ..< len(rope) - 1 {
// 			if j == len(rope) - 1 && i == 0 {
// 				continue // Skip checking the first and last segments
// 			}
// 			ray := 
// 		}
// 	}
// }

draw_scene :: proc(
	ball_pos: rl.Vector2,
	ball_rad: f32,
	rope: []PhysicsObject,
	rope_length: int,
	pause: bool,
	framesCounter: int,
	enemies: [dynamic]PhysicsObject,
) {
	rl.BeginDrawing()
	rl.ClearBackground(BG_COLOR)
	rl.DrawCircleV(ball_pos, ball_rad, PLAYER_COLOR)
	rl.DrawText("PRESS SPACE to PAUSE BALL MOVEMENT", 10, rl.GetScreenHeight() - 25, 20, FG_COLOR)

	for i in 0 ..= rope_length - 2 {
		rl.DrawLineEx(rope[i].pos, rope[i + 1].pos, 3, PLAYER_COLOR)
		if i == rope_length - 2 {
			rl.DrawCircle(
				i32(rope[i + 1].pos.x),
				i32(rope[i + 1].pos.y),
				TETHER_RADIUS,
				PLAYER_COLOR,
			)
		}
	}

	for enemy in enemies {
		rl.DrawCircle(i32(enemy.pos.x), i32(enemy.pos.y), ENEMY_RADIUS, ENEMY_COLOR)
	}

	rl.DrawFPS(10, 10)

	if pause && (framesCounter / 30) % 2 != 0 {
		rl.DrawText("PAUSED", 350, 200, 30, FG_COLOR)
	}

	rl.EndDrawing()
}

main :: proc() {
	rl.SetConfigFlags(rl.ConfigFlags{.MSAA_4X_HINT})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "ball and chain")
	defer rl.CloseWindow()

	ball_pos := rl.Vector2{f32(rl.GetScreenWidth() / 2), f32(rl.GetScreenHeight() / 2)}
	ball_rad := f32(PLAYER_RADIUS)
	player_targ := rl.Vector2{f32(rl.GetScreenWidth() / 2), f32(rl.GetScreenHeight() / 2)}
	tether_pos := rl.Vector2{}
	isClicking := false
	max_dist := ROPE_MAX_DIST

	rope_length :: ROPE_LENGTH

	anchor := rl.Vector2{f32(rl.GetScreenWidth() / 2), 50}
	rest_length := REST_LENGTH
	rope := make([]PhysicsObject, rope_length)
	initialize_rope(rope, rope_length, anchor)

	enemies := make([dynamic]PhysicsObject, 0)

	pause := true
	framesCounter := 0
	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
			pause = !pause
		}
		if !pause {
			if isClicking {
				rest_length = EXTENDED_REST_LENGTH
				max_dist = EXTENDED_ROPE_MAX_DIST
			} else {
				rest_length = REST_LENGTH
				max_dist = ROPE_MAX_DIST
			}
			handle_input(&player_targ, &isClicking, &enemies)
			update_ball_position(&ball_pos, &player_targ)
			update_rope(rope, ball_pos, f32(rest_length))
			update_tether_position(&ball_pos, &tether_pos, &isClicking, max_dist)
			update_enemies(&enemies, ball_pos) // Update enemies to move towards the player
			solve_collisions(&ball_pos, PLAYER_RADIUS, rope, TETHER_RADIUS, &enemies, ENEMY_RADIUS)
			fmt.println(isClosed(rope))
			rope[rope_length - 1].pos +=
				(tether_pos - rope[rope_length - 1].pos) / TETHER_LERP_FACTOR
		} else {
			framesCounter += 1
		}

		draw_scene(ball_pos, ball_rad, rope, rope_length, pause, framesCounter, enemies)
	}
}
