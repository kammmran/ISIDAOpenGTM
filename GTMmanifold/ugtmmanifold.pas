unit uGTMmanifold;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ComCtrls,
  ExtCtrls, StdCtrls, Menus, GLScene, GLLCLViewer, GLMesh, GLObjects, Types;

type

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
    GLCam: TGLCamera;
    GLDmy: TGLDummyCube;
    GLLight: TGLLightSource;
    GLwMesh: TGLMesh;
    GLPtsW: TGLPoints;
    GLPts: TGLPoints;
    GLSmain: TGLScene;
    GLSViewer: TGLSceneViewer;
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
    procedure GLSViewerKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure GLSViewerKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState
      );
    procedure GLSViewerMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure GLSViewerMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure GLSViewerMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure GLSViewerMouseWheelDown(Sender: TObject; Shift: TShiftState;
      MousePos: TPoint; var Handled: Boolean);
    procedure GLSViewerMouseWheelUp(Sender: TObject; Shift: TShiftState;
      MousePos: TPoint; var Handled: Boolean);
    procedure RadioBackground1Change(Sender: TObject);
    procedure RadioBackground2Change(Sender: TObject);
    procedure TrackBar1Change(Sender: TObject);
  private

  public
    a: integer;
  end;

var
  FrmGTMmanifold: TFrmGTMmanifold;
  mx,my: integer;
  bTranslate: boolean;

implementation

{$R *.lfm}

{ TFrmGTMmanifold }

procedure TFrmGTMmanifold.FormCreate(Sender: TObject);
begin
  a:=1;
  bTranslate:=False;
end;

procedure TFrmGTMmanifold.GLSViewerKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (ssShift in Shift) then bTranslate:=True;
end;

procedure TFrmGTMmanifold.GLSViewerKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  bTranslate:=False;
end;

procedure TFrmGTMmanifold.GLSViewerMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  mx := x;
  my := y;
end;

procedure TFrmGTMmanifold.GLSViewerMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
  if bTranslate=False then
  begin
    if ssLeft in Shift then
    begin
      GLCam.MoveAroundTarget((my - y) * 0.8, (mx - x) * 0.8);
    end;
  end else
  begin
    if ssLeft in Shift then
    begin
      GLCam.Translate((mx - x) * 0.8, (my - y) * 0.8,0);
    end;
  end;
  mx := x;
  my := y;
end;

procedure TFrmGTMmanifold.GLSViewerMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  bTranslate:=False;
end;

procedure TFrmGTMmanifold.GLSViewerMouseWheelDown(Sender: TObject;
  Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);
begin
    GLCam.AdjustDistanceToTarget(0.9);
end;

procedure TFrmGTMmanifold.GLSViewerMouseWheelUp(Sender: TObject;
  Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);
begin
    GLCam.AdjustDistanceToTarget(1.1);
end;

procedure TFrmGTMmanifold.RadioBackground1Change(Sender: TObject);
begin
  GLSmain.CurrentBuffer.BackgroundColor:=clBlack;
end;

procedure TFrmGTMmanifold.RadioBackground2Change(Sender: TObject);
begin
  GLSmain.CurrentBuffer.BackgroundColor:=clWhite;
end;

procedure TFrmGTMmanifold.TrackBar1Change(Sender: TObject);
var
  wpoint,point : TGLPoints;
begin
  point:=GLPts;
  wpoint:=GLPtsW;
  //showmessage('Change '+FloatToStr(point.Size));
  //showmessage('Trackbar '+inttostr(TrackBar1.position));
  point.Size:=5+TrackBar1.position;
  wpoint.Size:=5+TrackBar1.position;
end;

procedure TFrmGTMmanifold.BtOKClick(Sender: TObject);
var
  strainf,swphif,xmlf: string;
  sxml,sdata,stuple: TStringList;
  j1,j,i,idx,idxb,idxe: integer;
  x,y,z: double;
  xy,xyz,wxyz: array of array of double;
  xyzrg: array [1 .. 2, 1 .. 3] of double;
  xy6: array [1..6,1..3] of double; //x,y and distance
  wpoint,point : TGLPoints;
  Nsple,Npts,wNpts: integer;
  bfound:boolean;
  d,dmax: double;
  i6,i6max: integer;
  id6: array [1..6] of integer;
  v1,v2,v3: TVertexData;
  dmin: double;
