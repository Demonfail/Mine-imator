/// ptype_update_sprite_vbuffers()
/// @desc Updates the 3D models for sprite particles.

var res = sprite_tex;
if (!res.ready)
	res = mc_res

for (var m = 0; m < sprite_vbuffer_amount; m++)
	vbuffer_destroy(sprite_vbuffer[m])

var tex, swid, shei, fwid, fhei, framesx;
tex = res.particles_texture[sprite_tex_image]
swid = texture_width(tex)
shei = texture_height(tex)
fwid = min(swid, sprite_frame_width)
fhei = min(shei, sprite_frame_height)
framesx = swid div fwid

sprite_vbuffer_amount = abs(sprite_frame_end - sprite_frame_start) + 1
for (var m = 0; m < sprite_vbuffer_amount; m++)
{
	var frame, tx1, ty1, tx2, ty2;
	frame = min(sprite_frame_start, sprite_frame_end) + m;
	tx1 = ((frame mod framesx) * fwid) / swid
	ty1 = ((frame div framesx) * fhei) / shei
	tx2 = tx1 + fwid / swid
	ty2 = ty1 + fhei / shei
	
	sprite_vbuffer[m] = vbuffer_start()
	vertex_add(-fwid / 2, 0, fhei / 2, 0, 0, 1, tx1, ty1)
	vertex_add(fwid / 2, 0, fhei / 2, 0, 0, 1, tx2, ty1)
	vertex_add(fwid / 2, 0, -fhei / 2, 0, 0, 1, tx2, ty2)
	vertex_add(-fwid / 2, 0, fhei / 2, 0, 0, 1, tx1, ty1)
	vertex_add(fwid / 2, 0, -fhei / 2, 0, 0, 1, tx2, ty2)
	vertex_add(-fwid / 2, 0, -fhei / 2, 0, 0, 1, tx1, ty2)
	vbuffer_done()
}
