; The update installer's hooks: it has no speech model and never touches the
; one on the PC. Run on a PC without loqui, it says to use the full installer
; and stops before changing anything. Used by tauri.update.json.

!macro LOQUI_INSTALL_MODEL
  ${IfNot} ${FileExists} "$INSTDIR\models\version.txt"
    MessageBox MB_ICONINFORMATION "This file only updates loqui. To install loqui, download the file whose name starts with loqui-setup from the same page." /SD IDOK
    SetErrorLevel 2
    Quit
  ${EndIf}
  DetailPrint "Keeping the speech model on this PC."
!macroend
