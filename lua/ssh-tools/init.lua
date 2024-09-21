local M = {}

local api = vim.api
local projects = {}

local remove_prefix = function(str, prefix)
	return str:sub(1, #prefix) == prefix and str:sub(#prefix + 1) or str
end

local get_remote_file_path = function(local_file_path, project)
	local local_rel_path = remove_prefix(local_file_path, project.local_path)
	return vim.fs.joinpath(project.remote_path, local_rel_path)
end

-- Downloads the file from the remote server and saves it to the local path
local download_file = function(remote_file_path, local_file_path, project)
	vim.system({ "scp", project.name .. ":" .. remote_file_path, local_file_path }, {}, function(obj)
		if obj.code ~= 0 then
			print("Failed to download file: " .. remote_file_path)
		else
			-- Reload the buffer
			vim.schedule(function()
				vim.cmd("edit " .. local_file_path)
			end)
		end
	end)
end

-- Uploads the file to the remote server
local upload_file = function(local_file_path, remote_file_path, project)
	local remote_path = project.name .. ":" .. remote_file_path
	vim.system({ "scp", local_file_path, remote_path }, {}, function(obj)
		if obj.code ~= 0 then
			print("Failed to upload file to " .. remote_path)
		else
			print("Uploaded file to " .. remote_path)
		end
	end)
end

local get_project = function(file_path)
	for _, project in ipairs(projects) do
		if vim.startswith(file_path, project.local_path) then
			return project
		end
	end
	return nil
end

local setup_autocmds = function()
	api.nvim_create_user_command("SshDownload", function()
		local local_file_path = api.nvim_buf_get_name(0)
		local project = get_project(local_file_path)
		if not project then
			print("No project found for file: " .. local_file_path)
			return
		end
		local remote_file_path = get_remote_file_path(local_file_path, project)
		download_file(remote_file_path, local_file_path, project)
	end, {})

	api.nvim_create_user_command("SshUpload", function()
		local local_file_path = api.nvim_buf_get_name(0)
		local project = get_project(local_file_path)
		if not project then
			print("No project found for file: " .. local_file_path)
			return
		end
		local remote_file_path = get_remote_file_path(local_file_path, project)
		upload_file(local_file_path, remote_file_path, project)
	end, {})
end

M.setup = function(config)
	for name, project in pairs(config.projects) do
		project.name = name
		project.local_path = vim.fs.normalize(project.local_path, {})
		project.remote_path = vim.fs.normalize(project.remote_path, {})
		table.insert(projects, project)
	end
	setup_autocmds()
end

return M
