/// shader_high_dof_set(depthbuffer)
/// @arg depthbuffer

texture_set_stage(sampler_map[?"uDepthBuffer"], surface_get_texture(argument0))
gpu_set_texfilter_ext(sampler_map[?"uDepthBuffer"], false)

render_set_uniform_vec2("uScreenSize", render_width, render_height)

render_set_uniform("uBlurSize", app.setting_render_dof_blur_size)
render_set_uniform("uDepth", render_camera.value[e_value.CAM_DOF_DEPTH])
render_set_uniform("uRange", render_camera.value[e_value.CAM_DOF_RANGE])
render_set_uniform("uFadeSize", render_camera.value[e_value.CAM_DOF_FADE_SIZE])
render_set_uniform("uNear", cam_near)
render_set_uniform("uFar", cam_far)