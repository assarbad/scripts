==============================================
 Some code snippets for SpeedCommander macros
==============================================

In order to use the "includes" from this folder, make sure that this folder
here is linked into place under "My Documents" as ".\sc-macros\include" and
then start your actual macro with the snippet reproduced at the bottom. For
this purpose I prefer to use junction points (similar to symbolic links to
directories) which can be created with junction.exe from Sysinternals or with
SpeedCommander itself.

The two comments are already provided by SpeedCommander and cannot be removed,
so you can leave them out when copy+pasting the above ;)

NOTE: the common.vbs doesn't require it, but if you store a consts.vbs in the
same folder as the common.vbs, it'll be loaded. The points is that you could
provide constant values there to be used throughout your SpeedCommander macros.

LICENSE: the code is placed in the PUBLIC DOMAIN/CC0

==================================================
 Ein paar Codeschnipsel für SpeedCommander-Makros
==================================================

Um die Dateien aus diesem Verzeichnis in SpeedCommander-Makros zu benutzen
sollte sichergestellt werden, daß das Verzeichnis unter "Eigene Dateien" als
Unterverzeichnis ".\sc-macros\include" eingebunden ist. Ich benutze dazu sog.
Junction-Points (symbolische Verzeichnislinks), welche man mit junction.exe
von Sysinternals oder dem SpeedCommander erstellen kann. Danach gilt es nur
noch jedes deiner Makros mit dem am Ende dieses Textes stehenden Codeschnipsel
zu beginnen.

Die beiden auskommentierten Zeilen fügt der SpeedCommander automatisch in
jedes Makro ein und sie können auch nicht entfernt werden. Aber du kannst sie
weglassen wenn du den Schnipsel unten heraus- und in dein Makro hineinkopierst.

HINWEIS: die common.vbs benötigt sie nicht, aber wenn du eine consts.vbs im
selben Verzeichnis speicherst, wird sie durch common.vbs geladen. Der Sinn ist
es konstante Werte zentral für alle SpeedCommander-Makros bereitzustellen.

LIZENZ: der Code ist gemeinfrei, bzw. hilfsweise unter CC0-Lizenz.

------------------------------------------------------------------------------
'Begin of (Declarations)
Option Explicit
Private Sub include(fSpec) ExecuteGlobal CreateObject("Scripting.FileSystemObject").OpenTextFile(CreateObject("WScript.Shell").SpecialFolders("MyDocuments") & "\sc-macros\include\" & fSpec).ReadAll() End Sub
include "common.vbs"

'End of (Declarations)
