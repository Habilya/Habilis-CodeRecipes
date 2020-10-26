' For this to work, you need to activate this in security options...
' check mark Trust access to the VBA project object model

Private Sub Workbook_ExportAllModules()
    Dim wb As Workbook
    Dim wbpath As String
    Dim VBComp As Variant

    wbpath = "C:\VBAProjectCompare\NEW\\"

    For Each VBComp In ActiveWorkbook.VBProject.VBComponents
        If VBComp.Type = 1 Then
            On Error Resume Next
            Err.Clear
            VBComp.Export wbpath & VBComp.Name & ".vb"
        End If
    Next
End Sub