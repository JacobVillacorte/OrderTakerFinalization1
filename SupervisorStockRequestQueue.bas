B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Activity
Version=13.4
@EndOfDesignText@
#Region  Activity Attributes
	#FullScreen: False
	#IncludeTitle: False
#End Region

Sub Process_Globals
End Sub

Sub Globals
	Private pnlSupervisorStockRequestQueue As Panel
	Private lblBack As Label
	Private lblTitle As Label
	Private lblRefresh As Label
	Private lblStatus As Label
	Private pnlRequestFilters As Panel
	Private etRequestSearch As EditText
	Private btnAcceptAll As Button
	Private btnRejectAll As Button
	Private clvRequests As CustomListView
	Private currentLoadJob As HttpJob
	Private requestRows As List
	Private filteredRequestRows As List
	Private requestById As Map
	Private isLoadingRequests As Boolean
	Private bulkReviewRows As List
	Private bulkReviewAction As String
	Private bulkReviewIndex As Int
	Private bulkReviewSuccessCount As Int
	Private bulkReviewFailCount As Int
	Private bulkReviewInProgress As Boolean
End Sub

Sub Activity_Create(FirstTime As Boolean)
	Activity.Color = Colors.RGB(245, 247, 250)
	If Main.LoggedInUserID <= 0 Then
		Activity.Finish
		Return
	End If
	currentLoadJob = Null
	isLoadingRequests = False
	requestRows.Initialize
	filteredRequestRows.Initialize
	requestById.Initialize
	Activity.LoadLayout("SupervisorStockRequestQueue")
	If lblTitle.IsInitialized Then lblTitle.Text = "Stock Requests"
	If lblStatus.IsInitialized Then lblStatus.Text = "Loading pending requests..."
	SetupRequestFilterBar
	LoadPendingRequests
End Sub

Sub Activity_Resume
	If Main.LoggedInUserID <= 0 Then
		Activity.Finish
		Return
	End If
	If isLoadingRequests Then Return
	If requestRows.IsInitialized = False Or requestRows.Size = 0 Then
		LoadPendingRequests
	Else
		ApplyRequestFilters
	End If
End Sub

Sub Activity_Pause(UserClosed As Boolean)
	If currentLoadJob <> Null Then
		Try
			If currentLoadJob.IsInitialized Then currentLoadJob.Release
		Catch
			Log(LastException.Message)
		End Try
		currentLoadJob = Null
	End If
End Sub

Private Sub LoadPendingRequests
	If isLoadingRequests Then Return

	Log("LoadPendingRequests: start, convention_id=" & Main.LoggedInConventionID)

	If Main.LoggedInConventionID <= 0 Then
		lblStatus.Text = "Missing convention context."
		ToastMessageShow("Missing convention context.", True)
		ShowEmptyMessage("Missing convention context.")
		Return
	End If

	isLoadingRequests = True
	lblStatus.Text = "Loading pending requests..."
	clvRequests.Clear
	requestRows.Initialize
	requestById.Initialize

	Dim job As HttpJob
	job.Initialize("load_stock_requests", Me)
	currentLoadJob = job
	Dim url As String = Main.API_URL & "API/get_stock_requests.php?convention_id=" & Main.LoggedInConventionID & _
		"&status=pending&limit=200"
	Log("LoadPendingRequests: GET " & url)
	job.Download(url)

	Wait For (job) JobDone(jobLoad As HttpJob)
	If jobLoad.Success = False Then
		lblStatus.Text = "Unable to load stock requests."
		ToastMessageShow("Unable to load stock requests.", True)
		ShowEmptyMessage("Unable to load stock requests.")
		jobLoad.Release
		currentLoadJob = Null
		isLoadingRequests = False
		Return
	End If

	Try
		Dim parser As JSONParser
		parser.Initialize(jobLoad.GetString)
		Dim root As Map = parser.NextObject
		If root.Get("status") <> "success" Then
			lblStatus.Text = GetStringValue(root, "message")
			ToastMessageShow(lblStatus.Text, True)
			jobLoad.Release
			currentLoadJob = Null
			isLoadingRequests = False
			Return
		End If

		Dim data As List = root.Get("data")
		For Each row As Map In data
			requestRows.Add(row)
			requestById.Put(GetIntValue(row, "request_id"), row)
		Next
		ApplyRequestFilters
	Catch
		lblStatus.Text = "Invalid requests response."
		ToastMessageShow("Invalid requests response.", True)
		ShowEmptyMessage("Invalid requests response.")
	End Try

	jobLoad.Release
	currentLoadJob = Null
	isLoadingRequests = False
