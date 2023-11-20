vim.keymap.set('n', '\\r', function ()
	vim.cmd("update")
	vim.cmd("source %")
end)
