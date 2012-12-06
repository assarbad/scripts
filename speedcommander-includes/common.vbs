includeExisting "consts.vbs"

' Checks whether the code fragment exists in the user's include path
Public Sub includeExisting(fSpec)
	If CreateObject("Scripting.FileSystemObject").FileExists(CreateObject("WScript.Shell").SpecialFolders("MyDocuments") & "\sc-macros\include\" & fSpec) Then
		include fSpec
	End If
End Sub

' Executes one of the UserTools defined in SC by walking through the
' list of UserTools and finding one with a command that contains the
' given substring.
' Caveat: if there are multiple UserTools containing the substring,
'         only the first will get executed.
Public Sub ExecuteUserToolFromCmdSubstr(substr)
	Dim Tool
	For Each Tool In UserTools
		If Not InStr(Tool.Command, substr) = 0 Then
			Tool.Invoke
			Exit For
		End If
	Next
End Sub

' Simply executes the given command in the given directory
Public Sub RunCommand(command, dir)
	Dim shell
	Set shell = CreateObject("WScript.Shell")
	If Not IsNull(dir) Then
		shell.CurrentDirectory = dir
	End If
	shell.Run(command)
End Sub

' Runs a given command, started in the NT script interpreter, then exits.
Public Sub RunConsoleCmd(cmd, dir)
	Const cmd_exe = "cmd.exe /e:on /c "
	Dim command
	command = cmd_exe & cmd
	RunCommand command, dir
End Sub

' Starts winmergeU.exe (assumes it's in the PATH already) to compare two given folders
Public Sub CompareFoldersWinMerge(fldr1, fldr2)
	Dim command
	command = "winmergeU.exe /r /u """ & fldr1 & """ """ & fldr2 & """"
	RunCommand command, Null
End Sub

' Common wrapper for VCS actions
Public Sub ExecVCSCmd(cmd, title, notthis)
	Dim act, dir, item
	Set act = Workspace.ActiveWindow.FolderWindows.Active
	If act.IsVisible Then
		Set item = act.Items.Item(act.FocusedItem)
		If ((item.Attributes And 16) = 16) And Not (item.FileName = notthis)  Then
			dir = item.PathName ' Full path for focused directories
		Else
			dir = item.Folder ' Parent folder for files
		End If
		RunConsoleCmd "title """ & title & ": " & dir & """ && " & cmd & " || pause", dir
	End If
End Sub

' Executes a "cvs up" on the focused item or its parent
Public Sub UpdateCvsWorkingCopy
	ExecVCSCmd cvsup_cmd, "CVS update", "CVS"
End Sub

' Executes a "cvs up" on the focused item or its parent
Public Sub PullUpdMercurial
	ExecVCSCmd hgpullu_cmd, "hg pull -u", ".hg"
End Sub

' Will focus the item after the last path separator (backslash)
' after changing into its parent folder.
' Pass Null for the second optional parameter if you don't want to set a name.
Public Sub ChangeAndFocus(pathname, tabname)
	Dim act, item, i, basepath, itemname
	Set act = Workspace.ActiveWindow.FolderWindows.Active
	If act.IsVisible Then
		i = InStrRev(pathname, "\")
		If i <> 0 Then
			basepath = Left(pathname, i - 1)
			itemname = Right(pathname, Len(pathname) - i)
			act.Folder.Folder = basepath
			act.Refresh
			If Len(itemname) > 0 Then
				On Error Resume Next
				For i = 0 To act.Items.Count
					Set item = act.Items.Item(i)
					If item.FileName = itemname Then
						act.Selection.UnSelectAll
						act.FocusedItem = i
					End If
				Next
			End If
			If Not IsNull(tabname) Then
				act.Name = tabname
			End If
		End If
	End If
End Sub
