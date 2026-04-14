Group=Default Group
ModulesStructureVersion=1
Type=StaticCode
Version=1.80
@EndOfDesignText@
'Code module
Sub Process_Globals
	'VERSION: 1.04
	Type PieItem (Name As String, Value As Float, Color As Int) 
	Type PieData (Items As List, Target As Panel, Canvas As Canvas, GapDegrees As Int, _
		LegendTextSize As Float, LegendBackColor As Int)
	Type GraphInternal (originX As Int, zeroY As Int, originY As Int, maxY As Int, intervalX As Float, gw As Int, gh As Int)
	Type Graph (GI As GraphInternal, Title As String, YAxis As String, XAxis As String, YStart As Float, _ 
		YEnd As Float, YInterval As Float, AxisColor As Int)
	Type LinePoint (X As String, Y As Float, YArray() As Float, ShowTick As Boolean)
	Type LineData (Points As List, LinesColors As List, Target As Panel, Canvas As Canvas)
	Type BarData (Points As List, BarsColors As List, Target As Panel, Canvas As Canvas, Stacked As Boolean, BarsWidth As Int)
End Sub

#Region Bar chart methods

#End Region

#Region Line charts related methods

#End Region

#Region  Pie related methods
Sub AddPieItem(PD As PieData, Name As String, Value As Float, Color As Int)
	If PD.Items.IsInitialized = False Then PD.Items.Initialize
	If Color = 0 Then Color = Colors.RGB(Rnd(0, 255), Rnd(0, 255), Rnd(0, 255))
	Dim i As PieItem
	i.Initialize
	i.Name = Name
	i.Value = Value
	i.Color = Color
	PD.Items.Add(i)
End Sub

Sub DrawPie (PD As PieData, BackColor As Int, CreateLegendBitmap As Boolean) As Bitmap
	If PD.Items.Size = 0 Then
		ToastMessageShow("Missing pie values.", True)
		Return Null
	End If
	PD.Canvas.Initialize(PD.Target)
	PD.Canvas.DrawColor(BackColor)
	Dim Radius As Int
	Radius = Min(PD.Canvas.Bitmap.Width, PD.Canvas.Bitmap.Height) * 0.8 / 2
	Dim total As Int
	For i = 0 To PD.Items.Size - 1
		Dim it As PieItem
		it = PD.Items.Get(i)
		total = total + it.Value
	Next
	Dim startingAngle As Float
	startingAngle = 0
	Dim GapDegrees As Int
	If PD.Items.Size = 1 Then GapDegrees = 0 Else GapDegrees = PD.GapDegrees
	For i = 0 To PD.Items.Size - 1
		Dim it As PieItem
		it = PD.Items.Get(i)
		startingAngle = startingAngle + _ 
			calcSlice(PD.Canvas, Radius, startingAngle, it.Value / total, it.Color, GapDegrees)
	Next
	PD.Target.Invalidate
	If CreateLegendBitmap Then
		Return createLegend(PD)
	Else
		Return Null
	End If
End Sub

'Draws a single slice
Sub calcSlice(Canvas As Canvas, Radius As Int, _ 
		StartingDegree As Float, Percent As Float, Color As Int, GapDegrees As Int) As Float
	Dim b As Float
	b = 360 * Percent
	
	Dim cx, cy As Int
	cx = Canvas.Bitmap.Width / 2
	cy = Canvas.Bitmap.Height / 2 
	Dim p As Path
	p.Initialize(cx, cy)
	Dim gap As Float
	gap = Percent * GapDegrees / 2
	For i = StartingDegree + gap To StartingDegree + b - gap Step 10
		p.LineTo(cx + 2 * Radius * SinD(i), cy + 2 * Radius * CosD(i))
	Next
	p.LineTo(cx + 2 * Radius * SinD(StartingDegree + b - gap), cy + 2 * Radius * CosD(StartingDegree + b - gap))
	p.LineTo(cx, cy)
	Canvas.ClipPath(p) 'We are limiting the drawings to the required slice
	Canvas.DrawCircle(cx, cy, Radius, Color, True, 0)
	Canvas.RemoveClip
	Return b
End Sub

Sub createLegend(PD As PieData) As Bitmap
	Dim bmp As Bitmap
	If PD.LegendTextSize = 0 Then PD.LegendTextSize = 15
	Dim textHeight, textWidth As Float
	textHeight = PD.Canvas.MeasureStringHeight("M", Typeface.DEFAULT_BOLD, PD.LegendTextSize)
	For i = 0 To PD.Items.Size - 1
		Dim it As PieItem
		it = PD.Items.Get(i)
		textWidth = Max(textWidth, PD.Canvas.MeasureStringWidth(it.Name, Typeface.DEFAULT_BOLD, PD.LegendTextSize))
	Next
	bmp.InitializeMutable(textWidth + 20dip, 10dip +(textHeight + 10dip) * PD.Items.Size)
	Dim c As Canvas
	c.Initialize2(bmp)
	c.DrawColor(PD.LegendBackColor)
	For i = 0 To PD.Items.Size - 1
		Dim it As PieItem
		it = PD.Items.Get(i)
		c.DrawText(it.Name, 10dip, (i + 1) * (textHeight + 10dip), Typeface.DEFAULT_BOLD, PD.LegendTextSize, _
			it.Color, "LEFT")
	Next
	Return bmp
End Sub
#End Region




