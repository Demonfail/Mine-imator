/// render_high()
/// @desc Renders scene in high quality.

var starttime;
var ssaosurf, shadowsurf, fogsurf, finalsurf;

starttime = current_time
render_surface_time = 0

// SSAO
if (setting_render_ssao)
{
	var depthsurf, normalsurf, brightnesssurf;

	// Get depth and normal information
	render_surface[1] = surface_require(render_surface[1], render_width, render_height)
	render_surface[2] = surface_require(render_surface[2], render_width, render_height)
	render_surface[3] = surface_require(render_surface[3], render_width, render_height)
	depthsurf = render_surface[1]
	normalsurf = render_surface[2]
	brightnesssurf = render_surface[3]
	surface_set_target_ext(0, depthsurf)
	surface_set_target_ext(1, normalsurf)
	surface_set_target_ext(2, brightnesssurf)
	{
		draw_clear_alpha(c_white, 0)
		render_world_start(5000)
		render_world(e_render_mode.HIGH_SSAO_DEPTH_NORMAL)
		render_world_done()
	}
	surface_reset_target()
	
	// Noise texture
	if (!surface_exists(render_ssao_noise))
		render_ssao_noise = render_generate_noise(4, 4)
	
	// Calculate SSAO
	render_surface[0] = surface_require(render_surface[0], render_width, render_height)
	ssaosurf = render_surface[0]
	surface_set_target(ssaosurf)
	{
		gpu_set_texrepeat(false)
		draw_clear(c_white)
		render_shader_obj = shader_map[?shader_high_ssao]
		with (render_shader_obj)
		{
			shader_set(shader)
			shader_high_ssao_set(depthsurf, normalsurf, brightnesssurf)
		}
		draw_blank(0, 0, render_width, render_height) // Blank quad
		with (render_shader_obj)
			shader_clear()
		gpu_set_texrepeat(true)
	}
	surface_reset_target()
	
	// Blur
	repeat (setting_render_ssao_blur_passes)
	{
		var ssaosurftemp;
		render_surface[3] = surface_require(render_surface[3], render_width, render_height)
		ssaosurftemp = render_surface[3]
		
		render_shader_obj = shader_map[?shader_high_ssao_blur]
		with (render_shader_obj)
			shader_set(shader)
		
		// Horizontal
		surface_set_target(ssaosurftemp)
		{
			with (render_shader_obj)
				shader_high_ssao_blur_set(depthsurf, normalsurf, 1, 0)
			draw_surface_exists(ssaosurf, 0, 0)
		}
		surface_reset_target()
		
		// Vertical
		surface_set_target(ssaosurf)
		{
			with (render_shader_obj)
				shader_high_ssao_blur_set(depthsurf, normalsurf, 0, 1)
			draw_surface_exists(ssaosurftemp, 0, 0)
		}
		surface_reset_target()
		
		with (render_shader_obj)
			shader_clear()
	}
	gpu_set_texrepeat(true)
}

