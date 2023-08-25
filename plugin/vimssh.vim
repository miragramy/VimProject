" Title:        vimssh
" Description:  A plugin to allow remote editing of files through ssh. Functionality to save credentials and paths for future use.
" Last Change:  August 2023
" Maintainer:   Mirela Gramatikova <https://github.com/miragramy>

" Prevents the plugin from being loaded multiple times. If the loaded
" variable exists, do nothing more. Otherwise, assign the loaded
" variable and continue running this instance of the plugin.
if exists("g:loaded_vimssh")
    finish
endif
let g:loaded_vimssh = 1

" Exposes the plugin's functions for use as commands in Vim.
" Call this function as such:
" :SshEdit <username>@<IP/DNS> <absolute/path/to/file>
"
" If you are on a UNIX base system, you should have ssh and sshpass installed
" and added to the $PATH variable
" If you are on Windows, you should have PuTTy installed and added to the PATH environment variable.
command! -nargs=+ SshEdit call vimssh#SshEdit(<f-args>)


" Used to save a file opened throught SshEdit
" Should be called on a buffer(tab) that's been opened through SshEdit
" othewise the call will fail.
command! -nargs=0 SshSave call vimssh#SshSave()

" Used to list and choose from the currently available aliases for this user,
" if there are any.
command! -nargs=0 SshAlias call vimssh#ListAlias()