begin
  strainf:=EdDataPoints.Text;//'/Users/marcou/workdir/ISIDAGTM2017/GTMapTool/examples/IUPHAR_5HT2BZ3Dtrain.mat';
  swphif:=EdWPhi.Text;//'/Users/marcou/workdir/ISIDAGTM2017/GTMapTool/examples/IUPHAR_5HT2BWPhi3D.mat';
  xmlf:=EdXML.Text;//'/Users/marcou/workdir/ISIDAGTM2017/GTMapTool/examples/IUPHAR_5HT2B.xml';
  //
  for i:=1 to 6 do
  begin
    xy6[i,1]:=0;
    xy6[i,2]:=0;
    xy6[i,3]:=4;//All distances are between 0 and 1
    id6[i]:=0;
  end;
  point:=GLPts;
  //point.Size:=2;
  point.Size:=5;
  wpoint:=GLPtsW;
  //wpoint.Size:=2;
  wpoint.Size:=5;
  //
  point.Positions.Clear;
  point.Colors.Clear;
  wpoint.Positions.Clear;
  wpoint.Colors.Clear;
  GLwMesh.Vertices.Clear;
  //
  sdata:=TStringList.Create;
  sxml:=TStringList.Create;
  stuple:=TStringList.Create;
  stuple.Delimiter:=',';
  // Train3D
  sdata.LoadFromFile(strainf);
  Npts:=sdata.Count-2;
  SetLength(xyz,Npts+1,4);//xyz is 1 based
  stuple.CommaText:=sdata[1];
  xyzrg[1,1]:=StrToFloat(stuple[0]);
  xyzrg[2,1]:=StrToFloat(stuple[0]);
  xyzrg[1,2]:=StrToFloat(stuple[1]);
  xyzrg[2,2]:=StrToFloat(stuple[1]);
  xyzrg[1,3]:=StrToFloat(stuple[2]);
  xyzrg[2,3]:=StrToFloat(stuple[2]);
  for i:=1 to Npts do
  begin
    stuple.CommaText:=sdata[i];
    x:=StrToFloat(stuple[0]);
    y:=StrToFloat(stuple[1]);
    z:=StrToFloat(stuple[2]);
    //
    xyz[i,1]:=x;
    xyz[i,2]:=y;
    xyz[i,3]:=z;
    //
    if (x<xyzrg[1,1]) then xyzrg[1,1]:=x;
    if (x>xyzrg[2,1]) then xyzrg[2,1]:=x;
    if (y<xyzrg[1,2]) then xyzrg[1,2]:=y;
    if (y>xyzrg[2,2]) then xyzrg[2,2]:=y;
    if (z<xyzrg[1,3]) then xyzrg[1,3]:=z;
    if (z>xyzrg[2,3]) then xyzrg[2,3]:=z;
  end;
  //WPhi 3D
  sdata.Clear;
  stuple.Clear;
  sdata.LoadFromFile(swphif);
  wNpts:=sdata.Count-2;
  SetLength(wxyz,wNpts+1,4);//xyz is 1 based
  for i:=1 to wNpts do
  begin
    stuple.CommaText:=sdata[i];
    x:=StrToFloat(stuple[0]);
    y:=StrToFloat(stuple[1]);
    z:=StrToFloat(stuple[2]);
    //
    wxyz[i,1]:=x;
    wxyz[i,2]:=y;
    wxyz[i,3]:=z;
    //
    if (x<xyzrg[1,1]) then xyzrg[1,1]:=x;
    if (x>xyzrg[2,1]) then xyzrg[2,1]:=x;
    if (y<xyzrg[1,2]) then xyzrg[1,2]:=y;
    if (y>xyzrg[2,2]) then xyzrg[2,2]:=y;
    if (z<xyzrg[1,3]) then xyzrg[1,3]:=z;
    if (z>xyzrg[2,3]) then xyzrg[2,3]:=z;
  end;
  // Plot the train 3D
  for i:=1 to Npts do
  begin
    x:=2*(xyz[i,1]-xyzrg[1,1])/(xyzrg[2,1]-xyzrg[1,1])-1;
    y:=2*(xyz[i,2]-xyzrg[1,2])/(xyzrg[2,2]-xyzrg[1,2])-1;
    z:=2*(xyz[i,3]-xyzrg[1,3])/(xyzrg[2,3]-xyzrg[1,3])-1;
    point.Positions.Add(x, y, z);
  end;
  // Plot the train 3D
  for i:=1 to wNpts do
  begin
    x:=2*(wxyz[i,1]-xyzrg[1,1])/(xyzrg[2,1]-xyzrg[1,1])-1;
    y:=2*(wxyz[i,2]-xyzrg[1,2])/(xyzrg[2,2]-xyzrg[1,2])-1;
    z:=2*(wxyz[i,3]-xyzrg[1,3])/(xyzrg[2,3]-xyzrg[1,3])-1;
    wpoint.Positions.Add(x, y, z);
    wpoint.Colors.AddPoint(1.0,0.0,1.0);
  end;
  //Get latent space sample position
  sxml.LoadFromFile(xmlf);
  idx:=-1;
  bfound:=False;
  while((not bfound) and (idx<sxml.Count)) do
  begin
    idx:=idx+1;
    if Pos('<LatentSamples>',sxml[idx])>0 then begin
       idxb:=idx;
       idxe:=idx;
    end;
    if Pos('</LatentSamples>',sxml[idx])>0 then begin
      bfound:=True;
      idxe:=idx-1;
    end;
  end;
  if bfound then
  begin
    Nsple:=idxe-idxb+1;
    SetLength(xy,Nsple+1,3);
    for i:=idxb to idxe do
    begin
      stuple.Clear;
      stuple.CommaText:=RightStr(sxml[i],Length(sxml[i])-Pos('>',sxml[i]));
      if stuple.Count=2 then
      begin
        xy[i-idxb+1,1]:=StrToFloat(stuple[0]);
        xy[i-idxb+1,2]:=StrToFloat(stuple[1]);
      end;
    end;
  end;
  // kind of triangulate the latent space - shall be improved by a Delonay triangulation
  for i:=1 to Nsple do
  begin
    for i6:=1 to 6 do
    begin
      xy6[i6,1]:=0;
      xy6[i6,2]:=0;
      xy6[i6,3]:=4;//All distances are between 0 and 1
      id6[i6]:=0;
    end;
    for j:=1 to Nsple do //Search 6 nearest neighbors of i
    begin
      if (j<>i) then
      begin
        d:=sqr(xy[i,1]-xy[j,1])+sqr(xy[i,2]-xy[j,2]);
        i6:=1; bfound:=False;
        while (not bfound)  and (i6<=6) do
        begin
          if (xy6[i6,3] >= d) then bfound:=True;
          i6:=i6+1;
        end;
        if bfound then
        begin
          i6max:=i6;
          for i6:=6 downto i6max do
          begin
            xy6[i6,1]:=xy6[i6-1,1];
            xy6[i6,2]:=xy6[i6-1,2];
            xy6[i6,3]:=xy6[i6-1,3];
            id6[i6]:=id6[i6-1];
          end;
          xy6[i6max-1,1]:=xy[j,1];
          xy6[i6max-1,2]:=xy[j,2];
          xy6[i6max-1,3]:=d;
          id6[i6max-1]:=j;
        end;
      end;
    end;
    //Add the corresponding 3D triangles to the mesh
    for j:=1 to 6 do
    begin
      if(j=6) then j1:=1 else j1:=j+1;
      v1.coord.X:=2*(wxyz[i,1]-xyzrg[1,1])/(xyzrg[2,1]-xyzrg[1,1])-1;
      v1.coord.Y:=2*(wxyz[i,2]-xyzrg[1,2])/(xyzrg[2,2]-xyzrg[1,2])-1;
      v1.coord.Z:=2*(wxyz[i,3]-xyzrg[1,3])/(xyzrg[2,3]-xyzrg[1,3])-1;
      v2.coord.X:=2*(wxyz[id6[j],1]-xyzrg[1,1])/(xyzrg[2,1]-xyzrg[1,1])-1;
      v2.coord.Y:=2*(wxyz[id6[j],2]-xyzrg[1,2])/(xyzrg[2,2]-xyzrg[1,2])-1;
      v2.coord.Z:=2*(wxyz[id6[j],3]-xyzrg[1,3])/(xyzrg[2,3]-xyzrg[1,3])-1;
      v3.coord.X:=2*(wxyz[id6[j1],1]-xyzrg[1,1])/(xyzrg[2,1]-xyzrg[1,1])-1;
      v3.coord.Y:=2*(wxyz[id6[j1],2]-xyzrg[1,2])/(xyzrg[2,2]-xyzrg[1,2])-1;
      v3.coord.Z:=2*(wxyz[id6[j1],3]-xyzrg[1,3])/(xyzrg[2,3]-xyzrg[1,3])-1;
      v1.normal.X:=0;
      v1.normal.Y:=0;
      v1.normal.Z:=0;
      v2.normal.X:=0;
      v2.normal.Y:=0;
      v2.normal.Z:=0;
      v3.normal.X:=0;
      v3.normal.Y:=0;
      v3.normal.Z:=0;
      GLwMesh.Vertices.AddVertex3(v1,v2,v3);
    end;
  end;
  //
  FreeAndNil(sdata);
  FreeAndNil(stuple);
  FreeAndNil(sxml);
end;

procedure TFrmGTMmanifold.BtDataPointsClick(Sender: TObject);
begin
  if ODDataPoints.Execute then
  begin
    EdDataPoints.Text := ODDataPoints.Filename;
  end;
end;

procedure TFrmGTMmanifold.BtQuitClick(Sender: TObject);
begin
  Close;
end;

procedure TFrmGTMmanifold.BtWPhiClick(Sender: TObject);
begin
  if ODWPhi.Execute then
  begin
    EdWPhi.Text := ODWPhi.Filename;
  end;
end;

procedure TFrmGTMmanifold.BtXMLClick(Sender: TObject);
begin
  if ODXML.Execute then
  begin
    EdXML.Text := ODXML.Filename;
  end;
end;

end.
{
procedure TForm1.GLSceneViewer1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
end;


procedure TForm1.GLSceneViewer1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
begin
end;


procedure TForm1.FormMouseWheelDown(Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);
begin
end;


procedure TForm1.FormMouseWheelUp(Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean);
begin
end;
}
