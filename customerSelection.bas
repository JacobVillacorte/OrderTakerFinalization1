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
	'These global variables will be declared once when the application starts.
	'These variables can be accessed from all modules.
	Private tmrSearch As Timer
End Sub

Sub Globals
	'These global variables will be redeclared each time the activity is created.
	'These variables can only be accessed from this module.

	Private bttnConfirmBack As Button
	Private bttnConfirmProceed As Button
	Private clvCustomers As CustomListView
	Private lblConfirmAddress As Label
	Private lblConfirmCustomer As Label
	Private lblConfirmName As Label
	Private lblConfirmOwner As Label
	Private pnlConfirmCustomer As Panel
	Private pnlCustomerSelection As Panel
	Private pnlDim As Panel
	Private etSearchCustomers As EditText
	Private lblExitCustomerSelection As Label

	' Debounce timer for search

	Private lastSearchText As String

	' Pending selection shown in the Yes/No popup
	Private pendingSelectedCustomerID As Int
	Private pendingSelectedCustomerCode As String
	Private pendingSelectedCustomerName As String
	Private pendingSelectedCustomerOwner As String
	Private pendingSelectedCustomerAddress As String

	' Confirmed selection (highlighted in CLV)
	Private confirmedSelectedCustomerID As Int
End Sub

Sub Activity_Create(FirstTime As Boolean)
	'Do not forget to load the layout file created with the visual designer. For example:
	Activity.LoadLayout("customerSelection")

	' Initialize UI state
	If pnlConfirmCustomer.IsInitialized Then pnlConfirmCustomer.Visible = False
	pnlDim.Visible = False

	clvCustomers.Clear
	etSearchCustomers.Text = ""

	' Setup debounce timer
	tmrSearch.Initialize("tmrSearch", 250)

	pendingSelectedCustomerID = 0
	pendingSelectedCustomerCode = Main.SELECTED_CUSTOMER_CODE
	Main.SELECTED_CUSTOMER_CODE = ""
	confirmedSelectedCustomerID = 0

End Sub

Sub Activity_Resume

End Sub

Sub Activity_Pause (UserClosed As Boolean)

End Sub


Private Sub pnlDim_Click
	If pnlConfirmCustomer.IsInitialized Then pnlConfirmCustomer.Visible = False
	pnlDim.Visible = False
	pnlDim.Enabled = False
	pnlDim.SendToBack
	pendingSelectedCustomerID = 0
End Sub

' Debounce tick - perform search
Private Sub tmrSearch_Tick
	tmrSearch.Enabled = False
	DoSearch(lastSearchText)
End Sub

' Fired when user types in the search box; debounce before running query
Private Sub etSearchCustomers_TextChanged(Old As String, New As String)
	lastSearchText = New.Trim
	If lastSearchText = "" Then
		clvCustomers.Clear
		tmrSearch.Enabled = False
		Return
	End If

	tmrSearch.Enabled = False
	tmrSearch.Interval = 250
	tmrSearch.Enabled = True
End Sub

' Perform a local-only search against mst_customers and populate the CLV
Private Sub DoSearch(query As String)
	clvCustomers.Clear

	If Main.SQLProducts.IsInitialized = False Then
		ToastMessageShow("No local customer cache available.", False)
		Return
	End If

	Dim likeValue As String = "%" & query.ToLowerCase & "%"
	Dim rs As ResultSet
	Try
		rs = Main.SQLProducts.ExecQuery2("SELECT * FROM mst_customers WHERE is_active = 1 AND category IN ('WHL','MKTG') AND (LOWER(customer_code) LIKE ? OR LOWER(customer_name) LIKE ? OR LOWER(business_owner) LIKE ? OR LOWER(address) LIKE ?) ORDER BY customer_name LIMIT 50", _
			Array As String(likeValue, likeValue, likeValue, likeValue))
	Catch
		ToastMessageShow("Search failed: " & LastException.Message, True)
		Return
	End Try

	If rs.RowCount = 0 Then
		rs.Close
		Return
	End If

	Do While rs.NextRow
		Dim cid As Int = rs.GetInt("customer_id")
		Dim pnl As Panel
		pnl.Initialize("")
		pnl.SetLayout(0, 0, clvCustomers.AsView.Width, 90dip)

		Dim lblName As Label
		lblName.Initialize("")
		lblName.Text = rs.GetString("customer_code") & " - " & rs.GetString("customer_name")
		lblName.TextSize = 16
		lblName.SetLayout(10dip, 5dip, 80%x, 25dip)

		Dim lblOwner As Label
		lblOwner.Initialize("")
		lblOwner.Text = "Owner: " & rs.GetString("business_owner")
		lblOwner.TextSize = 12
		lblOwner.TextColor = Colors.Gray
		lblOwner.SetLayout(10dip, 30dip, 80%x, 18dip)

		Dim lblAddr As Label
		lblAddr.Initialize("")
		lblAddr.Text = "Addr: " & rs.GetString("address")
		lblAddr.TextSize = 12
		lblAddr.TextColor = Colors.Gray
		lblAddr.SetLayout(10dip, 48dip, 80%x, 18dip)

		pnl.AddView(lblName, lblName.Left, lblName.Top, lblName.Width, lblName.Height)
		pnl.AddView(lblOwner, lblOwner.Left, lblOwner.Top, lblOwner.Width, lblOwner.Height)
		pnl.AddView(lblAddr, lblAddr.Left, lblAddr.Top, lblAddr.Width, lblAddr.Height)

		' Highlight if this is the confirmed selection
		If cid = confirmedSelectedCustomerID Then
			pnl.Color = Colors.RGB(230, 245, 255)
		Else
			pnl.Color = Colors.White
		End If

		clvCustomers.Add(pnl, cid)
	Loop

	rs.Close