End Sub

Private Sub SetupRequestFilterBar
	If pnlRequestFilters.IsInitialized = False Then Return
	If etRequestSearch.IsInitialized = False Then Return
	If btnAcceptAll.IsInitialized = False Then Return
	If btnRejectAll.IsInitialized = False Then Return
End Sub

Private Sub etRequestSearch_TextChanged (Old As String, New As String)
	ApplyRequestFilters
End Sub

Private Sub btnAcceptAll_Click
	StartBulkRequestReview("approved")
End Sub

Private Sub btnRejectAll_Click
	StartBulkRequestReview("rejected")
End Sub

Private Sub ApplyRequestFilters
	filteredRequestRows.Initialize

	Dim searchText As String = ""
	If etRequestSearch.IsInitialized Then searchText = etRequestSearch.Text.Trim.ToLowerCase

	For Each row As Map In requestRows
		If RequestMatchesFilter(row, searchText) Then
			filteredRequestRows.Add(row)
		End If
	Next

	RenderRequests
End Sub

Private Sub RequestMatchesFilter(row As Map, searchText As String) As Boolean
	If searchText = "" Then Return True

	Dim haystack As String = _
		GetStringValue(row, "requester_name") & " " & _
		GetStringValue(row, "item_name") & " " & _
		GetStringValue(row, "device_id") & " " & _
		GetIntValue(row, "request_id")
	Return haystack.ToLowerCase.Contains(searchText)
End Sub

Private Sub RenderRequests
	clvRequests.Clear

	For Each row As Map In filteredRequestRows
		Dim requestId As Int = GetIntValue(row, "request_id")
		clvRequests.Add(CreateRequestRow(row), requestId)
	Next

	If filteredRequestRows.Size = 0 Then
		ShowEmptyMessage("No pending requests found.")
	Else
		lblStatus.Text = filteredRequestRows.Size & " pending request(s) loaded"
	End If
End Sub

Private Sub CreateRequestRow(row As Map) As Panel
	Dim requestId As Int = GetIntValue(row, "request_id")
	Dim requesterName As String = GetStringValue(row, "requester_name")
	Dim itemName As String = GetStringValue(row, "item_name")
	Dim requestedQty As Int = GetIntValue(row, "requested_qty")
	Dim deviceId As String = GetStringValue(row, "device_id")
	Dim createdAt As String = GetStringValue(row, "created_at")

	Dim pnl As Panel
	pnl.Initialize("")
	pnl.Color = Colors.White
	pnl.SetLayout(0, 0, clvRequests.AsView.Width, 136dip)

	Dim lblTitleRow As Label
	lblTitleRow.Initialize("")
	lblTitleRow.Text = itemName
	lblTitleRow.TextSize = 16
	lblTitleRow.Typeface = Typeface.DEFAULT_BOLD
	lblTitleRow.TextColor = Colors.Black
	pnl.AddView(lblTitleRow, 12dip, 8dip, clvRequests.AsView.Width - 152dip, 22dip)

	Dim lblRequester As Label
	lblRequester.Initialize("")
	lblRequester.Text = "Requested by: " & requesterName
	lblRequester.TextSize = 12
	lblRequester.TextColor = Colors.Gray
	pnl.AddView(lblRequester, 12dip, 32dip, clvRequests.AsView.Width - 152dip, 18dip)

	Dim lblMeta As Label
	lblMeta.Initialize("")
	lblMeta.Text = "Qty: " & requestedQty & "  |  Device: " & deviceId
	lblMeta.TextSize = 12
	lblMeta.TextColor = Colors.RGB(75, 95, 125)
	pnl.AddView(lblMeta, 12dip, 52dip, clvRequests.AsView.Width - 152dip, 18dip)

	Dim lblCreated As Label
	lblCreated.Initialize("")
	lblCreated.Text = createdAt
	lblCreated.TextSize = 11
	lblCreated.TextColor = Colors.RGB(120, 120, 120)
	pnl.AddView(lblCreated, 12dip, 72dip, clvRequests.AsView.Width - 152dip, 16dip)

	Dim btnApprove As Button
	btnApprove.Initialize("btnApprove")
	btnApprove.Text = "Approve"
	btnApprove.Tag = requestId
	btnApprove.TextColor = Colors.White
	btnApprove.TextSize = 11
	btnApprove.Gravity = Gravity.CENTER
	btnApprove.Color = Colors.RGB(46, 125, 50)
	pnl.AddView(btnApprove, clvRequests.AsView.Width - 116dip, 14dip, 104dip, 34dip)

	Dim btnReject As Button
	btnReject.Initialize("btnReject")
	btnReject.Text = "Reject"
	btnReject.Tag = requestId
	btnReject.TextColor = Colors.White
	btnReject.TextSize = 11
	btnReject.Gravity = Gravity.CENTER
	btnReject.Color = Colors.RGB(198, 40, 40)
	pnl.AddView(btnReject, clvRequests.AsView.Width - 116dip, 58dip, 104dip, 34dip)

	Dim pnlSep As Panel
	pnlSep.Initialize("")
	pnlSep.Color = Colors.RGB(235, 235, 235)
	pnl.AddView(pnlSep, 12dip, 132dip, clvRequests.AsView.Width - 24dip, 1dip)

	Return pnl
