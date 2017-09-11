/// render_world_model_part(part, texturenamemap, resource, bendangle, bendvbufferlist)
/// @arg part
/// @arg texturenamemap
/// @arg resource
/// @arg bendangle
/// @arg bendvbufferlist

var part, texnamemap, res, bendangle, bendvbufferlist, mat;
part = argument0
texnamemap = argument1
res = argument2
bendangle = argument3
bendvbufferlist = argument4
mat = matrix_get(matrix_world)

if (part.shape_list != null)
{
	var parttexname = model_get_texture_name(texnamemap, part.name);
	for (var s = 0; s < ds_list_size(part.shape_list); s++)
	{
		var shape = part.shape_list[|s];
		
		// Get texture (shape texture overrides part texture)
		var shapetexname = parttexname;
		if (shape.texture_name != part.texture_name)
			shapetexname = shape.texture_name
			
		// Set shader
		with (res)
			shader_texture = res_get_model_texture(shapetexname)
		shader_use()
		
		// Main part mesh
		matrix_set(matrix_world, matrix_multiply(shape.matrix, mat))
		vbuffer_render(shape.vbuffer)
		
		// Bended half
		if (part.bend_part != null)
		{
			// Connect mesh
			if (bendangle != 0 && bendvbufferlist != null && bendvbufferlist[|s] != null)
			{
				matrix_set(matrix_world, matrix_multiply(shape.matrix_bend, mat))
				vbuffer_render(bendvbufferlist[|s])
			}
			
			// Second half mesh
			matrix_set(matrix_world, matrix_multiply(matrix_multiply(model_part_bend_matrix(part, bendangle), shape.matrix_bend_half), mat))
			matrix_set(matrix_world, matrix_multiply(matrix_create(point3D(0, 0, 0), vec3(0), shape.scale), matrix_get(matrix_world))) // Add scale
			vbuffer_render(shape.bend_vbuffer)
		}
	}
}

matrix_set(matrix_world, mat)