// Shadows
if (setting_render_shadows)
{
	var sunout = (background_sunlight_color_final != c_black);

	// Sun
	if (sunout)
	{
		// Depth
		render_surface_sun_buffer = surface_require(render_surface_sun_buffer, setting_render_shadows_sun_buffer_size, setting_render_shadows_sun_buffer_size)
		surface_set_target(render_surface_sun_buffer)
		{
			draw_clear(c_white)
			render_world_start_light(
				point3D(background_light_data[0], background_light_data[1], background_light_data[2]), 
				point3D(cam_from[X] * background_sunlight_follow, cam_from[Y] * background_sunlight_follow, 0), 
				background_light_data[3], background_light_data[7], 
				cam_fov, background_sunlight_color_final
			)
			render_world(e_render_mode.HIGH_LIGHT_SUN_DEPTH)
			render_world_done()
		}
		surface_reset_target()
		
	}
	
	// Create initial shadow surface from sun
	render_surface[1] = surface_require(render_surface[1], render_width, render_height)
	shadowsurf = render_surface[1]
	surface_set_target(shadowsurf)
	{
		draw_clear(c_white)
		render_world_start()
		render_world(test(sunout, e_render_mode.HIGH_LIGHT_SUN, e_render_mode.HIGH_LIGHT_NIGHT))
		render_world_done()
	}
	surface_reset_target()
		
	// Get number of lights (to divide brightness by)
	render_light_amount = 0
	with (obj_timeline)
		if (value_inherit[e_value.VISIBLE] && !hide && (type = e_tl_type.POINT_LIGHT || type = e_tl_type.SPOT_LIGHT))
			render_light_amount++
	
	// User placed lights
	with (obj_timeline)
	{
		var shadowsurftemp;
	
		if (!value_inherit[e_value.VISIBLE] || hide)
			continue
		
		if (type = e_tl_type.POINT_LIGHT)
		{
			// Depth
			for (var d = e_dir.EAST; d < e_dir.amount; d++)
			{
				var look = dir_get_vec3(d);
				if (d = e_dir.DOWN || d = e_dir.UP)
					look[Y] -= 0.0001
				
				render_surface_point_buffer[d] = surface_require(render_surface_point_buffer[d], app.setting_render_shadows_point_buffer_size, app.setting_render_shadows_point_buffer_size)
				surface_set_target(render_surface_point_buffer[d])
				{
					draw_clear(c_white)
					render_world_start_light(world_pos, point3D_add(world_pos, look), 1, value[e_value.LIGHT_RANGE], 90, value[e_value.LIGHT_COLOR], value[e_value.LIGHT_FADE_SIZE])
					
					// Only render depth for shadows if the light source isn't shadowless
					if (shadows)
						render_world(e_render_mode.HIGH_LIGHT_POINT_DEPTH)
						
					render_world_done()
				}
				surface_reset_target()
			}
			
			// Shadows
			with (app)
			{
				render_surface[2] = surface_require(render_surface[2], render_width, render_height)
				shadowsurftemp = render_surface[2]
				surface_set_target(shadowsurftemp)
				{
					draw_clear(c_white)
					render_world_start()
					render_world(e_render_mode.HIGH_LIGHT_POINT)
					render_world_done()
				}
				surface_reset_target()
			}
			
		}
		else if (type = e_tl_type.SPOT_LIGHT)
		{
			var lookat = point3D_mul_matrix(point3D(0.0001, 1, 0), matrix);
			
			// Depth
			render_surface_spot_buffer = surface_require(render_surface_spot_buffer, app.setting_render_shadows_spot_buffer_size, app.setting_render_shadows_spot_buffer_size)
			surface_set_target(render_surface_spot_buffer)
			{
				draw_clear(c_white)
				
				render_world_start_light(world_pos, lookat, 1, value[e_value.LIGHT_RANGE], value[e_value.LIGHT_SPOT_RADIUS], value[e_value.LIGHT_COLOR], value[e_value.LIGHT_FADE_SIZE], value[e_value.LIGHT_SPOT_SHARPNESS])
				
				// Only render depth for shadows if the light source isn't shadowless
				if (shadows)
					render_world(e_render_mode.HIGH_LIGHT_SPOT_DEPTH)
					
				render_world_done()
			}
			surface_reset_target()
			
			// Shadows
			with (app)
			{
				render_surface[2] = surface_require(render_surface[2], render_width, render_height)
				shadowsurftemp = render_surface[2]
				surface_set_target(shadowsurftemp)
				{
					draw_clear(c_white)
					render_world_start()
					render_world(e_render_mode.HIGH_LIGHT_SPOT)
					render_world_done()
				}
				surface_reset_target()
			}
		
		}
		else
			continue
			
		// Add to final shadow surface
		if (surface_exists(shadowsurf))
		{
			surface_set_target(shadowsurf)
			{
				gpu_set_blendmode(bm_add)
				draw_surface_exists(shadowsurftemp, 0, 0)
				gpu_set_blendmode(bm_normal)
			}
			surface_reset_target()
		}
		
	}
	gpu_set_texfilter(false)
}

// Fog
if (background_fog_show)
{
	render_surface[2] = surface_require(render_surface[2], render_width, render_height)
	fogsurf = render_surface[2]
	surface_set_target(fogsurf)
	{
		draw_clear(c_black)
		render_world_start()
		render_world(e_render_mode.HIGH_FOG)
		render_world_done()
	}
	surface_reset_target()
}

// At this point: 0 = SSAO, 1 = Shadows, 2 = Fog, 3 = free

// Render directly to target?
if (!render_camera_dof && !setting_render_aa && !render_overlay)
{
	render_target = surface_require(render_target, render_width, render_height)
	finalsurf = render_target
}
else
{
	render_surface[3] = surface_require(render_surface[3], render_width, render_height)
	finalsurf = render_surface[3]
}