End Sub

Private Sub btnApprove_Click
	HandleReviewAction(Sender, "approved")
End Sub

Private Sub btnReject_Click
	HandleReviewAction(Sender, "rejected")
End Sub

Private Sub HandleReviewAction(senderObject As Object, actionStatus As String)
	Dim btn As Button = senderObject
	If btn.Tag = Null Then Return
	Dim requestId As Int = btn.Tag
	Dim row As Map = GetRequestRow(requestId)
	If row.IsInitialized = False Or row.Size = 0 Then Return

	Dim itemName As String = GetStringValue(row, "item_name")
	Dim requesterName As String = GetStringValue(row, "requester_name")
	Dim prompt As String = "Mark this request as " & actionStatus & "?" & CRLF & _
		itemName & CRLF & requesterName
	Msgbox2Async(prompt, "Confirm Review", "Yes", "", "No", Null, False)
	Wait For Msgbox_Result (Result As Int)
	If Result <> DialogResponse.POSITIVE Then Return

	RespondToRequest(requestId, actionStatus, GetIntValue(row, "requested_qty"), False)
End Sub

Private Sub StartBulkRequestReview(actionStatus As String)
	If filteredRequestRows.IsInitialized = False Or filteredRequestRows.Size = 0 Then
		ToastMessageShow("No requests to process.", False)
		Return
	End If

	Dim prompt As String = "Apply " & actionStatus & " to " & filteredRequestRows.Size & " request(s)?"
	Msgbox2Async(prompt, "Confirm Bulk Review", "Yes", "", "No", Null, False)
	Wait For Msgbox_Result (Result As Int)
	If Result <> DialogResponse.POSITIVE Then Return

	bulkReviewRows.Initialize
	For Each row As Map In filteredRequestRows
		bulkReviewRows.Add(row)
	Next
	bulkReviewAction = actionStatus
	bulkReviewIndex = 0
	bulkReviewSuccessCount = 0
	bulkReviewFailCount = 0
	bulkReviewInProgress = True
	ProcessNextBulkRequestReview
End Sub

Private Sub ProcessNextBulkRequestReview
	If bulkReviewInProgress = False Then Return

	If bulkReviewIndex >= bulkReviewRows.Size Then
		bulkReviewInProgress = False
		ToastMessageShow("Bulk review finished. Success: " & bulkReviewSuccessCount & ", Failed: " & bulkReviewFailCount, False)
		LoadPendingRequests
		Return
	End If

	Dim row As Map = bulkReviewRows.Get(bulkReviewIndex)
	bulkReviewIndex = bulkReviewIndex + 1
	RespondToRequest(GetIntValue(row, "request_id"), bulkReviewAction, GetIntValue(row, "requested_qty"), True)
