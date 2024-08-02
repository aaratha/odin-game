package main

import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450
PLAYER_SPEED :: 7
PLAYER_LERP_FACTOR :: 6
TETHER_LERP_FACTOR :: 6
FRICTION :: 0.80 // Friction factor to reduce velocity
BG_COLOR :: rl.BLACK
FG_COLOR :: rl.WHITE
PLAYER_COLOR :: rl.WHITE


RopeSegment :: struct {
	pos:      rl.Vector2,
	prev_pos: rl.Vector2,
}

verlet_integrate :: proc(segment: ^RopeSegment, dt: f32) {
	temp := segment.pos
	velocity := segment.pos - segment.prev_pos
	velocity = velocity * FRICTION
	segment.pos = segment.pos + velocity
	segment.prev_pos = temp
}

constrain_segment :: proc(segment: ^RopeSegment, anchor: rl.Vector2, rest_length: f32) {
	direction := segment.pos - anchor
	distance := rl.Vector2Length(direction)
	if distance > rest_length {
		direction = direction * (rest_length / distance)
		segment.pos = anchor + direction
	}
}

main :: proc() {
	rl.SetConfigFlags(rl.ConfigFlags{.MSAA_4X_HINT})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [shapes] example - bouncing ball with rope")
	defer rl.CloseWindow()

	ball_pos := rl.Vector2{f32(rl.GetScreenWidth() / 2), f32(rl.GetScreenHeight() / 2)}
	ball_rad :: 15
	ball_color :: PLAYER_COLOR
	player_targ := rl.Vector2{f32(rl.GetScreenWidth() / 2), f32(rl.GetScreenHeight() / 2)}
	tether_pos := rl.Vector2{0, 0}

	rope_length :: 15
	anchor := rl.Vector2{f32(rl.GetScreenWidth() / 2), 50}
	rest_length := 6
	rope := make([]RopeSegment, rope_length)

	for i in 0 ..= rope_length - 1 {
		rope[i] = RopeSegment{anchor, anchor}
	}

	pause := true
	framesCounter := 0
	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
			pause = !pause
		}
		if !pause {
			direction := rl.Vector2{0, 0}
			if rl.IsKeyDown(.W) {direction.y -= 1}
			if rl.IsKeyDown(.S) {direction.y += 1}
			if rl.IsKeyDown(.D) {direction.x += 1}
			if rl.IsKeyDown(.A) {direction.x -= 1}

			if direction.x != 0 || direction.y != 0 {
				length := rl.Vector2Length(direction)
				direction = direction * (PLAYER_SPEED / length)
			}

			player_targ.x += direction.x
			player_targ.y += direction.y

			ball_pos.x += (player_targ.x - ball_pos.x) / PLAYER_LERP_FACTOR
			ball_pos.y += (player_targ.y - ball_pos.y) / PLAYER_LERP_FACTOR

			// Update rope segments
			for i in 0 ..= rope_length - 1 {
				verlet_integrate(&rope[i], 1.0 / 60.0)
			}
			rope[0].pos = ball_pos

			// Constrain rope segments
			for i in 1 ..= rope_length - 1 {
				constrain_segment(&rope[i], rope[i - 1].pos, f32(rest_length))
				constrain_segment(
					&rope[rope_length - i - 1],
					rope[rope_length - i].pos,
					f32(rest_length),
				)
			}

			// Handle mouse interaction
			mouse_pos := rl.GetMousePosition()

			// Calculate direction from ball to mouse
			to_mouse := mouse_pos - ball_pos
			distance := rl.Vector2Length(to_mouse)

			// Update the end of the rope based on mouse position
			if distance > 70 {
				rope_end := ball_pos + rl.Vector2Normalize(to_mouse) * 70
				tether_pos = rope_end
			} else {
				tether_pos = mouse_pos
			}

			rope[rope_length - 1].pos +=
				(tether_pos - rope[rope_length - 1].pos) / TETHER_LERP_FACTOR
		} else {
			framesCounter += 1
		}

		rl.BeginDrawing()
		rl.ClearBackground(BG_COLOR)
		rl.DrawCircleV(ball_pos, ball_rad, PLAYER_COLOR)
		rl.DrawText(
			"PRESS SPACE to PAUSE BALL MOVEMENT",
			10,
			rl.GetScreenHeight() - 25,
			20,
			FG_COLOR,
		)

		// Draw rope
		for i in 0 ..= rope_length - 2 {
			rl.DrawLineEx(rope[i].pos, rope[i + 1].pos, 3, PLAYER_COLOR)
			if i == rope_length - 2 {
				rl.DrawCircle(i32(rope[i].pos.x), i32(rope[i].pos.y), 10, PLAYER_COLOR)
			}
		}

		rl.DrawFPS(10, 10)

		if pause && (framesCounter / 30) % 2 != 0 {
			rl.DrawText("PAUSED", 350, 200, 30, FG_COLOR)
		}

		rl.EndDrawing()
	}
}
