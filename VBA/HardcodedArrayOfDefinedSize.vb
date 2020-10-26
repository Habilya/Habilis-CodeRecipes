' Working with "hardcoded" array of defined size

Const STR_MONTH_LIST_NAME = "January|February|March|April|May|June|July|August|September|October|November|December"

Public Function GetMonthsArray() As String()
    GetMonthsArray = Split(STR_MONTH_LIST_NAME, "|")
End Function

Public Function GetMonthName(iMonth As Integer) As String

      GetMonthName = ""

      If iMonth >= 1 And iMonth <= 12 Then
         GetMonthName = GetMonthsArray()(iMonth - 1)
      End If

End Function

Public Function GetMonthIndex(sMonth As String) As Integer

   Dim vaMonthArray() As String
   Dim i As Integer

   GetMonthIndex = 0

   vaMonthArray() = Split(STR_MONTH_LIST_NAME, "|")

   For i = LBound(vaMonthArray) To UBound(vaMonthArray)

      If StrComp(vaMonthArray(i), sMonth) = 0 Then
         GetMonthIndex = i + 1
         Exit Function
      End If

   Next

End Function