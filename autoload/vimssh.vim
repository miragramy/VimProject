" This is a dictionary that will have a buffer num as a key and it's corresponding
" data for the ssh access as a value. The value will be a list that will have
" the following structure:
" (index)    0      1      2        3
" (value) username host password  filePath
"
" We need to keep this so we know where the save a buffer's data.
let s:sshBuffers = {}

let s:encryptionPassword = "3nc123_pa$$w0rd_" . system("whoami")

function! s:GenerateSshCommand(password, user, host)
   if has('win32') || has('win64')
      " Assume user has PuTTy installed. No checks here, we will return the message when it fails.
      let s:sshString = printf('plink %s -l %s -pw %s', a:host, a:user, a:password)
   else
      " Same as above
      let s:sshString = printf("sshpass -p '%s' ssh -q -o \"StrictHostKeyChecking=no\" %s@%s", a:password, a:user, a:host)
   endif

   return s:sshString
endfunction

function s:GenerateSaveFileName()
   " File name will be based on current user, so we don't have conflicts if
   " different users use the plugin on the same PC.
   let s:currentUser = "mirelag"
   return ".ssh_edit_" . s:currentUser
endfunction

function s:CreateAndOrReturnSaveFilePath()
   let s:saveFileDirectoryPath = expand('<sfile>:p:h')
   let s:saveFileBaseName = s:GenerateSaveFileName()

   if has('win32') || has('win64')
      let s:saveFileAbsolutePath = s:saveFileDirectoryPath . "\\" . s:saveFileBaseName
   else
      let s:saveFileAbsolutePath = s:saveFileDirectoryPath . "/" . s:saveFileBaseName
   endif

   echo s:testpath

   " if empty(expand(glob(trim(s:saveFileAbsolutePath))))
   if empty(trim(s:saveFileAbsolutePath))
      let s:result = writefile([], s:saveFileAbsolutePath)
      if s:result == -1
         return "-1"
      endif
   endif

  return s:saveFileAbsolutePath
endfunction

function! s:EncryptString(text)
   " TODO!
endfunction

function! DecryptString(encrypted_text)
   " TODO!
endfunction

function! s:WriteStringToFile(filename, text)
   " Read the file contents
   let s:fileContents = readfile(a:filename)

   " Check if the text already exists in the file
   let s:textExists = index(s:fileContents, a:text) >= 0

   " If the text doesn't exist, write it to the file
   if !s:textExists
      echo "This is not in the current file, adding it"

      " Append the password to the file
      let s:writeResult = writefile([a:text], a:filename, 'a')

      if s:writeResult == -1
         return -1
      endif
   endif

   return 1
 endfunction

function! vimssh#SshEdit(...) abort
   if a:0 != 2 && a:0 != 3
      echo 'You can call the function as follows'
      echo 'With 2 arguments, without saving: <username>@<IP/DNS> </absolute/path/to/file>'
      echo 'With 3 arguments, saving the current connection as an alias: <username>@<IP/DNS> </absolute/path/to/file> <alias_name>'
      return
   endif

   " First argument is username, second is the IP/DNS address.
   let connectionArguments = split(a:1, "@")
   if len(connectionArguments) != 2
      echo 'Malformed connection string passed. You must pass <username>@<IP/DNS>'
      return
   endif

   " inputsave() is needed, to save the state of the screen before prompting for the user input
   call inputsave()
   let password = inputsecret("Enter password: ")
   " inputrestore() is needed, to restore the state of the screen after prompting for input
   call inputrestore()

   " Clear the screen
   redraw

   let ssh = s:GenerateSshCommand(password, connectionArguments[0], connectionArguments[1])

   let fileContent = system(printf("%s 'cat \"%s\"'", ssh, a:2))

   if v:shell_error == 5
      echo "Wrong password passed"
      return
   endif

   if v:shell_error != 0
      echo "File doesn't exist or you don't have permissions to view it"
      return
   endif

   tabnew

   let currentBuffer = bufnr('%')

   call setline('.', split(fileContent, '\n')[0:-1])

   " Add to the global dictionary
   let s:sshBuffers[currentBuffer] = [connectionArguments[0], connectionArguments[1], password, a:2]

   " If we want to save an alias
   if a:0 == 3
      let s:saveFilePath = s:CreateAndOrReturnSaveFilePath()
      if s:saveFilePath == "-1"
         echo "Failed to create save file for your user"
         return
      endif
      " Format here is <alias>@<user>@<host>@<password>@<path>
      let s:saveString = printf("%s@%s@%s@%s@%s", a:3, connectionArguments[0], connectionArguments[1], password, a:2)

      let s:result = s:WriteStringToFile(s:saveFilePath, s:saveString)
      if s:result == -1
         echo "Failed to write alias to save file."
         return
      endif
   endif

   echo "Successfully opened!"
endfunction

function! vimssh#SshSave(...) abort
   if a:0 > 0
      echo "This function doesn't expect any arguments"
      return
   endif

   let currentBuffer = bufnr('%')

   if has_key(s:sshBuffers, currentBuffer)
      let sshInfo = get(s:sshBuffers, currentBuffer)
      let ssh = s:GenerateSshCommand(sshInfo[2], sshInfo[0], sshInfo[1])

      let bufferContent = join(getline(1,'$'), "\n")

      call system(printf("%s 'echo \"%s\" > %s'", ssh, bufferContent, sshInfo[3]))
      echo printf("Saved to host %s on path %s", sshInfo[1], sshInfo[3])
   else
      echo "This is not an ssh buffer"
      return
   endif
endfunction

function! vimssh#ListAlias() abort
   let s:fileName = s:CreateAndOrReturnSaveFilePath()
   let s:content = readfile(s:fileName)
   let s:inputs = []

   call add(s:inputs, "Please pick an alias to connect with:")

   let s:row = 1
   for line in s:content
      let s:tokens = split(line, "@")

      let s:name = printf("%d Name: %s, ",s:row, s:tokens[0])
      let s:user = printf("User: %s, ", s:tokens[1])
      let s:host = printf("Host: %s, ", s:tokens[2])
      let s:path = printf("File: %s", s:tokens[4])
      call add(s:inputs, s:name . s:user . s:host . s:path)
      let s:row = s:row + 1
   endfor
   let s:input = inputlist(s:inputs)

   let s:size = s:row - 1

   if s:input > 0 && s:input <= s:size
      let s:tokens = split(s:content[s:input - 1], "@")
      let s:ssh = s:GenerateSshCommand(s:tokens[3], s:tokens[1], s:tokens[2])
      let s:fileContent = system(printf("%s 'cat \"%s\"'", s:ssh, s:tokens[4]))

      if v:shell_error == 5
         echo "Wrong password passed"
         return
      endif

      if v:shell_error != 0
         echo "File doesn't exist or you don't have permissions to view it"
         return
      endif

      tabnew

      let s:currentBuffer = bufnr('%')

      call setline('.', split(s:fileContent, '\n')[0:-1])

      " Add to the global dictionary
      let s:sshBuffers[s:currentBuffer] = [s:tokens[1], s:tokens[2], s:tokens[3], s:tokens[4]]

   else
      echo "Invalid option!"
   endif

endfunction