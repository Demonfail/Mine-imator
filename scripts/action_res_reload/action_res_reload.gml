/// action_res_reload()

load_folder = project_folder
save_folder = project_folder

with (res_edit)
	res_load()
	
with (obj_template)
	if (item_tex = res_edit)
		temp_update_item()

lib_preview.update = true
res_preview.update = true
res_preview.reset_view = true
