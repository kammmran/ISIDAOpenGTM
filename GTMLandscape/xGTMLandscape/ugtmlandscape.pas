unit uGTMLandscape;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  MaskEdit, Buttons, TASources, TAGraph, TAMultiSeries, TASeries, TAChartUtils,
  TAChartImageList, contnrs, fgl, XMLRead, XMLWrite, DOM, UGTMXML, UGTMBase,
  UcGTM, utypes, ulinalg, TADrawUtils, TATools, TAFuncSeries, TAColorMap, strutils,
  GraphType, UnitMolDraw, Types, IntfGraphics, unitProc, UnitLLStringList,
  UnitNodeSelectProc, process, TACustomSeries, ioSVM;

type
  TIntegerList = specialize TFPGList<Integer>;

  { TFrmxGTMLandscape }

  TFrmxGTMLandscape = class(TForm)
    BitBtnFirst: TBitBtn;
    BitBtnGoTo: TBitBtn;
    BitBtnLast: TBitBtn;
    BitBtnLeft: TBitBtn;
    BitBtnRight: TBitBtn;
    BtLandscapeFile: TButton;
    BtGTM: TButton;
    BtProjections: TButton;
    BtResp: TButton;
    BtQuit: TButton;
    BtOK: TButton;
    BtSVM: TButton;
    BtSDF: TButton;
    BtSavePlot: TButton;
    BtUpdate: TButton;
    BtZoom: TButton;
    EdGTM: TLabeledEdit;
    EdSVM: TLabeledEdit;
    EdtTop: TLabeledEdit;
    EdtLeft: TLabeledEdit;
    EdtBottom: TLabeledEdit;
    EdtRight: TLabeledEdit;
    LblZoomZone: TLabel;
    LSZoomTag1: TLineSeries;
    CBProp: TComboBox;
    ChCumRsp: TChart;
    ChOrgRspLS1: TLineSeries;
    ChCumRspLS1: TLineSeries;
    ChPrj: TChart;
    ChScale: TChart;
    ChGTMLatent: TChart;
    CBLandscapes: TComboBox;
    ChToolCumRsp: TChartToolset;
    ChToolCumRspDataPointHintTool1: TDataPointHintTool;
    CMGradient: TColorMapSeries;
    CBColorspace: TComboBox;
    CTSMolsUserDefinedTool1: TUserDefinedTool;
    CTSMolsZoomDragTool1: TZoomDragTool;
    EdColmin: TEdit;
    EdColmax: TEdit;
    EdLandscapeFile: TLabeledEdit;
    EdProjections: TLabeledEdit;
    EdResp: TLabeledEdit;
    EdSDF: TLabeledEdit;
    ImageMol: TImage;
    LblColmin: TLabel;
    LblColmax: TLabel;
    LblEdCumRsp: TLabeledEdit;
    LblEdRsp: TLabeledEdit;
    LblEdPdata: TLabeledEdit;
    LblMolRec: TLabel;
    LCSLevels: TListChartSource;
    CMLandscape: TColorMapSeries;//TODO: prepare another plot and generate a picture P
    LCSViridis: TListChartSource;
    LCSPlasma: TListChartSource;
    LCSInferno: TListChartSource;
    LSRcum: TListChartSource;
    LSEmphasize: TLineSeries;
    CTSMols: TChartToolset;
    CTSMolsDataPointClickTool: TDataPointClickTool;
    CTSMolsDataPointCrosshairTool: TDataPointCrosshairTool;
    LBSamples: TBubbleSeries;
    LCSEmphasize: TListChartSource;
    LCSMols: TListChartSource; //TODO: use the landscape picture P as background
    LCSSamples: TListChartSource;
    LSPrj: TLineSeries;
    LSRorg: TListChartSource;
    MaskEditGoto: TMaskEdit;
    MmLog: TMemo;
    ODlgLandscapeFile: TOpenDialog;
    ODlgGTMFile: TOpenDialog;
    ODlgProjections: TOpenDialog;
    ODlgResp: TOpenDialog;
    ODlgSVM: TOpenDialog;
    ODSDF: TOpenDialog;
    SDSavePlot: TSaveDialog;
    TglBxLog: TToggleBox;
    TglBxPrj: TToggleBox; //TODO: Replace toggle box by a checkboxes.
    TglBxZoomBox: TToggleBox;
    LandscapePNG: TRasterImage;//To be interpreted as a PNG.
    ToggleBox1: TToggleBox;
    procedure BtGTMClick(Sender: TObject);
    procedure BtLandscapeFileClick(Sender: TObject);
    procedure BtOKClick(Sender: TObject);
    procedure BtProjectionsClick(Sender: TObject);
    procedure BtQuitClick(Sender: TObject);
    procedure BtRespClick(Sender: TObject);
    procedure BtSavePlotClick(Sender: TObject);
    procedure BtSDFClick(Sender: TObject);
    procedure BtSVMClick(Sender: TObject);
    procedure BtUpdateClick(Sender: TObject);
    procedure BtZoomClick(Sender: TObject);
    procedure CBColorspaceSelect(Sender: TObject);
    procedure CBLandscapesSelect(Sender: TObject);
    procedure ChGTMLatentAfterDraw(ASender: TChart; ADrawer: IChartDrawer);
    procedure ChPrjBeforeCustomDrawBackWall(ASender: TChart;
      ADrawer: IChartDrawer; const ARect: TRect; var ADoDefaultDrawing: Boolean
      );
    procedure ChPrjExtentChanged(ASender: TChart);
    procedure ChPrjResize(Sender: TObject);
    procedure ChScaleAfterDraw(ASender: TChart; ADrawer: IChartDrawer);
    procedure ChToolCumRspDataPointHintTool1Hint(ATool: TDataPointHintTool;
      const APoint: TPoint; var AHint: String);
    procedure CMGradientCalculate(const AX, AY: Double; out AZ: Double);
    procedure CTSMolsDataPointClickToolPointClick(ATool: TChartTool;
      APoint: TPoint);
    procedure CTSMolsUserDefinedTool1AfterMouseDown(ATool: TChartTool;
      APoint: TPoint);
    procedure CTSMolsUserDefinedTool1AfterMouseMove(ATool: TChartTool;
      APoint: TPoint);
    procedure CTSMolsUserDefinedTool1AfterMouseUp(ATool: TChartTool;
      APoint: TPoint);
    procedure EdColmaxEditingDone(Sender: TObject);
    procedure EdColminEditingDone(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure CMLandscapeCalculate(const AX, AY: Double; out AZ: Double);
    procedure TglBxPrjChange(Sender: TObject);
    procedure TglBxLogChange(Sender: TObject);
    procedure ReadData(sfilename: string);
    procedure FillCBLandscape(sfilename: string);
    procedure PopulateColorSource;
    procedure MolChange();
    procedure MolChange(Sid:integer);
    procedure BitBtnFirstClick(Sender: TObject);
    procedure BitBtnGoToClick(Sender: TObject);
    procedure BitBtnLastClick(Sender: TObject);
    procedure BitBtnLeftClick(Sender: TObject);
    procedure BitBtnRightClick(Sender: TObject);
    procedure CBPropChange(Sender: TObject);
    procedure TglBxZoomBoxChange(Sender: TObject);
  private
    ncells: integer;
    fmatX: TMatrix;
    {bDrawTess,} bRsp, bPrj, bSDF: boolean;
    dmin, dmax, dmin2: double; //landscape min and max values, dmin2 is second smallest dmin
    dminC: double; //min distances between 2 nodes
    fcolmin,fcolmax: TColor;
    //
    fLMolPropList,fLMolPropValIdx: TStringList;
    fMolPropVal: array of string;
    fLLvec: TVector; // A vector that should contain the likelihood of each compound
    fMxRvec,fMxRvec0,fMxRvec1: TVector; // A vector that should contain the maximum responsibility of each compound and backup
    fNodeMxRvec: TIntVector; // A vector that contains the node ID of this maximum
    //
    fsdfslurp, ftmpmolsdf: TStringList;
    fLMolIndex: TIntegerList;
    fPrjToMolIndex: TIntegerList;//Mapping of projection data to a given molecule index
    fmoldr: TMol2DVec;
    fCurrMol: integer;
    //
    fCustRect: TRect;
  public
    bDrawTess, bDrawGrdt: boolean;
  end;

var
  FrmxGTMLandscape: TFrmxGTMLandscape;

implementation

{$R *.lfm}

{ TFrmxGTMLandscape }

procedure TFrmxGTMLandscape.BtQuitClick(Sender: TObject);
begin
  {$IfDef DARWIN}Halt;{$EndIf}
  {$IfNDef DARWIN}Application.Terminate;{$EndIf}
end;

procedure TFrmxGTMLandscape.BtRespClick(Sender: TObject);
var
  sSDFF,sPrjF: string;
begin
  if ODlgResp.Execute then
    EdResp.Text := ODlgResp.FileName;
  sPrjF:=Copy(EdResp.Text,0,Length(EdResp.Text)-5)+'Prj.mat';
  sSDFF:=Copy(EdResp.Text,0,Length(EdResp.Text)-5)+'.sdf';
  if FileExists(sPrjF) then EdProjections.Text:=sPrjF;
  if FileExists(sSDFF) then EdSDF.Text:=sSDFF;
  bRsp:=True;
end;

procedure TFrmxGTMLandscape.BtSavePlotClick(Sender: TObject);
var
  splot: string;
begin
  //DEBUG
  //writeln('BtSavePlotClick');
  if SDSavePlot.Execute then
  begin
    splot:=SDSavePlot.FileName;
    if LandscapePNG<>nil then//bDrawTess then
      LandscapePNG.SaveToFile(splot)
    else
      ChGTMLatent.SaveToFile(TPortableNetworkGraphic,splot);
  end;
end;

procedure TFrmxGTMLandscape.BtSDFClick(Sender: TObject);
begin
  if ODSDF.Execute then
    EdSDF.Text := ODSDF.FileName;
  bSDF:=True;
end;

procedure TFrmxGTMLandscape.BtSVMClick(Sender: TObject);
var
  sSDFF,sPrjF: string;
begin
  if ODlgSVM.Execute then
    EdSVM.Text := ODlgSVM.FileName;
  sPrjF:=Copy(EdSVM.Text,0,Length(EdSVM.Text)-5)+'Prj.mat';
  sSDFF:=Copy(EdSVM.Text,0,Length(EdSVM.Text)-5)+'.sdf';
  if FileExists(sPrjF) then EdProjections.Text:=sPrjF;
  if FileExists(sSDFF) then EdSDF.Text:=sSDFF;
  bRsp:=True;
end;

procedure TFrmxGTMLandscape.BtUpdateClick(Sender: TObject);
var
  dRcut: double;
//  v: double;
  i: integer;
begin
  //Beware that the MolIndex and index of data point on the plot may differ and lead to out of bonds errors
  {for i:=1 to High(fMxRvec) do
    MmLog.Lines.Add('i='+IntToStr(i)+' Rmax='+FloatToStr(fMxRvec[i]));}
  if TryStrToFloat(LblEdRsp.Text,dRcut) then begin
    if TglBxZoomBox.Checked then
    begin
//      for i:=45 to 55 do
//        v:=fLLvec[i];
      for i:=Low(fMxRvec) to High(fMxRvec) do
        fMxRvec[i]:=fMxRvec1[i];
      LoadPrjSeries(EdProjections.Text,fMxRvec,LCSMols,fPrjToMolIndex,dRcut);
      //LoadPrjSeries(EdProjections.Text,fLLvec,LCSMols,fPrjToMolIndex,dRcut);
    end else
    begin
      for i:=Low(fMxRvec) to High(fMxRvec) do
        fMxRvec[i]:=fMxRvec0[i];
      LoadPrjSeries(EdProjections.Text,EdResp.Text,LCSMols,fPrjToMolIndex,dRcut);
    end;
      //LoadPrjSeries(EdProjections.Text,EdResp.Text,LCSMols,fPrjToMolIndex,dRcut);
  end;
  PlotRCum(fMxRvec,High(fMxRvec),LSRcum,LSRorg,MmLog); Application.ProcessMessages;
end;

procedure TFrmxGTMLandscape.BtZoomClick(Sender: TObject);
var
  CurrDir,ExeName,CmdOut: string;
  CmdArgs: array of TProcessString;
begin
  CurrDir:=GetCurrentDir;
  //ExeName:=GetCurrentDir+DirectorySeparator+'..'+DirectorySeparator+'..'+DirectorySeparator
  //+'GTMNodeSelect';
  //ExeName:=ExeName+DirectorySeparator+'xGTMNodeSelect';
  ExeName:='xGTMNodeSelect';
  {$IfDef WINDOWS}ExeName:=ExeName+'.exe';{$EndIf}
  CmdArgs:=[EdtLeft.Text,EdtRight.Text,EdtBottom.Text,EdtTop.Text,LblEdPdata.Text,EdGTM.Text,EdSVM.Text,EdSDF.Text,Copy(EdGTM.Text,1,RPos('.',EdSVM.Text)-1)+'.prp'];
  RunCommandIndir(CurrDir,ExeName,CmdArgs,CmdOut);
  MmLog.Lines.Add('...Process ended... '+CmdOut); Application.ProcessMessages;
end;

{procedure TFrmxGTMLandscape.BtZoomClick(Sender: TObject);
// The zoomed manifold is computed here.
var
  acGTM, zcGTM: TcGTM;
  aGTMXML: TGTMXML;
  SLMols: TLLStringList;
  ik: Integer;
  xmin, xmax, ymin, ymax: Double;
  thrld: Double;
  snodes: String;
  soutfiles: String;
  XT : TMatrix;
  LLt,LLtmin: Double;
  SLtmp,SLlog: TStringList;
  MaxIter: Integer;
begin
  SLlog:=TStringList.Create;
  SLtmp:=TStringList.Create;
  // Restrict the application to full size GTM
  acGTM:=TcGTM.Create;
  acGTM.Restart:=True;//This GTM is supposed to have been already trained
  aGTMXML:=TGTMXML.Create;
  aGTMXML.ReadGTMModel(acGTM,EdGTMFile.Text);
  FreeAndNil(aGTMXML);
  //Node selection
  MmLog.Lines.Add('Submanifold definition...'); Application.ProcessMessages;
  xmin:=StrToFloat(EdtLeft.Text);
  xmax:=StrToFloat(EdtRight.Text);
  ymin:=StrToFloat(EdtBottom.Text);
  ymax:=StrToFloat(EdtTop.Text);
  if (xmin>=xmax) or (ymin>=ymax) then begin
    Exception.Create('ERROR: wrong range value: '+FormatFloat('##.##',xmin)+','+FormatFloat('##.##',ymin)+','+FormatFloat('##.##',xmax)+','+FormatFloat('##.##',ymax));
    Halt;
  end;
  //
  MmLog.Lines.Add('Concerned nodes ID:');
  snodes:=' ';//snodes: string of selected nodes IDs
  for ik:=1 to acGTM.K do begin //SelNode=TRUE -> node is selected to be used for projection and it is updatable during optimization
    if (acGTM.matX[ik,1]>=xmin) and (acGTM.matX[ik,1]<=xmax) and (acGTM.matX[ik,2]>=ymin) and (acGTM.matX[ik,2]<=ymax) then begin
      acGTM.SelNode[ik]:=True;
      snodes:=snodes+IntToStr(ik)+' ';
    end
    else
      acGTM.SelNode[ik]:=False;
  end;
  MmLog.Lines.Add('('+snodes+')'); Application.ProcessMessages;
  //
  //Load the molecules into the molecule list and the GTM.
  SLmols:=TLLStringList.Create;
  SLmols.LoadFromFile(EdMolDesc.Text);
  acGTM.ReadMols(EdMolDesc.Text);
  thrld:=StrToFloat(LblEdPdata.Text);
  RestrictedLikelyhood(SLmols,acGTM,thrld,XT,LLt,LLtmin,SLtmp,SLlog);
  MmLog.Lines.Add(SLlog.Text);
  SLlog.Clear;
  //
  soutfiles:=Copy(EdMolDesc.Text,0,Length(EdMolDesc.Text)-4);
  //Output the selected molecules sorted according to their likelyhood int the file *_Sorted.svm
  SLmols.SaveToFile(soutfiles+'_Sorted.svm');
  //Output the selected molecules in a their orignial order and save them in the file *_NotSorted.svm
  SLtmp.SaveToFile(soutfiles+'_NotSorted.svm');
  SLtmp.Clear;
  //
  MmLog.Lines.Add('Descriptors have been saved as: '+soutfiles+'_Sorted.svm and '+soutfiles+'_NotSorted.svm');
  //
  MaxIter:=0; // MaxIter, number of optimisation iterations of the GTM. Zero: do not optimize
  zcGTM:=TcGTM.Create;
  SLlog.Clear;
  DoZoomOnGTM(acGTM,zcGTM,xmax,xmin,ymax,ymin,XT,SLlog,MaxIter);
  MmLog.Lines.Add(SLlog.Text);
  SLlog.Clear;
  MmLog.Lines.Add('Projections have ended successfully on the zoomed manifold');
   //Save responsabilities and projections
  WriteGTMMat(zcGTM,soutfiles+'_zoom',False,True);
  //
  FreeAndNil(SLmols);
  FreeAndNil(acGTM);
  FreeAndNil(zcGTM);
  FreeAndNil(SLtmp);
  FreeAndNil(SLlog);
end;}

procedure TFrmxGTMLandscape.CBColorspaceSelect(Sender: TObject);
begin
  if bDrawGrdt then begin
    bDrawTess:=True;
    PopulateColorSource;
  end;
end;

procedure TFrmxGTMLandscape.CBLandscapesSelect(Sender: TObject);
begin
  //DEBUG
  //writeln('CBLandscapeSelect');
  bDrawTess:=True;
  bDrawGrdt:=True;
  ReadData(EdLandscapeFile.Text);
  PopulateColorSource;
end;

procedure TFrmxGTMLandscape.ChGTMLatentAfterDraw(ASender: TChart;
  ADrawer: IChartDrawer);
begin
  bDrawTess:=False;
end;

procedure TFrmxGTMLandscape.ChPrjBeforeCustomDrawBackWall(ASender: TChart;
  ADrawer: IChartDrawer; const ARect: TRect; var ADoDefaultDrawing: Boolean);
var
   img: TLazIntfImage;
begin
  if {bDrawTess and} (LandscapePNG<>nil) then
  begin
    img:=TLazIntfImage.Create(LandscapePNG.RawImage,False);
    ADrawer.PutImage(0,0,img);
    ADoDefaultDrawing:=False;
    FreeAndNil(img);
  end;
end;

procedure TFrmxGTMLandscape.ChPrjExtentChanged(ASender: TChart);
var
   aXmin,aXmax,aYmin,aYmax: double;
   a,b: double;
begin
  if length(fmatX)>3 then
  begin
    aXmin:=ChPrj.CurrentExtent.a.X;
    aXmax:=ChPrj.CurrentExtent.b.X;
    aYmin:=ChPrj.CurrentExtent.a.Y;
    aYmax:=ChPrj.CurrentExtent.b.Y;
    //
    ChGTMLatent.AxisList.Axes[0].Range:=ChPrj.AxisList.Axes[0].Range;
    ChGTMLatent.AxisList.Axes[1].Range:=ChPrj.AxisList.Axes[1].Range;
    //
    bDrawTess:=True; //If landscape is setup
    bDrawGrdt:=True;
    ChGTMLatent.Extent.XMin:=aXmin;//-0.5;//ChPrj.Extent.XMin;
    ChGTMLatent.Extent.XMax:=aXMax;//0.5;//ChPrj.Extent.XMax;
    ChGTMLatent.Extent.YMin:=aYmin;//-0.5;//ChPrj.Extent.YMin;
    ChGTMLatent.Extent.YMax:=aYmax;//0.5;//ChPrj.Extent.YMax;
    CMLandscape.Extent.XMin:=aXmin;//-0.5;//ChPrj.Extent.XMin;
    CMLandscape.Extent.XMax:=aXmax;//0.5;//ChPrj.Extent.XMax;
    CMLandscape.Extent.YMin:=aYmin;//-0.5;//ChPrj.Extent.YMin;
    CMLandscape.Extent.YMax:=aYmax;//0.5;//ChPrj.Extent.YMax;
    //
    ChGTMLatent.MarginsExternal:=ChPrj.MarginsExternal;
    ChGTMLatent.Margins:=ChPrj.Margins;
    ChGTMLatent.LeftAxis:=ChPrj.LeftAxis;
    ChGTMLatent.BottomAxis:=ChPrj.BottomAxis;
    //
    PopulateColorSource;
  end;
//Seems that it does not work this way
  //PopulateColorSource;
{  ChGTMLatent.Repaint;
  LandscapePNG:=ChGTMLatent.SaveToImage(TPortableNetworkGraphic);
  {$IFDEF UNIX}
  ChPrj.Repaint;
  {$ENDIF}
  {$IFDEF WINDOWS}
  ChPrj.Repaint;
  {$ENDIF}
}
end;

procedure TFrmxGTMLandscape.ChPrjResize(Sender: TObject);
begin
  if length(fmatX)>3 then
  begin
    bDrawTess:=True; //If landscape is setup
    bDrawGrdt:=True;
  end;
  LandscapePNG:=ChGTMLatent.SaveToImage(TPortableNetworkGraphic);
  {$IFDEF UNIX}
  ChPrj.Repaint;
  {$ENDIF}
  {$IFDEF WINDOWS}
  ChPrj.Repaint;
  {$ENDIF}
end;

procedure TFrmxGTMLandscape.ChScaleAfterDraw(ASender: TChart;
  ADrawer: IChartDrawer);
begin
  bDrawGrdt:=True;
end;

procedure TFrmxGTMLandscape.ChToolCumRspDataPointHintTool1Hint(
  ATool: TDataPointHintTool; const APoint: TPoint; var AHint: String);
var
  PI: Integer;
  SL1, SL2: TLineSeries;
  r,p,t: double;
begin
  PI:=ATool.PointIndex;
  SL1:=ChCumRspLS1; //ATool.Series as TLineSeries;
  SL2:=ChOrgRspLS1;
  r:=SL1.GetXValue(PI);
  p:=SL1.GetYValue(PI);
  t:=SL2.GetXValue(PI);
  AHint:='frac. top data: '+FloatToStr(1-p)+' C. Rsp: '+FloatToStr(r);
  LblEdCumRsp.Text:=FloatToStr(r);
  LblEdPdata.Text:=FloatToStr(1-p);
  LblEdRsp.Text:=FloatToStr(t);
end;

procedure TFrmxGTMLandscape.CMGradientCalculate(const AX, AY: Double; out
  AZ: Double);
var
  ext: TDoubleRect;
begin
  if bDrawGrdt then
    AZ:=AX;
end;

procedure TFrmxGTMLandscape.CTSMolsDataPointClickToolPointClick(
  ATool: TChartTool; APoint: TPoint);
var
  clicktool: TDatapointClickTool;
  i,ii: integer;
begin
  //if ser.Title='Projections' then
  if LSPrj.Active then
  begin
    clicktool := TDatapointClickTool(ATool);
    ii:=clicktool.PointIndex;   // Point index of the nearest data point
    i:=fPrjToMolIndex[ii];
    if (i>=0) and (i<=fLMolIndex.Count-2) then
    begin
      fCurrMol:=i;
      MaskEditGoto.Text:=IntToStr(fCurrMol+1);
      MolChange(ii);
    end;
  end;
end;

procedure TFrmxGTMLandscape.CTSMolsUserDefinedTool1AfterMouseDown(
  ATool: TChartTool; APoint: TPoint);
var
  ax, ay: double;
begin
  ax:=ChPrj.ImageToGraph(APoint).X;
  ay:=ChPrj.ImageToGraph(APoint).Y;
  fCustRect:=Rect(APoint.X,APoint.Y,APoint.X,APoint.Y);
  LSZoomTag1.Clear;
  LSZoomTag1.AddXY(ax,ay);
  LSZoomTag1.AddXY(ax,ay);
  LSZoomTag1.Active:=True;
end;

procedure TFrmxGTMLandscape.CTSMolsUserDefinedTool1AfterMouseMove(
  ATool: TChartTool; APoint: TPoint);
var
  ax, ay: double;
begin
  ax:=ChPrj.ImageToGraph(APoint).X;
  ay:=ChPrj.ImageToGraph(APoint).Y;
  //
  LSZoomTag1.SetXValue(1,ax);
  LSZoomTag1.SetYValue(1,ay);
  //
end;

procedure TFrmxGTMLandscape.CTSMolsUserDefinedTool1AfterMouseUp(
  ATool: TChartTool; APoint: TPoint);
var
  acGTM: TcGTM;
  aGTMXML: TGTMXML;
  LLt: double;
  xmin,xmax,ymin,ymax: double;
  ii,ik: integer;
  snodes:string;
  //---
  sTop,sLeft,sRight,sBottom: string;
  Point0, Point1: TPoint;
  aBrush: TBrush;
procedure PointToRect(Point0, Point1: TPoint; var aRect:TRect);
//Reorder Point0 and Point 1 so they correspond to opposite corners of a rectangle
begin
  if Point0.X=Point1.X then Point1.X:=Point0.X+1;
  if Point0.Y=Point1.Y then Point1.Y:=Point0.Y-1;
  if Point0.X<Point1.X then
  begin
    aRect.Left:=Point0.X;
    aRect.Right:=Point1.X;
    if Point0.Y<Point1.Y then
    begin
      aRect.Top:=Point0.Y;
      aRect.Bottom:=Point1.Y;
    end else
    begin
      aRect.Top:=Point1.Y;
      aRect.Bottom:=Point0.Y;
    end;
  end else
  begin
    aRect.Left:=Point1.X;
    aRect.Right:=Point0.X;
    if Point0.Y<Point1.Y then
    begin
      aRect.Top:=Point0.Y;
      aRect.Bottom:=Point1.Y;
    end else
    begin
      aRect.Top:=Point1.Y;
      aRect.Bottom:=Point0.Y;
    end;
  end;
end;
begin
  //
  LSZoomTag1.Active:=False; //Hide the helper series
  //
  Point0:=fCustRect.TopLeft;
  Point1:=APoint;
  PointToRect(Point0,Point1,fCustRect);// Defines a rectangle from the two positions
  // Record the selected rectangle in the interface
  sLeft:=FloatToStrF(ATool.Chart.ImageToGraph(fCustRect.TopLeft).X,ffGeneral,2,4);
  sTop:=FloatToStrF(ATool.Chart.ImageToGraph(fCustRect.TopLeft).Y,ffGeneral,2,4);
  sRight:=FloatToStrF(ATool.Chart.ImageToGraph(fCustRect.BottomRight).X,ffGeneral,2,4);
  sBottom:=FloatToStrF(ATool.Chart.ImageToGraph(fCustRect.BottomRight).Y,ffGeneral,2,4);
  EdtLeft.Text:=sLeft;
  EdtTop.Text:=sTop;
  EdtRight.Text:=sRight;
  EdtBottom.Text:=sBottom;
  // Make the zoom buttons visible to the useer
  LblZoomZone.Visible:=True;
  TglBxZoomBox.Visible:=True;
  BtZoom.Visible:=True;
  EdtLeft.Visible:=True;
  EdtTop.Visible:=True;
  EdtRight.Visible:=True;
  EdtBottom.Visible:=True;
  //
  //Compute restricted likelihood ---- Should be in the end of a selection
  // Restrict the application to full size GTM
  acGTM:=TcGTM.Create;
  acGTM.Restart:=True;//This GTM is supposed to have been already trained
  aGTMXML:=TGTMXML.Create;
  aGTMXML.ReadGTMModel(acGTM,EdGTM.Text);
  FreeAndNil(aGTMXML);
  // Node selection
  MmLog.Lines.Add('Submanifold definition...'); MmLog.SelStart:=Length(MmLog.Text); Application.ProcessMessages;
  xmin:=StrToFloat(EdtLeft.Text);
  xmax:=StrToFloat(EdtRight.Text);
  ymin:=StrToFloat(EdtBottom.Text);
  ymax:=StrToFloat(EdtTop.Text);
  //
  MmLog.Lines.Add('Concerned nodes ID:');
  snodes:=' ';//snodes: string of selected nodes IDs
  for ik:=1 to acGTM.K do begin //SelNode=TRUE -> node is selected to be used for projection and it is updatable during optimization
    if (acGTM.matX[ik,1]>=xmin) and (acGTM.matX[ik,1]<=xmax) and (acGTM.matX[ik,2]>=ymin) and (acGTM.matX[ik,2]<=ymax) then begin
      acGTM.SelNode[ik]:=True;
      snodes:=snodes+IntToStr(ik)+' ';
    end
    else
      acGTM.SelNode[ik]:=False;
  end;
  MmLog.Lines.Add('('+snodes+')'); MmLog.SelStart:=Length(MmLog.Text); Application.ProcessMessages;
  // Update the fMxRvec so that it contains a measurable responsibility only on selected nodes
  for ii:=1 to High(fNodeMxRvec) do
  begin
    ik:=fNodeMxRvec[ii];
    if not acGTM.SelNode[ik] then
      fMxRvec[ii]:=0 //Cancels the responsibility of compounds whose max responsibility in not in selected nodes
    else
      fMxRvec[ii]:=fMxRvec0[ii]; // Else recover the max responsibility from the backup
  end;
  for ii:=1 to High(fNodeMxRvec) do
    fMxRvec1[ii]:=fMxRvec[ii]; // Save the selected max responsibility as backup
  //
  acGTM.ReadMols(EdSVM.Text);
  acGTM.Init;
  acGTM.Project(True,True,True,True); // Here the manifold is already set and projection can be done on selected nodes
  LLt:=acGTM.LogLikelyHoodOnSelected();
  {for ii:=1 to acGTM.N do begin// Copy the molecules likelihood and max responsibility in the fLLvec and fMxRvec vectors for ploting and filtering
    MmLog.Lines.Add('ii='+IntToStr(ii)+' MxR='+FloatToStr(aCGTM.MxR(ii))+' NodeMxR='+IntToStr(acGTM.NodeMxR(ii)));
    fMxRvec[ii]:=acGTM.MxR(ii);//Max responsibility of the molecule
    fLLvec[ii]:=acGTM.LLM[ii];
  end;}
  MmLog.Lines.Add('Likelihood of all data on the restricted manifold: '+FloatToStr(LLt)); MmLog.SelStart:=Length(MmLog.Text); Application.ProcessMessages;
  //
  PlotRCum(fMxRvec,acGTM.N,LSRcum,LSRorg,MmLog); Application.ProcessMessages;
  //PlotRCum(fLLvec,acGTM.N,LSRcum,LSRorg,MmLog); Application.ProcessMessages;
  //
  FreeAndNil(acGTM);
end;

procedure TFrmxGTMLandscape.EdColmaxEditingDone(Sender: TObject);
var
  s: string;
begin
  s:=Trim(EdColmax.Text);
  if (s<>'') then
  begin
    try
      fcolmax:=StringToColor(s);
      bDrawTess:=True;
      PopulateColorSource;
      bDrawTess:=False;
    except
      EdColmax.Text:='clBlue';
    end;
  end;
end;

procedure TFrmxGTMLandscape.EdColminEditingDone(Sender: TObject);
var
  s: string;
begin
  s:=Trim(EdColmin.Text);
  if (s<>'') then
  begin
    try
      fcolmin:=StringToColor(s);
      bDrawTess:=True;
      PopulateColorSource;
      bDrawTess:=False;
    except
      EdColmin.Text:='clRed';
    end;
  end;
end;

procedure TFrmxGTMLandscape.FormCreate(Sender: TObject);
begin
  //SLColors := TStringList.Create;
  DimMatrix(fmatX, 0, 0);
  bDrawTess := False;
  bDrawGrdt := False;
  bRsp:=False;
  bPrj:=False;
  bSDF:=False;
  dmin := MaxDouble;
  dmax := MinDouble;
  dminC:= MaxDouble;
  fcolmin:=clCream;
  fcolmax:=clBlack;
  LandscapePNG:=nil;
  fLLvec:=nil;
  fMxRvec:=nil;
  //debug - start
  EdGTM.Text:='';
  EdLandscapeFile.Text:='';
  EdProjections.Text:='';
  EdResp.Text:='';
  EdSVM.Text:='';
  EdSDF.Text:='';

  {
  EdGTM.Text:='/home/marcou/workdir/ISIDAGTM2024/GTMLandscape/xGTMLandscape/example/IUPHAR-5HT2B-33map.xml';
  EdLandscapeFile.Text:='/home/marcou/workdir/ISIDAGTM2024/GTMLandscape/xGTMLandscape/example/IUPHAR-5HT2B-33_pKi.xml';
  EdProjections.Text:='/home/marcou/workdir/ISIDAGTM2024/GTMLandscape/xGTMLandscape/example/IUPHAR-5HT2B-33mapPrj.mat';
  EdResp.Text:='/home/marcou/workdir/ISIDAGTM2024/GTMLandscape/xGTMLandscape/example/IUPHAR-5HT2B-33mapR.svm';
  EdSVM.Text:='/home/marcou/workdir/ISIDAGTM2024/GTMLandscape/xGTMLandscape/example/IUPHAR-5HT2B-33_E_IIAB_R(2-4)_FC.svm';
  EdSDF.Text:='/home/marcou/workdir/ISIDAGTM2024/GTMLandscape/xGTMLandscape/example/IUPHAR-5HT2B-33.sdf';
  }
  //debug - end
  fLMolPropList:=TStringList.Create;
  fLMolPropList.Duplicates:=dupIgnore;
  fLMolPropList.Sorted:=True;
  fLMolPropValIdx:=TStringList.Create;
  fLMolPropValIdx.Duplicates:=dupIgnore;
  fLMolPropValIdx.Sorted:=True;
  fPrjToMolIndex:=TIntegerList.Create;
  //
  fCurrMol:=-1;
  fsdfslurp := TStringList.Create;
  ftmpmolsdf := TStringList.Create;
  fLMolIndex := TIntegerList.Create;
  fmoldr := TMol2DVec.Create;
  fmoldr.VMolWidth := ImageMol.Width;
  fmoldr.VMolHeight := ImageMol.Height;
  fmoldr.VMolPage.Clear;
  //
  //for i:=0 to CGPlots.Items.Count-1 do
  //  CGPlots.CheckEnabled[i]:=False;
end;

procedure TFrmxGTMLandscape.FormDestroy(Sender: TObject);
begin
  DimMatrix(fmatX, 0, 0);
  bDrawTess := False;
  bDrawGrdt := False;
  bRsp:=False;
  bPrj:=False;
  bSDF:=False;
  //
  FreeAndNil(LandscapePNG);
  //
  FreeAndNil(fLMolPropList);
  FreeAndNil(fLMolPropValIdx);
  FreeAndNil(fPrjToMolIndex);
  //
  FreeAndNil(fLMolIndex);
  FreeAndNil(fsdfslurp);
  FreeAndNil(ftmpmolsdf);
  FreeAndNil(fmoldr);
end;

procedure TFrmxGTMLandscape.CMLandscapeCalculate(const AX, AY: Double; out
  AZ: Double);
var
  d,dstmin: double;
  imin: integer;
  i:integer;
function Rescale(d: double): double;
//Rescale AZ to scale inside limits of the color map
begin
  Result:=d;
  if d<=LCSLevels.Item[1]^.GetX(0) then
    Result:=LCSLevels.Item[1]^.GetX(0)+DEFAULT_EPSILON
  else if d>=LCSLevels.Item[2]^.GetX(0) then
    Result:=LCSLevels.Item[2]^.GetX(0)-DEFAULT_EPSILON;
end;
begin
  if bDrawTess then
  begin
    imin:=-1;
    dstmin:=MaxDouble;
    i:=1;
    while (i<=ncells) and (dstmin>dminC) do // dstmin>dminC: the node closest to AX,AY has been found
    begin
      d:=sqr(fmatX[i,1]-AX)+sqr(fmatX[i,2]-AY);
      if d<dstmin then
      begin
        dstmin:=d;
        imin:=i;
      end;
      inc(i);
    end;
    {for i:=1 to ncells do
    begin
      d:=sqr(fmatX[i,1]-AX)+sqr(fmatX[i,2]-AY);
      if d<dstmin then
      begin
        dstmin:=d;
        imin:=i;
      end;
    end;}
    AZ:=-Infinity;
    // Modified by Fanny 14-06-2024
    // IMPORTANT, in case of bug : In Lazarus component tacolormap.pas, add the following lines of code, line 210:
    {
    else
      try
         if (not IsNaN(v1)) and (not IsInfinite(v1)) and (not IsNaN(v2)) and (not IsInfinite(v2)) and (not IsNaN(Avalue)) and (not IsInfinite(AValue))then
            Result := InterpolateRGB(c1, c2, (AValue - v1) / (v2 - v1));
      finally
      end;
    }
    // if (fmatX[imin,3]<>NaN) and (fmatX[imin,3]<>-Infinity) and (fmatX[imin,3]<>Infinity) then
    if (not IsNaN(fmatX[imin,3])) and (not IsInfinite(Abs(fmatX[imin,3]))) then
    begin //Properly manage speacial real values
      if not TglBxLog.Checked then
      begin
        AZ:=Rescale(fmatX[imin,3]); //Set the value of the pixel to the closest GTM node value (Voronoi cell). Ensure the result is in color range.
      end else
      begin
        if fmatX[imin,3]>dmin then
        begin
          AZ:=Rescale(log10(fmatX[imin,3]-dmin));
        end
        else
          AZ:=-Infinity;
      end;
    end;
  end;
end;

procedure TFrmxGTMLandscape.TglBxPrjChange(Sender: TObject);
begin
  //DEBUG
  //writeln('TglBxPrjChange');
  //From show projections to hide projections
  if TglBxPrj.Checked then
  begin
    //bDrawTess:=True;
    CMLandscape.Active:=True;
    TglBxPrj.Color := clBtnShadow;
    TglBxPrj.Caption := 'Show projections';
    LSPrj.Active:=False;
    LSEmphasize.Active:=False;
  end
  else
  begin
    //bDrawTess:=True;
    CMLandscape.Active:=False;
    TglBxPrj.Color := clDefault;
    TglBxPrj.Caption := 'Hide projections';
    LSPrj.Active:=True;
    LSEmphasize.Active:=True;
  end;
end;

procedure TFrmxGTMLandscape.TglBxLogChange(Sender: TObject);
begin
  //DEBUG
  //writeln('TglBxLogChange');
  //From log scale to non-log scale
  bDrawTess:=True;
  bDrawGrdt:=True;
  if TglBxLog.Checked then
  begin
    TglBxLog.Color := clBtnShadow;
    TglBxLog.Caption := 'No log scale';
  end
  else
  begin
    TglBxLog.Color := clDefault;
    TglBxLog.Caption := 'Log scale';
  end;
  ReadData(EdLandscapeFile.Text);
  PopulateColorSource;
end;

procedure TFrmxGTMLandscape.ReadData(sfilename: string);
var
  fr: double;
  dtmp: double;
  i,j: integer;
  slandscape: string;
  doc: TXMLDocument;
  rootnode: TDOMElement;
  node, anode: TDOMNode;
  nodes: TDOMNodeList;
  snode: string; //string node value
  sattnme,sattval,snodnme: string; //node name, attribute name and attribute value
  SLColors: TStringList;
  bFound: boolean;
  s: string;
procedure CleanUp(s: string);
begin
  raise Exception.Create('ERROR: node '+s+' not found');
  FreeAndNil(doc);
  FreeAndNil(SLColors);
end;
function FindNode(aNode: TDOMElement; s: string): TDOMNode;
//Search for a node s and cleanup memory if found
begin
  Result:=aNode.FindNode(s);
  if Result=nil then
    CleanUp(s);
end;

begin
  //DEBUG
  //writeln('ReadData');
  if CBLandscapes.ItemIndex<0 then //If no landscape is selected do nothing
  begin
    bDrawTess:=False;
    bDrawGrdt:=False;
    exit;
  end;
  fcolmin:=clRed;
  fcolmax:=clBlue;
  //CMGradient.BuiltInPalette:=cmpHot;
  //CMLandscape.BuiltInPalette:=cmpHot;
  SLColors:=TStringList.Create;
  slandscape:=CBLandscapes.Items[CBLandscapes.ItemIndex];
  ReadXMLFile(doc, EdLandscapeFile.Text); //Parse the XML file
  rootnode := doc.DocumentElement;
  anode:=rootnode.FindNode('Landscape');
  if anode=nil then
  begin
    CleanUp('Landscape');
    Exit;
  end;
  //slandscape= nodename attribute=attributevalue
  snodnme:=ExtractWord(1,slandscape,[' ']);
  sattnme:=ExtractWord(2,ExtractWord(1,slandscape,['=']),[' ']);
  sattval:=ExtractWord(2,slandscape,['=']);
  node:=anode.FirstChild;
  bFound:=False;
  while (node<>nil) and (bFound=False) do
  begin
    if node.NodeName=snodnme then
    begin
      if sattnme<>'' then
      begin
        if TDOMElement(node).hasAttribute(sattnme) then
          if TDOMElement(node).GetAttribute(sattnme)=sattval then
            bFound:=True;
        CMGradient.ColorSource:=nil;
        CMLandscape.ColorSource:=nil;
      end else
      begin
        bFound:=True;
        fcolmin:=clCream;
        fcolmax:=clBlack;
        CMGradient.ColorSource:=LCSLevels;
        CMLandscape.ColorSource:=LCSLevels;
        //CMGradient.BuiltInPalette:=cmpMonochrome;
        //CMLandscape.BuiltInPalette:=cmpMonochrome;
      end;
    end;
    if not bFound then node:=node.NextSibling;//if this not this node consider the next one
  end;
  if bFound then
    snode:=node.FirstChild.NodeValue
  else begin
    CleanUp(slandscape);
    exit;
  end;
  //Here snode contain the color
  //Reset and read data
  SLColors.Clear;
  SLColors.CommaText:=snode; //Read color from node string.
  // Load Samples
  for i:=1 to ncells do // Compute the smallest cell radius
    for j:=i+1 to ncells do
    begin
      dtmp:= sqr(fmatX[i, 1]-fmatX[j, 1])+sqr(fmatX[i, 2]-fmatX[j, 2]);
      if dminC > dtmp then dminC:=dtmp;
    end;
  dminC:=dminC/4;
  // radius of projection points
  fr := sqrt(dminC)/5; //1 / (3*sqrt(ncells));
  //writeln('fr=',fr);
  fr:=max(fr,1);
  //
  dmin := MaxDouble; //min and max values to scale the color gradient
  dmax := -MaxDouble;
  dmin2:=dmin;
  //
  for i := 1 to ncells do
  begin
    // Modified by Fanny 14-06-2024
    // dtmp := StrToFloat(SLColors[i-1]); //dtmp is the interpreted value
    if SameText(SLColors[i-1], 'Nan') then
      dtmp := NaN
    else
    begin
      try
        dtmp := StrToFloat(SLColors[i-1]);
      except
        on E: EConvertError do
        begin
          // Handle the conversion error if needed
          dtmp := NaN; // Or any other default value
        end;
      end;
    end;
    fmatX[i, 3] := dtmp;

    // Modified by Fanny 14-06-2024
    if not IsNaN(dtmp) then
    begin
      if dtmp < dmin then
      begin
        dmin2:=dmin;
        dmin := dtmp;
      end else if (dtmp<dmin2) and (dtmp>dmin) then
        dmin2:=dtmp;
      if dtmp > dmax then
        dmax := dtmp;
    end;

  end;
  LCSSamples.Clear;
  for i:=1 to ncells do
  begin
      LCSSamples.AddXYList(fmatX[i, 1], [fmatX[i, 2], 2*fr*(fmatX[i,3]-dmin)/(dmax-dmin)]);
  end;
  //
  bDrawTess := True;
  bDrawGrdt := True;
  //
  FreeAndNil(SLColors);
  FreeAndNil(doc);
end;

procedure TFrmxGTMLandscape.FillCBLandscape(sfilename: string);
var
  doc: TXMLDocument;
  rootnode: TDOMElement;
  nodeLS,node: TDOMNode;
  nodes:TDOMNodeList;
  snode,stmp: string;
  SLlog: TStringList;//temporary string list
  i: integer;//iterator
begin
  //DEBUG
  //writeln('FillCBLandscape');
  SLlog:=TStringList.Create;
  CBLandscapes.Items.Clear;
  ReadXMLFile(doc, EdLandscapeFile.Text); //Parse the XML file
  rootnode := doc.DocumentElement;
  stmp := rootnode.GetAttribute('tool');
  MmLog.Lines.Add('Reading file '+sfilename);
  stmp := rootnode.GetAttribute('tool');
  MmLog.Lines.Add('Tool: '+stmp);
  stmp := rootnode.GetAttribute('title');
  MmLog.Lines.Add('Title: '+stmp);
  stmp := rootnode.GetAttribute('author');
  MmLog.Lines.Add('Author: '+stmp);
  stmp := rootnode.GetAttribute('comment');
  MmLog.Lines.Add('Comment: '+stmp);
  MmLog.Lines.Add('---');
  //
  nodeLS:=rootnode.FindNode('Landscape');
  if nodeLS<>nil then
  begin
    if TDOMElement(nodeLS).hasAttribute('number_of_nodes') then
      stmp:=TDOMElement(nodeLS).GetAttribute('number_of_nodes')
    else
    begin
      raise Exception.Create('ERROR in node Landscape no attribute number_of_nodes.');
      FreeAndNil(SLlog);
      FreeAndNil(doc);
      Exit;
    end;
    ncells:=StrToInt(stmp);
    DimMatrix(fmatX,ncells,3);
  end
  else begin
    Writeln('ERROR parsing XML model: no Landscape found');
    halt;
  end;
  MmLog.Lines.Add('Number of nodes: '+IntToStr(ncells));
  // Going down one level
  node:=nodeLS.FirstChild;
  while(node<>nil) do
  begin
    stmp:=node.NodeName;
    if TDOMElement(node).hasAttribute('class') then
      stmp:=stmp+' class='+TDOMElement(node).GetAttribute('class');
    CBLandscapes.Items.Add(stmp);
    node:=node.NextSibling;
  end;
  nodeLS:=rootnode.FindNode('LatentSamples');
  if (nodeLS<>nil) then
  begin
    SLlog.Clear;
    SLlog.Text:=nodeLS.FirstChild.NodeValue;
    for i:=1 to ncells do
    begin
      fmatX[i,1]:=StrToFloat(ExtractWord(1,SLlog[i-1],[',']));
      fmatX[i,2]:=StrToFloat(ExtractWord(2,SLlog[i-1],[',']));
      fmatX[i,3]:=0;
    end;
  end else
  begin
    raise Exception.Create('ERROR no node LatentSample');
    halt(1);
  end;
  FreeAndNil(SLlog);
  FreeAndNil(doc);
  //
end;

procedure TFrmxGTMLandscape.PopulateColorSource;
const
  DUMMY = 0.0;
var
  i: integer;
  cmin, cmax: double;
begin
  //DEBUG
  //Writeln('PopulateColorSource');
  //Keep LCSLevels in case we need to design a custom colormap
  EdColmin.Text:='';
  EdColmax.Text:='';
  EdColmax.Visible:=False; LblColmax.Visible:=False;
  EdColmin.Visible:=False; LblColmin.Visible:=False;
  //Populate the gradient color map
  if TglBxLog.Checked=False then
  begin
    cmin:=dmin;
    cmax:=dmax;
  end else begin
    cmin:=log10(dmin2-dmin);
    cmax:=log10(dmax-dmin);
  end;
  //
  LCSLevels.Clear;
  LCSLevels.Add(-Infinity ,DUMMY,'',clWhite);
  LCSLevels.Add(cmin,DUMMY,'',fcolmin); //Add colorpoints
  LCSLevels.Add(cmax,DUMMY,'',fcolmax);
  LCSLevels.Add(Infinity ,DUMMY,'',clWhite);
  //
  LCSViridis[0]^.SetX(-Infinity);
  for i:=1 to LCSViridis.Count-2 do
    LCSViridis.Item[i]^.SetX(cmin+(cmax-cmin)*(i-1)/(LCSViridis.Count-3));
  LCSViridis[LCSViridis.Count-1]^.SetX(Infinity);
  LCSPlasma[0]^.SetX(-Infinity);
  for i:=1 to LCSPlasma.Count-2 do
    LCSPlasma.Item[i]^.SetX(cmin+(cmax-cmin)*(i-1)/(LCSPlasma.Count-3));
  LCSPlasma[LCSPlasma.Count-1]^.SetX(Infinity);
  LCSInferno[0]^.SetX(-Infinity);
  for i:=1 to LCSInferno.Count-2 do
    LCSInferno.Item[i]^.SetX(cmin+(cmax-cmin)*(i-1)/(LCSInferno.Count-3));
  LCSInferno[LCSInferno.Count-1]^.SetX(Infinity);
  //
  if bDrawTess then
  begin
    Case CBColorspace.ItemIndex of
      0: begin
        CMGradient.BuiltInPalette:=cmpCold;
        CMGradient.ColorSource:=nil;
      end;
      1: begin
        CMGradient.BuiltInPalette:=cmpHot;
        CMGradient.ColorSource:=nil;
      end;
      2: begin
        CMGradient.BuiltInPalette:=cmpRainbow;
        CMGradient.ColorSource:=nil;
      end;
      3: begin
        CMGradient.BuiltInPalette:=cmpMonochrome;
        CMGradient.ColorSource:=nil;
      end;
      4: begin
        CMGradient.ColorSource:=LCSViridis;
      end;
      5: begin
        CMGradient.ColorSource:=LCSPlasma;
      end;
      6: begin
        CMGradient.ColorSource:=LCSInferno;
      end;
      7: begin
        EdColmax.Visible:=True; LblColmax.Visible:=True;
        EdColmin.Visible:=True; LblColmin.Visible:=True;
        EdColmin.Text:=ColorToString(fcolmin);
        EdColmax.Text:=ColorToString(fcolmax);
        CMGradient.ColorSource:=LCSLevels;
      end;
    end;
    CMGradient.Extent.XMin:=cmin;
    CMGradient.Extent.XMax:=cmax;
    CMGradient.BuiltInPaletteMin:=cmin;
    CMGradient.BuiltInPaletteMax:=cmax;
    CMLandscape.ColorSource:=CMGradient.ColorSource;
    CMLandscape.BuiltInPalette:=CMGradient.BuiltInPalette;//cmpCold; cmpHot; cmpMonochrome; cmpRainbow;
    CMLandscape.BuiltInPaletteMin:=CMGradient.BuiltInPaletteMin;
    CMLandscape.BuiltInPaletteMax:=CMGradient.BuiltInPaletteMax;
  end;
  CMLandscape.Active:=True;
  //
  LandscapePNG:=ChGTMLatent.SaveToImage(TPortableNetworkGraphic);
  ChPrj.Repaint;
end;

procedure TFrmxGTMLandscape.MolChange();
var
  i: integer;
begin
  //bDrawTess:=False;
  CMLandscape.Active:=False;
  //
  ftmpmolsdf.Clear;
  if fLMolIndex.Count>0 then begin
    for i := fLMolIndex[fCurrMol] to fLMolIndex[fCurrMol + 1] - 1 do
      ftmpmolsdf.Add(fsdfslurp[i]);
    fmoldr.VMolPage.Clear;
    fmoldr.DrawMol(ftmpmolsdf);
    fmoldr.WriteToImage(ImageMol);
  end;
  LblMolRec.Caption:='Looking at Record: '+IntToStr(fCurrMol+1)+ ' -|- '+fMolPropVal[fCurrMol+1];
  //
  //Set reticule in ExpPred chart
  if LSPrj.Count<=0 then Exit; // No projection data points are available for selection
  LSPrj.Active:=True;
  LSEmphasize.Active:=True;
  LSEmphasize.ShowPoints:=True;
  If LCSEmphasize.Count<1 then LCSEmphasize.Add(0,0);
  LCSEmphasize.SetXValue(0,LSPrj.GetXValue(fCurrMol));
  LCSEmphasize.SetYValue(0,LSPrj.GetYValue(fCurrMol));
end;

procedure TFrmxGTMLandscape.MolChange(Sid: integer);
var
  i: integer;
begin
  //bDrawTess:=False;
  CMLandscape.Active:=False;
  //
  ftmpmolsdf.Clear;
  if fLMolIndex.Count>0 then begin
    for i := fLMolIndex[fCurrMol] to fLMolIndex[fCurrMol + 1] - 1 do
      ftmpmolsdf.Add(fsdfslurp[i]);
    fmoldr.VMolPage.Clear;
    fmoldr.DrawMol(ftmpmolsdf);
    fmoldr.WriteToImage(ImageMol);
  end;
  LblMolRec.Caption:='Looking at Record: '+IntToStr(fCurrMol+1)+ ' -|- '+fMolPropVal[fCurrMol+1];
  //
  //Set reticule in ExpPred chart
  if LSPrj.Count<=0 then Exit; // No projection data points are available for selection
  LSPrj.Active:=True;
  LSEmphasize.Active:=True;
  LSEmphasize.ShowPoints:=True;
  If LCSEmphasize.Count<1 then LCSEmphasize.Add(0,0);
  LCSEmphasize.SetXValue(0,LSPrj.GetXValue(Sid));
  LCSEmphasize.SetYValue(0,LSPrj.GetYValue(Sid));
end;

procedure TFrmxGTMLandscape.BitBtnFirstClick(Sender: TObject);
begin
  fCurrMol:=0;
  MaskEditGoto.Text:=IntToStr(fCurrMol+1);
  MolChange();
end;  // BitBtnGoToClick

procedure TFrmxGTMLandscape.BitBtnGoToClick(Sender: TObject);
var
  i: integer;
  Code: integer;
begin
  Val(MaskEditGoto.Text, i, Code);
  Dec(i);
  if (Code = 0) and (i>=0) and (i<=fLMolIndex.Count-2) then
  begin
    fCurrMol:=i;
    MolChange();
  end;
end;  // BitBtnGoToClick

procedure TFrmxGTMLandscape.BitBtnLastClick(Sender: TObject);
var
  i: integer;
begin
  i:=fLMolIndex.Count-2;
  fCurrMol:=i;
  MaskEditGoto.Text:=IntToStr(fCurrMol+1);
  MolChange();
end;  // BitBtnGoToClick

procedure TFrmxGTMLandscape.BitBtnLeftClick(Sender: TObject);
var
  i: integer;
begin
  i:=fCurrMol-1;
  if (i>=0) and (i<=fLMolIndex.Count-2) then
  begin
    fCurrMol:=i;
    MaskEditGoto.Text:=IntToStr(fCurrMol+1);
    MolChange();
  end;
end;  // BitBtnLeftClick

procedure TFrmxGTMLandscape.BitBtnRightClick(Sender: TObject);
var
  i: integer;
begin
  i:=fCurrMol+1;
  if (i>=0) and (i<=fLMolIndex.Count-2) then
  begin
    fCurrMol:=i;
    MaskEditGoto.Text:=IntToStr(fCurrMol+1);
    MolChange();
  end;
end;  // BitBtnRightClick

procedure TFrmxGTMLandscape.CBPropChange(Sender: TObject);
var
  i,imol,ibpos,iepos,icol: integer;
  sprop: string;
begin
  //DEBUG
  //writeln('PropChange');
  imol:=0;
  fLMolPropValIdx.Clear;
  for i:=Low(fMolPropVal) to High(fMolPropVal) do fMolPropVal[i]:='';
  for i := 0 to fsdfslurp.Count - 1 do
  begin
    if fsdfslurp[i] = '$$$$' then
      Inc(imol);
    if (POS('>',fsdfslurp[i])=1) then //Property line found
    begin
      ibpos:=POS('<',fsdfslurp[i])+1;
      iepos:=length(fsdfslurp[i]);
      sprop:=Copy(fsdfslurp[i],ibpos,iepos-ibpos);
      if sprop=CBProp.Items[CBProp.ItemIndex] then
      begin
        fLMolPropValIdx.Add(fsdfslurp[i+1]);
        fMolPropVal[imol+1]:=fsdfslurp[i+1];
      end;
    end;
  end;
  MolChange();
end;

procedure TFrmxGTMLandscape.TglBxZoomBoxChange(Sender: TObject);
var
  aTopLeft, aTopRight, aBottomLeft, aBottomRight: TDoublePoint;
begin
  If TglBxZoomBox.Checked then
  begin
    TglBxZoomBox.Caption:='Hide box';
    //
    aTopLeft:=ChPrj.ImageToGraph(fCustRect.TopLeft);
    aBottomRight:=ChPrj.ImageToGraph(fCustRect.BottomRight);
    aTopRight.X:=aBottomRight.X; aTopRight.Y:=aTopLeft.Y;
    aBottomLeft.X:=aTopLeft.X; aBottomLeft.Y:=aBottomRight.Y;
    //
    LSZoomTag1.Clear;
    LSZoomTag1.AddXY(aTopLeft.X,ATopLeft.Y);
    LSZoomTag1.AddXY(aBottomLeft.X,ABottomLeft.Y);
    LSZoomTag1.AddXY(aBottomRight.X,aBottomRight.Y);
    LSZoomTag1.AddXY(aTopRight.X,aTopRight.Y);
    LSZoomTag1.AddXY(aTopLeft.X,ATopLeft.Y);
    LSZoomTag1.Active:=True;
  end else
  begin
    TglBxZoomBox.Caption:='Show box';
    LSZoomTag1.Active:=False;
  end;
end;

procedure TFrmxGTMLandscape.BtLandscapeFileClick(Sender: TObject);
var
  sGTMF,sSVMF,sPrjF,sSDFF,sRspF: string;
begin
  if ODlgLandscapeFile.Execute then
    EdLandscapeFile.Text := ODlgLandscapeFile.FileName;
  sGTMF:=Copy(EdLandscapeFile.Text,0,Length(EdLandscapeFile.Text)-8)+'.xml';
  sSVMF:=Copy(EdLandscapeFile.Text,0,Length(EdLandscapeFile.Text)-8)+'.svm';
  sRspF:=Copy(EdLandscapeFile.Text,0,Length(EdLandscapeFile.Text)-8)+'R.svm';
  sPrjF:=Copy(EdLandscapeFile.Text,0,Length(EdLandscapeFile.Text)-8)+'Prj.mat';
  sSDFF:=Copy(EdLandscapeFile.Text,0,Length(EdLandscapeFile.Text)-8)+'.sdf';
  if FileExists(sGTMF) then EdGTM.Text:=sGTMF;
  if FileExists(sSVMF) then EdSVM.Text:=sSVMF;
  if FileExists(sRspF) then EdResp.Text:=sRspF;
  if FileExists(sPrjF) then EdProjections.Text:=sPrjF;
  if FileExists(sSDFF) then EdSDF.Text:=sSDFF;
end;

procedure TFrmxGTMLandscape.BtGTMClick(Sender: TObject);
var
  sRegF,sClsF,sSVMF,sPrjF,sSDFF,sRspF: string;
begin
  if ODlgGTMFile.Execute then
    EdGTM.Text := ODlgGTMFile.FileName;
  sRegF:=Copy(EdGTM.Text,0,Length(EdGTM.Text)-4)+'_reg.xml';
  sClsF:=Copy(EdGTM.Text,0,Length(EdGTM.Text)-4)+'_cls.xml';
  sSVMF:=Copy(EdGTM.Text,0,Length(EdGTM.Text)-4)+'.svm';
  sRspF:=Copy(EdGTM.Text,0,Length(EdGTM.Text)-4)+'R.svm';
  sPrjF:=Copy(EdGTM.Text,0,Length(EdGTM.Text)-4)+'Prj.mat';
  sSDFF:=Copy(EdGTM.Text,0,Length(EdGTM.Text)-4)+'.sdf';
  if FileExists(sRegF) then EdLandscapeFile.Text:=sRegF
  else if FileExists(sClsF) then EdLandscapeFile.Text:=sClsF;
  if FileExists(sSVMF) then EdSVM.Text:=sSVMF;
  if FileExists(sRspF) then EdResp.Text:=sRspF;
  if FileExists(sPrjF) then EdProjections.Text:=sPrjF;
  if FileExists(sSDFF) then EdSDF.Text:=sSDFF;
end;

procedure TFrmxGTMLandscape.BtOKClick(Sender: TObject);
var
  SLPrj: TStringList;
  i,ii: integer;
  xy: TDoublePoint;
  ibpos,iepos: integer; // begin and end line indexes of SDF fields
begin
  //Initialize
  DimMatrix(fmatX, 0, 0);
  DimVector(fLLvec,0);
  DimVector(fMxRvec,0);
  DimVector(fMxRvec0,0);
  DimVector(fMxRvec1,0);
  DimIntVector(fNodeMxRvec,0);
  bDrawTess := False;
  bDrawGrdt := False;
  bRsp:=False;
  bPrj:=False;
  bSDF:=False;
  dmin := MaxDouble;
  dmax := MinDouble;
  dminC:= MaxDouble;
  fcolmin:=clCream;
  fcolmax:=clBlack;
  LandscapePNG:=nil;
  fCurrMol:=-1;
  TglBxPrj.Checked:=False;
  CBLandscapes.ItemIndex:=-1;
  fCustRect:=TRect.Empty;
  //Hide the zoom interface - it shows again when the user interact with the plot
  LblZoomZone.Visible:=False;
  TglBxZoomBox.Visible:=False;
  BtZoom.Visible:=False;
  EdtLeft.Visible:=False;
  EdtTop.Visible:=False;
  EdtRight.Visible:=False;
  EdtBottom.Visible:=False;
  //Prepare new landscape
  CMLandscape.Active:=False;
  FillCBLandscape(EdLandscapeFile.Text);
  if FileExists(EdResp.Text) then bRsp:=True else bRsp:=False;
  if FileExists(EdProjections.Text) then bPrj:=True else bPrj:=False;
  if FileExists(EdSDF.Text) then bSDF:=True else bSDF:=False;
  if (bRsp) then // Plot the responsibility curve
  begin
    LoadLLfromRespFile(EdResp.Text,fLLvec);
    LoadMxRfromRespFile(EdResp.Text,fMxRvec,fNodeMxRvec);
    DimVector(fMxRvec0,High(fMxRvec));
    DimVector(fMxRvec1,High(fMxRvec));
    for ii:=Low(fMxRvec) to High(fMxRvec) do
    begin
      fMxRvec0[ii]:=fMxRvec[ii];
      fMxRvec1[ii]:=fMxRvec[ii];
    end;
    PlotRCum(fMxRvec,High(fMxRvec),LSRcum,LSRorg,MmLog);
    //PlotRCum(fLLvec,High(fLLVec),LSRcum,LSRorg,MmLog);
    //PlotRCum(EdResp.Text,LSRcum, LSRorg,MmLog); // Compute and plot the cumulative responsibility curve
  end;
  if (bPrj) then
  begin
    LoadPrjSeries(EdProjections.Text,EdResp.Text,LCSMols,fPrjToMolIndex,TDoubleHelper.MinValue);
  end;
  // Load SDF
  if bSDF then
  begin
    //Reset the SDF management
    fsdfslurp.Clear;
    fLMolIndex.Clear;
    fLMolPropList.Clear;
    fLMolPropValIdx.Clear;
    SetLength(fMolPropVal,0);
    //
    fsdfslurp.LoadFromFile(EdSDF.Text);
    fLMolIndex.Add(0);
    for i := 0 to fsdfslurp.Count - 1 do
    begin
      if fsdfslurp[i] = '$$$$' then
        fLMolIndex.Add(i + 1);
      if (POS('>',fsdfslurp[i])=1) then //Property line found
      begin
        ibpos:=POS('<',fsdfslurp[i])+1;
        iepos:=length(fsdfslurp[i]);
        fLMolPropList.Add(Copy(fsdfslurp[i],ibpos,iepos-ibpos));
      end;
    end;
    SetLength(fMolPropVal,fLMolIndex.Count);
    for i:=Low(fMolPropVal) to High(fMolPropVal) do fMolPropVal[i]:='';
    CBProp.Items:=fLMolPropList as TStrings;
    BitBtnFirst.Visible := True;
    BitBtnFirst.Enabled := True;
    BitBtnLeft.Visible := True;
    BitBtnLeft.Enabled := True;
    BitBtnGoTo.Visible := True;
    BitBtnGoTo.Enabled := True;
    BitBtnRight.Visible := True;
    BitBtnRight.Enabled := True;
    BitBtnLast.Visible := True;
    BitBtnLast.Enabled := True;
    MaskEditGoto.Visible := True;
    MaskEditGoto.Enabled := True;
    LblMolRec.Visible := True;
    //Display the first compound
    fCurrMol:=0;
    MolChange();
  end;
  //
  ChGTMLatent.Update;
  bDrawTess:=False;
  bDrawGrdt:=False;
  bRsp:=False;
  bPrj:=False;
end;

procedure TFrmxGTMLandscape.BtProjectionsClick(Sender: TObject);
var
  sRspF,sSDFF: string;
begin
  if ODlgProjections.Execute then
    EdProjections.Text := ODlgProjections.FileName;
  sRspF:=Copy(EdProjections.Text,0,Length(EdProjections.Text)-7)+'R.svm';
  sSDFF:=Copy(EdProjections.Text,0,Length(EdProjections.Text)-7)+'.sdf';
  if FileExists(sRspF) then EdResp.Text:=sRspF;
  if FileExists(sSDFF) then EdSDF.Text:=sSDFF;
  bPrj:=True;
end;

end.
