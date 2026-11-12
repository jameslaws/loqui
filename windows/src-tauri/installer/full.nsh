; The full installer's hooks: it carries the speech model and copies it only
; when this PC doesn't already have this version of it, so installing over an
; older loqui doesn't copy 640 MB again. Used by tauri.full.json.
;
; models/version.nsh is written by scripts/release/build.mjs: one line,
; !define LOQUI_MODEL_VERSION "<SHA-256 of the model files>".

!define LOQUI_MODELS "${__FILEDIR__}\..\models"
!include "${LOQUI_MODELS}\version.nsh"

!macro LOQUI_INSTALL_MODEL
  Push $0
  Push $1
  StrCpy $1 ""
  ClearErrors
  FileOpen $0 "$INSTDIR\models\version.txt" r
  ${IfNot} ${Errors}
    FileRead $0 $1
    FileClose $0
  ${EndIf}
  ${If} $1 == "${LOQUI_MODEL_VERSION}"
    DetailPrint "The speech model is already on this PC."
  ${Else}
    DetailPrint "Copying the speech model (640 MB)..."
    RMDir /r "$INSTDIR\models"
    SetOutPath "$INSTDIR\models\parakeet"
    File "${LOQUI_MODELS}\parakeet\encoder.int8.onnx"
    File "${LOQUI_MODELS}\parakeet\decoder.int8.onnx"
    File "${LOQUI_MODELS}\parakeet\joiner.int8.onnx"
    File "${LOQUI_MODELS}\parakeet\tokens.txt"
    SetOutPath "$INSTDIR\models"
    File "${LOQUI_MODELS}\silero_vad.onnx"
    ; The version file last, so a copy cut short is made again next time.
    FileOpen $0 "$INSTDIR\models\version.txt" w
    FileWrite $0 "${LOQUI_MODEL_VERSION}"
    FileClose $0
  ${EndIf}
  SetOutPath "$INSTDIR"
  Pop $1
  Pop $0
!macroend