surface_set_target(finalsurf)
{
	// Background
	draw_clear_alpha(c_black, 0)
	render_world_background()
	
	// World
	render_world_start()
	render_world_sky()
	render_world(e_render_mode.COLOR_FOG)
	render_world_done()
	
	// 2D mode
	render_set_projection_ortho(0, 0, render_width, render_height, 0)
	
	// Multiply by SSAO
	gpu_set_blendmode_ext(bm_zero, bm_src_color)
	if (setting_render_ssao)
		draw_surface_exists(ssaosurf, 0, 0)
	
	// Multiply by shadows
	if (setting_render_shadows)
	{
		render_shader_obj = shader_map[?shader_high_light_apply]
		with (render_shader_obj)
			shader_use()
		draw_surface_exists(shadowsurf, 0, 0)
		with (render_shader_obj)
			shader_clear()
	}
	gpu_set_blendmode(bm_normal)
	
	// Draw fog
	if (background_fog_show)
	{
		render_shader_obj = shader_map[?shader_high_fog_apply]
		with (render_shader_obj)
		{
			shader_set(shader)
			shader_high_fog_apply_set(fogsurf)
		}
		draw_blank(0, 0, render_width, render_height)
		with (render_shader_obj)
			shader_clear()
	}
	
	// Alpha fix
	gpu_set_blendmode_ext(bm_src_color, bm_one) 
	if (render_background)
		draw_box(0, 0, render_width, render_height, false, c_black, 1)
	else
	{
		render_world_start()
		render_world(e_render_mode.ALPHA_FIX)
		render_world_done()
	}
	gpu_set_blendmode(bm_normal)

}
surface_reset_target()

// DOF
if (render_camera_dof)
{
	var prevsurf, depthsurf;
	prevsurf = finalsurf
	
	// At this point: 0, 1, 2 = free, 3 = Final

	// Get depth
	render_surface[0] = surface_require(render_surface[0], render_width, render_height)
	depthsurf = render_surface[0]
	surface_set_target(depthsurf)
	{
		draw_clear(c_white)
		render_world_start()
		render_world(e_render_mode.HIGH_DOF_DEPTH)
		render_world_done()
	}
	surface_reset_target()
	
	// Apply DOF
	
	// Render directly to target?
	if (!setting_render_aa && !render_overlay)
	{
		render_target = surface_require(render_target, render_width, render_height)
		finalsurf = render_target
	}
	else
	{
		render_surface[1] = surface_require(render_surface[1], render_width, render_height)
		finalsurf = render_surface[1]
	}
	
	surface_set_target(finalsurf)
	{
		draw_clear_alpha(c_black, 0)
		gpu_set_texfilter(true)
		gpu_set_texrepeat(false)
		
		render_shader_obj = shader_map[?shader_high_dof]
		with (render_shader_obj)
		{
			shader_set(shader)
			shader_high_dof_set(depthsurf)
		}
		draw_surface_exists(prevsurf, 0, 0)
		with (render_shader_obj)
			shader_clear()
			
		gpu_set_texfilter(false)
		gpu_set_texrepeat(true)
	}
	surface_reset_target()
	
}

// AA
if (setting_render_aa)
{
	var prevsurf = finalsurf;

	// Render directly to target?
	if (!render_overlay)
	{
		render_target = surface_require(render_target, render_width, render_height)
		finalsurf = render_target
	}
	else
	{
		render_surface[2] = surface_require(render_surface[2], render_width, render_height)
		finalsurf = render_surface[2]
	}
	
	surface_set_target(finalsurf)
	{
		draw_clear_alpha(c_black, 0)
		
		render_shader_obj = shader_map[?shader_high_aa]
		with (render_shader_obj)
			shader_use()
		draw_surface_exists(prevsurf, 0, 0)
		with (render_shader_obj)
			shader_clear()
		
		// Alpha fix
		gpu_set_blendmode_ext(bm_src_color, bm_one) 
		if (render_background)
			draw_box(0, 0, render_width, render_height, false, c_black, 1)
		else
		{
			render_world_start()
			render_world(e_render_mode.ALPHA_TEST)
			render_world_done()
		}
		gpu_set_blendmode(bm_normal)
		
	}
	surface_reset_target()
}

// 2D overlay (camera colors/watermark)
if (render_overlay)
{
	render_target = surface_require(render_target, render_width, render_height)
	surface_set_target(render_target)
	{
		draw_clear_alpha(c_black, 0)
	
		if (render_camera_colors)
		{
			render_shader_obj = shader_map[?shader_color_camera]
			with (render_shader_obj)
				shader_use()
			draw_surface_exists(finalsurf, 0, 0)
			with (render_shader_obj)
				shader_clear()
		}
		else
			draw_surface_exists(finalsurf, 0, 0)
			
		if (render_watermark)
			render_watermark_image()
	}
	surface_reset_target()
}
	
render_time = current_time - starttime - render_surface_time