End Sub

' User tapped a CLV row — show confirm popup (Yes/No)
Private Sub clvCustomers_ItemClick(Index As Int, Value As Object)
	Dim cid As Int = Value
	pendingSelectedCustomerID = cid
	ShowCustomerConfirmByID(cid)
End Sub

Private Sub ShowCustomerConfirmByID(cid As Int)
	If Main.SQLProducts.IsInitialized = False Then Return

	Dim rs As ResultSet = Main.SQLProducts.ExecQuery2("SELECT * FROM mst_customers WHERE customer_id = ?", Array As String(cid))
	If rs.RowCount = 0 Then
		rs.Close
		ToastMessageShow("Customer not found.", False)
		Return
	End If
	rs.Position = 0

	pendingSelectedCustomerName = rs.GetString("customer_name")
	pendingSelectedCustomerCode = rs.GetString("customer_code")
	pendingSelectedCustomerOwner = rs.GetString("business_owner")
	pendingSelectedCustomerAddress = rs.GetString("address")
	rs.Close

	lblConfirmCustomer.Text = pendingSelectedCustomerCode
	lblConfirmName.Text = pendingSelectedCustomerName
	lblConfirmOwner.Text = pendingSelectedCustomerOwner
	lblConfirmAddress.Text = pendingSelectedCustomerAddress

	If pnlDim.IsInitialized Then
		pnlDim.Visible = True
		pnlDim.Enabled = True
		pnlDim.BringToFront
		' ensure confirm panel sits above the dim
	End If
	pnlConfirmCustomer.Visible = True
	pnlConfirmCustomer.BringToFront
End Sub

' Popup cancel (No)
Private Sub bttnConfirmBack_Click
	pnlConfirmCustomer.Visible = False
	If pnlDim.IsInitialized Then
		pnlDim.Visible = False
		pnlDim.Enabled = False
		pnlDim.SendToBack
	End If
	pendingSelectedCustomerID = 0
End Sub

' Popup Choose (Yes) — mark selection and enable global Confirm
Private Sub bttnConfirmChoose_Click
	If pendingSelectedCustomerID = 0 Then Return

	confirmedSelectedCustomerID = pendingSelectedCustomerID
	Main.SELECTED_CUSTOMER_CODE = pendingSelectedCustomerCode
	Main.SELECTED_CUSTOMER_ID = 0

	pnlConfirmCustomer.Visible = False
	If pnlDim.IsInitialized Then
		pnlDim.Visible = False
		pnlDim.Enabled = False
		pnlDim.SendToBack
	End If

	DoSearch(lastSearchText)
End Sub

' Popup Proceed — save selected customer and continue to add order
Private Sub bttnConfirmProceed_Click
	If pendingSelectedCustomerID = 0 Then Return

	Main.SELECTED_CUSTOMER_ID = pendingSelectedCustomerID
	Main.SELECTED_CUSTOMER_CODE = pendingSelectedCustomerCode
	Main.SELECTED_CUSTOMER_NAME = pendingSelectedCustomerName
	Main.SELECTED_CUSTOMER_OWNER = pendingSelectedCustomerOwner
	Main.SELECTED_CUSTOMER_ADDRESS = pendingSelectedCustomerAddress
	confirmedSelectedCustomerID = pendingSelectedCustomerID

	pnlConfirmCustomer.Visible = False
	If pnlDim.IsInitialized Then
		pnlDim.Visible = False
		pnlDim.Enabled = False
		pnlDim.SendToBack
	End If

	StartActivity(addOrderActivity)
	Activity.Finish
End Sub

Private Sub lblExitCustomerSelection_Click
	Activity.Finish
End Sub
