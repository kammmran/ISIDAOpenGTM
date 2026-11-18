unit uGTMmanifold;

{ 3D view of a GTM manifold and of the data it was fitted to, in the space of
  the first three principal components.

  The view used to be built with GLScene. GLScene is not available for the
  Lazarus Cocoa widgetset (macOS), so the scene is now drawn with the
  TOpenGLControl that ships with Lazarus (package LazOpenGLContext), which
  works on Windows, Linux and macOS.

  Mouse: drag = rotate, Shift+drag = pan, wheel = zoom.

  Command line (optional): GTMmanifold <data Z3D.mat> <manifold WPhi3D.mat> <model.xml>
  pre-fills the three file fields and displays them directly. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ComCtrls,
  ExtCtrls, StdCtrls, Menus, Types, Math, StrUtils, OpenGLContext, GL, GLU;

type
  TVec3 = record
    X, Y, Z: double;
  end;
  TVec3Array = array of TVec3;
  TTriangle = array[0..2] of integer;

  { TFrmGTMmanifold }

  TFrmGTMmanifold = class(TForm)
    BtOK: TButton;
    BtQuit: TButton;
    BtDataPoints: TButton;
    BtWPhi: TButton;
    BtXML: TButton;
    EdDataPoints: TEdit;
    EdWPhi: TEdit;
    EdXML: TEdit;
    Label1: TLabel;
    ODXML: TOpenDialog;
    ODWPhi: TOpenDialog;
    ODDataPoints: TOpenDialog;
    RadioBackground1: TRadioButton;
    RadioBackground2: TRadioButton;
    TrackBar1: TTrackBar;
    procedure BtDataPointsClick(Sender: TObject);
    procedure BtOKClick(Sender: TObject);
    procedure BtQuitClick(Sender: TObject);
    procedure BtWPhiClick(Sender: TObject);
    procedure BtXMLClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure RadioBackground1Change(Sender: TObject);
    procedure RadioBackground2Change(Sender: TObject);
    procedure TrackBar1Change(Sender: TObject);
  private
    FView: TOpenGLControl;
    FPts: TVec3Array;               // data points, scaled into [-1,1]^3
    FNodes: TVec3Array;             // manifold nodes, scaled into [-1,1]^3
    FTris: array of TTriangle;      // triangles between manifold nodes
    FPointSize: single;
    FWhiteBackground: boolean;
    FYaw, FPitch, FDist: double;    // camera orbit around the target
    FTarget: TVec3;
    FMouseX, FMouseY: integer;
    FAutoLoad: boolean;
    procedure ViewPaint(Sender: TObject);
    procedure ViewMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ViewMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure ViewMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure DoAutoLoad(Data: PtrInt);
  public
    a: integer;
  end;

var
  FrmGTMmanifold: TFrmGTMmanifold;

implementation

{$R *.lfm}

const
  // Initial view, as in the former GLScene setup: camera at (6,5,4) looking at the origin.
  InitYaw = 39.8;    // degrees, atan2(5,6)
  InitPitch = 24.7;  // degrees, atan2(4, sqrt(6^2+5^2))
  InitDist = 4.0;

function ParseFloat(const s: string; out v: double): boolean;
var
  fs: TFormatSettings;
begin
  fs := DefaultFormatSettings;
  fs.DecimalSeparator := '.';
  Result := TryStrToFloat(Trim(s), v, fs);
end;

function ReadMat3(const fn: string): TVec3Array;
// Read a 3-column .mat file written by GTMapTool: a header line, then x,y,z per line.
var
  sl, tup: TStringList;
  i, n: integer;
begin
  Result := nil;
  sl := TStringList.Create;
  tup := TStringList.Create;
  try
    tup.Delimiter := ',';
    tup.StrictDelimiter := True;
    sl.LoadFromFile(fn);
    SetLength(Result, sl.Count);
    n := 0;
    for i := 0 to sl.Count - 1 do
    begin
      tup.DelimitedText := Trim(sl[i]);
      if tup.Count < 3 then continue;
      if not (ParseFloat(tup[0], Result[n].X) and ParseFloat(tup[1], Result[n].Y)
        and ParseFloat(tup[2], Result[n].Z)) then continue; // header line
      Inc(n);
    end;
    SetLength(Result, n);
  finally
    tup.Free;
    sl.Free;
  end;
end;

function ReadLatentSamples(const fn: string): TVec3Array;
// The 2D coordinates of the nodes in latent space, from the <LatentSamples> block of a GTM model.
var
  sl, tup: TStringList;
  i, n: integer;
  inside, last: boolean;
  s: string;
begin
  Result := nil;
  sl := TStringList.Create;
  tup := TStringList.Create;
  try
    tup.Delimiter := ',';
    tup.StrictDelimiter := True;
    sl.LoadFromFile(fn);
    SetLength(Result, sl.Count);
    n := 0;
    inside := False;
    for i := 0 to sl.Count - 1 do
    begin
      s := sl[i];
      if (not inside) and (Pos('<LatentSamples', s) > 0) then
      begin
        inside := True;
        s := Copy(s, Pos('>', s) + 1, Length(s));
      end;
      if not inside then continue;
      last := Pos('</LatentSamples>', s) > 0;
      if last then s := Copy(s, 1, Pos('</LatentSamples>', s) - 1);
      tup.DelimitedText := Trim(s);
      if (tup.Count = 2) and ParseFloat(tup[0], Result[n].X) and ParseFloat(tup[1], Result[n].Y) then
      begin
        Result[n].Z := 0;
        Inc(n);
      end;
      if last then break;
    end;
    SetLength(Result, n);
  finally
    tup.Free;
    sl.Free;
  end;
end;

{ TFrmGTMmanifold }

procedure TFrmGTMmanifold.FormCreate(Sender: TObject);
begin
  a := 1;
  FPointSize := 5;
  FWhiteBackground := False;
  FYaw := InitYaw;
  FPitch := InitPitch;
  FDist := InitDist;
  FView := TOpenGLControl.Create(Self);
  with FView do
  begin
    Parent := Self;
    AnchorSideLeft.Control := Self;
    AnchorSideTop.Control := Self;
    AnchorSideRight.Control := Self;
    AnchorSideRight.Side := asrBottom;
    AnchorSideBottom.Control := TrackBar1;
    Anchors := [akTop, akLeft, akRight, akBottom];
    AutoResizeViewport := True;
    OnPaint := @ViewPaint;
    OnMouseDown := @ViewMouseDown;
    OnMouseMove := @ViewMouseMove;
    OnMouseWheel := @ViewMouseWheel;
  end;
  // Optional command line: data, manifold and model files
  if (ParamCount >= 3) and FileExists(ParamStr(1)) then
  begin
    EdDataPoints.Text := ParamStr(1);
    EdWPhi.Text := ParamStr(2);
    EdXML.Text := ParamStr(3);
    FAutoLoad := True;
  end;
end;

procedure TFrmGTMmanifold.FormShow(Sender: TObject);
begin
  if FAutoLoad then
  begin
    FAutoLoad := False;
    Application.QueueAsyncCall(@DoAutoLoad, 0);
  end;
end;

procedure TFrmGTMmanifold.DoAutoLoad(Data: PtrInt);
begin
  BtOKClick(nil);
end;

procedure TFrmGTMmanifold.ViewPaint(Sender: TObject);
var
  i, k: integer;
  w, h: integer;
  fg: single;
begin
  w := FView.Width;
  h := Max(FView.Height, 1);
  glViewport(0, 0, w, h);
  if FWhiteBackground then glClearColor(1, 1, 1, 1) else glClearColor(0, 0, 0, 1);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
  glEnable(GL_DEPTH_TEST);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  gluPerspective(45.0, w / h, 0.05, 100.0);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  // orbit camera: distance, then pitch and yaw around the target; Z axis up
  glTranslated(0, 0, -FDist);
  glRotated(FPitch, 1, 0, 0);
  glRotated(-90, 1, 0, 0);
  glRotated(-FYaw - 90, 0, 0, 1);
  glTranslated(-FTarget.X, -FTarget.Y, -FTarget.Z);

  // manifold as a wireframe of triangles
  glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
  glColor3f(0.6, 0.6, 0.6);
  glBegin(GL_TRIANGLES);
  for i := 0 to High(FTris) do
    for k := 0 to 2 do
      with FNodes[FTris[i][k]] do glVertex3d(X, Y, Z);
  glEnd;
  glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

  // manifold nodes in magenta
  glPointSize(FPointSize);
  glColor3f(1, 0, 1);
  glBegin(GL_POINTS);
  for i := 0 to High(FNodes) do with FNodes[i] do glVertex3d(X, Y, Z);
  glEnd;

  // data points as round dots: white on black, black on white
  glEnable(GL_POINT_SMOOTH);
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  if FWhiteBackground then fg := 0 else fg := 1;
  glColor3f(fg, fg, fg);
  glBegin(GL_POINTS);
  for i := 0 to High(FPts) do with FPts[i] do glVertex3d(X, Y, Z);
  glEnd;
  glDisable(GL_POINT_SMOOTH);
  glDisable(GL_BLEND);

  FView.SwapBuffers;
end;

procedure TFrmGTMmanifold.ViewMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FMouseX := X;
  FMouseY := Y;
end;

procedure TFrmGTMmanifold.ViewMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
  dx, dy, s, cy, sy: double;
begin
  if ssLeft in Shift then
  begin
    dx := X - FMouseX;
    dy := Y - FMouseY;
    if ssShift in Shift then
    begin
      // pan in the view plane
      s := FDist * 0.002;
      cy := cos(DegToRad(FYaw));
      sy := sin(DegToRad(FYaw));
      FTarget.X := FTarget.X + dx * s * sy;
      FTarget.Y := FTarget.Y - dx * s * cy;
      FTarget.Z := FTarget.Z + dy * s;
    end else
    begin
      FYaw := FYaw - dx * 0.5;
      FPitch := EnsureRange(FPitch + dy * 0.5, -89, 89);
    end;
    FView.Invalidate;
  end;
  FMouseX := X;
  FMouseY := Y;
end;

procedure TFrmGTMmanifold.ViewMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  if WheelDelta > 0 then FDist := FDist * 0.9 else FDist := FDist * 1.1;
  FDist := EnsureRange(FDist, 0.2, 50);
  FView.Invalidate;
  Handled := True;
end;

procedure TFrmGTMmanifold.RadioBackground1Change(Sender: TObject);
begin
  FWhiteBackground := RadioBackground2.Checked;
  if Assigned(FView) then FView.Invalidate;
end;

procedure TFrmGTMmanifold.RadioBackground2Change(Sender: TObject);
begin
  FWhiteBackground := RadioBackground2.Checked;
  if Assigned(FView) then FView.Invalidate;
end;

procedure TFrmGTMmanifold.TrackBar1Change(Sender: TObject);
begin
  FPointSize := 5 + TrackBar1.Position;
  if Assigned(FView) then FView.Invalidate;
end;

procedure TFrmGTMmanifold.BtOKClick(Sender: TObject);
var
  xyz, wxyz, xy: TVec3Array;
  lo, hi: array[1..3] of double;
  i, j, k, j1, nt: integer;
  d: double;
  nnId: array[0..5] of integer;
  nnD: array[0..5] of double;

  procedure Grow(const v: TVec3);
  begin
    lo[1] := Min(lo[1], v.X); hi[1] := Max(hi[1], v.X);
    lo[2] := Min(lo[2], v.Y); hi[2] := Max(hi[2], v.Y);
    lo[3] := Min(lo[3], v.Z); hi[3] := Max(hi[3], v.Z);
  end;

  function Sc(x: double; c: integer): double;
  begin
    if hi[c] > lo[c] then Result := 2 * (x - lo[c]) / (hi[c] - lo[c]) - 1 else Result := 0;
  end;

  function Scaled(const v: TVec3): TVec3;
  begin
    Result.X := Sc(v.X, 1);
    Result.Y := Sc(v.Y, 2);
    Result.Z := Sc(v.Z, 3);
  end;

begin
  try
    xyz := ReadMat3(EdDataPoints.Text);
    wxyz := ReadMat3(EdWPhi.Text);
    xy := ReadLatentSamples(EdXML.Text);
  except
    on E: Exception do
    begin
      ShowMessage('Cannot read the input files: ' + E.Message);
      exit;
    end;
  end;
  if (Length(xyz) = 0) or (Length(wxyz) = 0) then
  begin
    ShowMessage('The data or manifold coordinate file is empty or not in .mat format.');
    exit;
  end;
  // Common scaling of data and manifold into [-1,1]^3
  for k := 1 to 3 do begin lo[k] := MaxDouble; hi[k] := -MaxDouble; end;
  for i := 0 to High(xyz) do Grow(xyz[i]);
  for i := 0 to High(wxyz) do Grow(wxyz[i]);
  SetLength(FPts, Length(xyz));
  for i := 0 to High(xyz) do FPts[i] := Scaled(xyz[i]);
  SetLength(FNodes, Length(wxyz));
  for i := 0 to High(wxyz) do FNodes[i] := Scaled(wxyz[i]);

  // Approximate triangulation of the manifold from the latent grid: each node
  // is joined to consecutive pairs of its 6 nearest latent-space neighbours.
  SetLength(FTris, 0);
  if Length(xy) = Length(wxyz) then
  begin
    SetLength(FTris, 6 * Length(xy));
    nt := 0;
    for i := 0 to High(xy) do
    begin
      for k := 0 to 5 do begin nnId[k] := -1; nnD[k] := MaxDouble; end;
      for j := 0 to High(xy) do
        if j <> i then
        begin
          d := sqr(xy[i].X - xy[j].X) + sqr(xy[i].Y - xy[j].Y);
          if d < nnD[5] then
          begin
            k := 5;
            while (k > 0) and (nnD[k - 1] > d) do
            begin
              nnD[k] := nnD[k - 1]; nnId[k] := nnId[k - 1]; Dec(k);
            end;
            nnD[k] := d; nnId[k] := j;
          end;
        end;
      for j := 0 to 5 do
      begin
        j1 := (j + 1) mod 6;
        if (nnId[j] < 0) or (nnId[j1] < 0) then continue;
        FTris[nt][0] := i; FTris[nt][1] := nnId[j]; FTris[nt][2] := nnId[j1];
        Inc(nt);
      end;
    end;
    SetLength(FTris, nt);
  end else if Length(xy) > 0 then
    ShowMessage('The model has ' + IntToStr(Length(xy)) + ' nodes but the manifold file has ' +
      IntToStr(Length(wxyz)) + ' points: the manifold is shown as points only.');

  FTarget.X := 0; FTarget.Y := 0; FTarget.Z := 0;
  Caption := Format('ISIDA/GTMManifoldView - %d points, %d nodes, %d triangles',
    [Length(FPts), Length(FNodes), Length(FTris)]);
  FView.Invalidate;
end;

procedure TFrmGTMmanifold.BtDataPointsClick(Sender: TObject);
begin
  if ODDataPoints.Execute then
    EdDataPoints.Text := ODDataPoints.Filename;
end;

procedure TFrmGTMmanifold.BtQuitClick(Sender: TObject);
begin
  Close;
end;

procedure TFrmGTMmanifold.BtWPhiClick(Sender: TObject);
begin
  if ODWPhi.Execute then
    EdWPhi.Text := ODWPhi.Filename;
end;

procedure TFrmGTMmanifold.BtXMLClick(Sender: TObject);
begin
  if ODXML.Execute then
    EdXML.Text := ODXML.Filename;
end;

end.