End Sub

Private Sub RespondToRequest(requestId As Int, actionStatus As String, approvedQty As Int, isBulk As Boolean)
	Dim payload As Map
	payload.Initialize
	payload.Put("request_id", requestId)
	payload.Put("status", actionStatus)
	payload.Put("approved_qty", approvedQty)
	payload.Put("reviewer_user_id", Main.LoggedInUserID)
	payload.Put("reviewer_notes", "")

	Dim gen As JSONGenerator
	gen.Initialize(payload)

	Dim job As HttpJob
	job.Initialize("respond_stock_request", Me)
	currentLoadJob = job
	job.PostString(Main.API_URL & "API/respond_stock_request.php", gen.ToString)
	job.GetRequest.SetContentType("application/json")

	Wait For (job) JobDone(jobResp As HttpJob)
	If jobResp.Success = False Then
		jobResp.Release
		currentLoadJob = Null
		If isBulk Then
			bulkReviewFailCount = bulkReviewFailCount + 1
			ProcessNextBulkRequestReview
		Else
			ToastMessageShow("Unable to update request.", True)
		End If
		Return
	End If

	Try
		Dim parser As JSONParser
		parser.Initialize(jobResp.GetString)
		Dim root As Map = parser.NextObject
		If root.Get("status") <> "success" Then
			jobResp.Release
			currentLoadJob = Null
			If isBulk Then
				bulkReviewFailCount = bulkReviewFailCount + 1
				ProcessNextBulkRequestReview
			Else
				ToastMessageShow(GetStringValue(root, "message"), True)
			End If
			Return
		End If

		jobResp.Release
		currentLoadJob = Null
		If isBulk Then
			bulkReviewSuccessCount = bulkReviewSuccessCount + 1
			ProcessNextBulkRequestReview
		Else
			ToastMessageShow("Request updated.", False)
			LoadPendingRequests
		End If
	Catch
		jobResp.Release
		currentLoadJob = Null
		If isBulk Then
			bulkReviewFailCount = bulkReviewFailCount + 1
			ProcessNextBulkRequestReview
		Else
			ToastMessageShow("Invalid review response.", True)
		End If
	End Try
End Sub

Private Sub lblRefresh_Click
	LoadPendingRequests
End Sub

Private Sub lblBack_Click
	StartActivity(SupervisorOrderTakerSelection)
	Activity.Finish
End Sub

Private Sub ShowEmptyMessage(message As String)
	clvRequests.Clear
	Dim pnlEmpty As Panel
	pnlEmpty.Initialize("")
	pnlEmpty.Color = Colors.Transparent
	pnlEmpty.SetLayout(0, 0, clvRequests.AsView.Width, 120dip)

	Dim lblEmpty As Label
	lblEmpty.Initialize("")
	lblEmpty.Text = message
	lblEmpty.TextSize = 15
	lblEmpty.TextColor = Colors.Gray
	lblEmpty.Gravity = Gravity.CENTER
	pnlEmpty.AddView(lblEmpty, 0, 32dip, clvRequests.AsView.Width, 40dip)

	clvRequests.Add(pnlEmpty, "empty")
	lblStatus.Text = message
End Sub

Private Sub GetRequestRow(requestId As Int) As Map
	If requestById.ContainsKey(requestId) Then
		Return requestById.Get(requestId)
	End If
	Dim emptyMap As Map
	emptyMap.Initialize
	Return emptyMap
End Sub

Private Sub GetStringValue(source As Map, key As String) As String
	If source.IsInitialized = False Then Return ""
	If source.ContainsKey(key) = False Then Return ""
	If source.Get(key) = Null Then Return ""
	Return source.Get(key)
End Sub

Private Sub GetIntValue(source As Map, key As String) As Int
	If source.IsInitialized = False Then Return 0
	If source.ContainsKey(key) = False Then Return 0
	If source.Get(key) = Null Then Return 0
	Return source.Get(key)
End Sub