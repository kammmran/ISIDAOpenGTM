unit UnitGTMView;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, TAGraph, TASeries, TASources, TAMultiSeries,
  TATools, Forms, Controls, Graphics, Dialogs, StdCtrls, Buttons, MaskEdit,
  ExtCtrls, ComboEx, ComCtrls, contnrs, UGTMXML, UGTMFull, UGTMBase, UGTMSparse,
  ugtm_options, fpvtocanvas, fpvectorial, fgl, types, U_TYPE_GRAPHES,
  U_BASE_GRAPHES, U_GRAPHES, UnitMolDraw, utypes;

const
  clMissing= clCream;
  cMyColors: array [1..5,1..5] of TColor = ((clBlack, clGray, clGray,clGray,clGray),
                                            (clBlack, clWhite, clGray,clGray,clGray),
                                            (clBlack, clGray, clWhite,clGray,clGray),
                                            (clBlack, clDkGray, clLtGray,clWhite,clGray),
                                            (clBlack,clDkGray,clGray,clLtGray,clWhite));

type

  TIntegerList = specialize TFPGList<Integer>;

  { TFormGTMView }

  TFormGTMView = class(TForm)
    BitBtnFirst: TBitBtn;
    BitBtnGoTo: TBitBtn;
    BitBtnLast: TBitBtn;
    BitBtnLeft: TBitBtn;
    BitBtnRight: TBitBtn;
    BtOK: TButton;
    BtSDF: TButton;
    BtQuit: TButton;
    BtR: TButton;
    BtXML: TButton;
    BtPrj: TButton;
    CGPlots: TCheckGroup;
    CBProp: TComboBox;
    CTSMolsDataPointClickTool: TDataPointClickTool;
    CTSMolsDataPointCrosshairTool: TDataPointCrosshairTool;
    LBMols: TBubbleSeries;
    EdtR: TEdit;
    LblR: TLabel;
    LBSamples: TBubbleSeries;
    LCSEmphasize: TListChartSource;
    LCSSamples: TListChartSource;
    LSEmphasize: TLineSeries;
    CTSMols: TChartToolset;
    ChGTMLatent: TChart;
    EdtPrj: TEdit;
    EdtSDF: TEdit;
    ImageMol: TImage;
    LblMolRec: TLabel;
    LblPrj: TLabel;
    LblSDF: TLabel;
    LCSMols: TListChartSource;
    LBNodes: TBubbleSeries;
    LCSTraits: TListChartSource;
    LCSResp: TListChartSource;
    LSTraits: TLineSeries;
    EdtXML: TEdit;
    LblXML: TLabel;
    MaskEditGoto: TMaskEdit;
    MmLog: TMemo;
    ODSDF: TOpenDialog;
    ODR: TOpenDialog;
    ODXML: TOpenDialog;
    ODPrj: TOpenDialog;
    TBSize: TTrackBar;
    procedure BitBtnFirstClick(Sender: TObject);
    procedure BitBtnGoToClick(Sender: TObject);
    procedure BitBtnLastClick(Sender: TObject);
    procedure BitBtnLeftClick(Sender: TObject);
    procedure BitBtnRightClick(Sender: TObject);
    procedure BtOKClick(Sender: TObject);
    procedure BtPrjClick(Sender: TObject);
    procedure BtQuitClick(Sender: TObject);
    procedure BtRClick(Sender: TObject);
    procedure BtSDFClick(Sender: TObject);
    procedure BtXMLClick(Sender: TObject);
    procedure CBPropChange(Sender: TObject);
    procedure CGPlotsItemClick(Sender: TObject; Index: integer);
    procedure CTSMolsDataPointClickToolPointClick(ATool: TChartTool;
      APoint: TPoint);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure MaskEditGotoEditingDone(Sender: TObject);
    procedure MolChange();
    procedure TBSizeChange(Sender: TObject);
  private
    fXMLFle,fPrjFle,fSDFFle,fRFle: string; //XML model file name
    SLog: TStringList; //Log list
    fsdfslurp, ftmpmolsdf: TStringList;
    fLMolIndex: TIntegerList;
    fLMolPropList,fLMolPropValIdx: TStringList;
    fMolPropVal: array of string;
    fmoldr: TMol2DVec;
    fCurrMol: integer;
    fvResponsibility, fmatX: TMatrix;
    fr: Double;
  public

  end;

var
  FormGTMView: TFormGTMView;

implementation

{$R *.lfm}

{ TFormGTMView }

procedure TFormGTMView.BtQuitClick(Sender: TObject);
begin
  {$IfDef DARWIN}Halt;{$EndIf}
  {$IfNDef DARWIN}Close;{$EndIf}
end;

procedure TFormGTMView.BtRClick(Sender: TObject);
begin
  if ODR.Execute then
  begin
     fRFle:=ODR.FileName;
     EdtR.Text:=fRFle;
  end;
end;

procedure TFormGTMView.BtSDFClick(Sender: TObject);
begin
  if ODSDF.Execute then
  begin
     fSDFFle:=ODSDF.FileName;
     EdtSDF.Text:=fSDFFle;
  end;
end;

procedure TFormGTMView.BtOKClick(Sender: TObject);
var
  GTMModel: TGTMXML;
  aGTMOpt: TRGtmOptions;
  aGTMFull: TGTMFull;
  aGTMBase: TGTMBase;
  aGTMSparse: TGTMSparse;
  SLtmp,SLxy,SLR,SLRdata,SLRtuple:TStringList;
  //XYPrj: TMatrix;
  i,j: integer;
  s: string;
  dx,dy: double;
  bXMLIsSet, bPrjIsSet, bSDFIsSet, bRIsSet: Boolean;
  vDensity: TVector;
  inode: integer;
  dnode,dmin,dmax: double;
  ibpos,iepos: integer;
  sprop: string;
begin
  //Reset series
  LCSMols.Clear;
  LCSResp.Clear;
  LCSSamples.Clear;
  LCSTraits.Clear;
  LCSEmphasize.Clear;
  //
  bXMLIsSet:=False; bPrjIsSet:=False; bSDFIsSet:=False; bRIsSet:=False;
  GTMModel:=TGTMXML.Create;
  aGTMFull:=TGTMFull.Create;
  aGTMSparse:=TGTMSparse.Create;
  aGTMOpt:=TRGtmOptions.Create;
  SLtmp:=TStringList.Create;
  SLxy:=TStringList.Create;
  fr:=1E-2;
  //
  fXMLFle:=EdtXML.Text;
  fPrjFle:=EdtPrj.Text;
  fRFle:=EdtR.Text;
  fSDFFle:=EdtSDF.Text;
  MaskEditGoto.Text:='';
  //
  If FileExists(fXMLFle) then bXMLIsSet:=True else bXMLIsSet:=False;
  If FileExists(fPrjFle) then bPrjIsSet:=True else bPrjIsSet:=False;
  If FileExists(fSDFFle) then bSDFIsSet:=True else bSDFIsSet:=False;
  If FileExists(fRFle) then bRIsSet:=True else bRIsSet:=False;
  //
  //ShowMessage('fXMLFle: '+fXMLFle+'\n fPrjFle: '+fPrjFle+'\n fRFle: '+fRFle+'\n fSDFFle: '+fSDFFle);
  if bXMLIsSet then
  begin
    GTMModel.ReadGTMModel(aGTMOpt,fXMLFle);
    if aGTMOpt.GTMType=MULTINOMIAL then
    begin
      GTMModel.ReadGTMModel(aGTMSparse,fXMLFle);
      aGTMBase:=aGTMSparse as TGTMBase;
    end else
    begin
      GTMModel.ReadGTMModel(aGTMFull,fXMLFle);
      aGTMBase:=aGTMFull as TGTMBase;
    end;
    MmLog.Lines.Add('Dimension: '+IntToStr(aGTMBase.D));
    MmLog.Lines.Add('Number of Nodes: '+IntToStr(aGTMBase.K));
    MmLog.Lines.Add('Number of RBF: '+IntToStr(aGTMBase.M));
    MmLog.Lines.Add('RBF Width: '+FloatToStr(aGTMBase.sigma));
    // Load traits (RBFs) locations
    for i:=1 to aGTMBase.M do
      LCSTraits.Add(aGTMBase.matM[i,1],aGTMBase.matM[i,2]);
    CGPlots.CheckEnabled[0]:=True;
    // Load Samples
    DimMatrix(fmatX,aGTMBase.K,2);
    fr:=1/sqrt(aGTMBase.K);
    for i:=1 to aGTMBase.K do
    begin
      fmatX[i,1]:=aGTMBase.matX[i,1];
      fmatX[i,2]:=aGTMBase.matX[i,2];
      LCSSamples.AddXYList(fmatX[i,1],[fmatX[i,2],fr]);
    end;
    CGPlots.CheckEnabled[1]:=True;
  end;
  // Set Responsibilities
  If bRIsSet and bXMLIsSet then;
  begin
    fr:=1/sqrt(aGTMBase.K);
    DimVector(vDensity,aGTMBase.K);
    SLR:=TStringList.Create;
    SLRdata:=TStringList.Create;
    SLRtuple:=TStringList.Create;
    SLRtuple.Delimiter:=':';
    //Load the densities and the responsibilities
    SLR.LoadFromFile(fRFle);
    DimMatrix(fvResponsibility,SLR.Count,aGTMBase.K);
    for i:=0 to SLR.Count-1 do
    begin
      SLRdata.DelimitedText:=SLR[i];
      for j:=1 to SLRdata.Count-1 do
      begin
        SLRtuple.DelimitedText:=SLRdata[j];
        inode:=StrToInt(SLRtuple[0]);
        dnode:=StrToFloat(SLRtuple[1]);
        vDensity[inode]:=vDensity[inode]+dnode;
        if (inode>High(fVResponsibility[i+1])) then
        begin
          ShowMessage('ERROR: the responsibility file provided refers to non-existing nodes');
          Halt;
        end;
        fvResponsibility[i+1,inode]:=dnode;
      end;
    end;
    dmin:=vDensity[1];dmax:=vDensity[1];
    for i:=0 to aGTMBase.K do
    begin
      if dmin>vDensity[i] then dmin:=vDensity[i];
      if dmax<vDensity[i] then dmax:=vDensity[i];
    end;
    for i:=0 to aGTMBase.K do
    begin
      vDensity[i]:=(vDensity[i]-dmin)/(dmax-dmin);
    end;
    LCSSamples.Clear;
    for i:=0 to aGTMBase.K do
    begin
      LCSSamples.AddXYList(fmatX[i,1],[fmatX[i,2],fr*vDensity[i]+0.003]);
    end;
    for i:=0 to aGTMBase.K do
    begin
      LCSSamples.AddXYList(fmatX[i,1],[fmatX[i,2],0.003]);
    end;
    CGPlots.CheckEnabled[1]:=True;
    // Load Prj
    if bPrjIsSet then
    begin
      SLtmp.Clear;
      SLtmp.LoadFromFile(EdtPrj.Text);
      for i:=1 to SLtmp.Count-2 do
      begin
        SLxy.CommaText:=SLtmp[i];
        LCSMols.AddXYList(StrToFloat(SLxy[0]),[StrToFloat(SLxy[1]),0.1*fr*TBSize.Position],'',clBlack);
      end;
      CGPlots.CheckEnabled[2]:=True;
    end;
    //
    FreeAndNil(SLRdata);
    FreeAndNil(SLRtuple);
    FreeAndNil(SLR);
  end;
  // Load SDF
  if bSDFIsSet then
  begin
    //Reset the SDF management
    fsdfslurp.Clear;
    fLMolIndex.Clear;
    fLMolPropList.Clear;
    fLMolPropValIdx.Clear;
    SetLength(fMolPropVal,0);
    //
    fsdfslurp.LoadFromFile(EdtSDF.Text);
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
    CGPlots.CheckEnabled[3]:=True;
  end;
  //
  FreeAndNil(SLxy);
  FreeAndNil(SLtmp);
  FreeAndNil(GTMModel);
  FreeAndNil(aGTMFull);
  FreeAndNil(aGTMSparse);
  FreeAndNil(aGTMOpt);
end;

procedure TFormGTMView.BitBtnGoToClick(Sender: TObject);
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

procedure TFormGTMView.BitBtnFirstClick(Sender: TObject);
begin
  fCurrMol:=0;
  MaskEditGoto.Text:=IntToStr(fCurrMol+1);
  MolChange();
end;  // BitBtnGoToClick

procedure TFormGTMView.BitBtnLastClick(Sender: TObject);
var
  i: integer;
begin
  i:=fLMolIndex.Count-2;
  fCurrMol:=i;
  MaskEditGoto.Text:=IntToStr(fCurrMol+1);
  MolChange();
end;  // BitBtnGoToClick

procedure TFormGTMView.BitBtnLeftClick(Sender: TObject);
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

procedure TFormGTMView.BitBtnRightClick(Sender: TObject);
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

procedure TFormGTMView.BtPrjClick(Sender: TObject);
var
  sBaseName: string;
begin
  if ODPrj.Execute then
  begin
     fPrjFle:=ODPrj.FileName;
     EdtPrj.Text:=fPrjFle;
     sBaseName:=ExtractFileNameWithoutExt(ODPrj.FileName);
     sBaseName:=LeftStr(sBaseName,Length(sBaseName)-3);
     if FileExists(sBaseName+'R.svm') then
        EdtR.Text:=sBaseName+'R.svm';
  end;
end;

procedure TFormGTMView.BtXMLClick(Sender: TObject);
var
  sBaseName: string;
begin
  if ODXML.Execute then
  begin
     fXMLFle:=ODXML.FileName;
     EdtXML.Text:=fXMLFle;
     sBaseName:=ExtractFileNameWithoutExt(ODXML.FileName);
     if FileExists(sBaseName+'R.svm') then
        EdtR.Text:=sBaseName+'R.svm';
     if FileExists(sBaseName+'Prj.mat') then
        EdtPrj.Text:=sBaseName+'Prj.mat';
  end;
end;

procedure TFormGTMView.CBPropChange(Sender: TObject);
var
  i,imol,ibpos,iepos,icol: integer;
  sprop: string;
begin
  imol:=0;
  fLMolPropValIdx.Clear;
  for i:=Low(fMolPropVal) to High(fMolPropVal) do fMolPropVal[i]:='';
  //MmLog.Append('search for '+CBProp.Items[CBProp.ItemIndex]);
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
  //MmLog.Append('High(fMolPropVal)='+IntToStr(High(fMolPropVal)));
  //MmLog.Append('fLMolPropValIdx.Count='+IntToStr(fLMolPropValIdx.Count));
  for i:=1 to High(fMolPropVal) do
  begin
    icol:=fLMolPropValIdx.IndexOf(fMolPropVal[i])+1;
    if icol<=0 then
      LBMols.SetColor(i-1,clMissing)
    else if icol<=fLMolPropValIdx.Count then
      LBMols.SetColor(i-1,cMyColors[fLMolPropValIdx.Count,icol])
    else
      LBMols.SetColor(i-1,cMyColors[fLMolPropValIdx.Count,(icol mod High(cMyColors))]);
    //MmLog.Append('icol ='+IntToStr(icol)+' High(cMyColors[fLMolPropValIdx.Count])='+IntToStr(High(cMyColors[fLMolPropValIdx.Count]))+' fLMolPropValIdx.Count='+inttostr(fLMolPropValIdx.Count));
  end;
  MolChange();
end;

procedure TFormGTMView.CGPlotsItemClick(Sender: TObject; Index: integer);
begin
  CTSMolsDataPointCrosshairTool.Enabled:=False;
  //CTSMolsDataPointCrosshairTool.Hide;
  If CGPlots.Checked[0] then
    LSTraits.Active:=True else LSTraits.Active:=False;
  If CGPlots.Checked[1] then
    LBSamples.Active:=True else LBSamples.Active:=False;
  If CGPlots.Checked[2] then begin
     LBMols.Active:=True;
     LSEmphasize.Active:=True;
     CTSMolsDataPointCrosshairTool.Enabled:=True;
     //CTSMolsDataPointCrosshairTool.Hide;
  end else
  begin
    LBMols.Active:=False;
    LSEmphasize.Active:=False;
  end;
  If CGPlots.Checked[3] then
    LBNodes.Active:=True else LBNodes.Active:=False;
end;

procedure TFormGTMView.CTSMolsDataPointClickToolPointClick(ATool: TChartTool;
  APoint: TPoint);
var
  clicktool: TDatapointClickTool;
  ser: TBubbleSeries;
  i: integer;
begin
  if (CGPlots.Checked[2]) then
  begin
    clicktool := TDatapointClickTool(ATool);
    ser := TBubbleSeries(clickTool.Series);     // this is the clicked series
    if ser = nil then
      exit;
    if ser.Title='Projections' then
    begin
      i:=clicktool.PointIndex;   // Point index of the nearest data point
      if (i>=0) and (i<=fLMolIndex.Count-2) then
      begin
        fCurrMol:=i;
        MaskEditGoto.Text:=IntToStr(fCurrMol+1);
        MolChange();
      end;
    end;
  end;
//
  {ShowMessage(Format('Series %s, x = %f, y = %f, point index = %d', [
    ser.Title,             // Title of the clicked series
    clickTool.NearestGraphPoint.X, clickTool.NearestGraphPoint.Y,    // Coordinates of the nearest data point
    clicktool.PointIndex   // Point index of the nearest data point
  ]));}
end;

procedure TFormGTMView.FormCreate(Sender: TObject);
var
  proot: string;
  i: integer;
begin
  fr:=1;
  SLog:=TStringList.Create;
  fLMolPropList:=TStringList.Create;
  fLMolPropList.Duplicates:=dupIgnore;
  fLMolPropList.Sorted:=True;
  fLMolPropValIdx:=TStringList.Create;
  fLMolPropValIdx.Duplicates:=dupIgnore;
  fLMolPropValIdx.Sorted:=True;
  //proot:='/Users/marcou/Documents/CS3-2018/FDB/';
  //'/Users/marcou/Documents/CS3-2018/Frg/CVIter1Fold1/t9l2u4/';
  ///Users/marcou/Documents/Kazan2018/A2A/SMOTE/linsvmGM/short/train-smote28_p1';
  //'/Users/marcou/workdir/ISIDAGTM2017/GTMapTool/examples/IUPHAR_5HT2B';
  //fXMLFle:=proot+'train_Freq_0.xml'; EdtXML.Text:=fXMLFle;
  //fPrjFle:=proot+'train_Freq_0_fitPrj.mat'; EdtPrj.Text:=fPrjFle;
  //fSDFFle:=proot+'train.sdf'; EdtSDF.Text:=fSDFFle;
  //fRFle:=proot+'train_Freq_0_fitR.svm'; EdtR.Text:=fRFle;
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
  for i:=0 to CGPlots.Items.Count-1 do
    CGPlots.CheckEnabled[i]:=False;
end;

procedure TFormGTMView.FormDestroy(Sender: TObject);
begin
  FreeAndNil(SLog);
  FreeAndNil(fLMolPropList);
  FreeAndNil(fLMolPropValIdx);
  //
  FreeAndNil(fLMolIndex);
  FreeAndNil(fsdfslurp);
  FreeAndNil(ftmpmolsdf);
  FreeAndNil(fmoldr);
end;

procedure TFormGTMView.MaskEditGotoEditingDone(Sender: TObject);
begin
  BitBtnGoToClick(Sender);
end;

procedure TFormGTMView.MolChange();
var
  i,icol: integer;
  rmax: double;
  s: string;
  ptColor: TColor;
begin
  ftmpmolsdf.Clear;
  if fLMolIndex.Count>0 then begin
    for i := fLMolIndex[fCurrMol] to fLMolIndex[fCurrMol + 1] - 1 do
      ftmpmolsdf.Add(fsdfslurp[i]);
    fmoldr.VMolPage.Clear;
    fmoldr.DrawMol(ftmpmolsdf);
    fmoldr.WriteToImage(ImageMol);
    //LabelMol(LblMolRec, PClsD);
    //LabelMolName(LblName,fmoldr.MolG.MolName);
  end;
  //Set reticule in ExpPred chart
  LSEmphasize.ShowPoints:=True;
  If LCSEmphasize.Count<1 then LCSEmphasize.Add(0,0);
  LCSEmphasize.SetXValue(0,LBMols.GetXValue(fCurrMol));
  LCSEmphasize.SetYValue(0,LBMols.GetYValue(fCurrMol));
  //Set reponsibilities
  LCSResp.Clear;
  //s:='';
  rmax:=0;
  for i:=1 to High(fvResponsibility[0]) do
      if (fvResponsibility[fCurrMol+1,i]>rmax) then rmax:=fvResponsibility[fCurrMol+1,i];
  icol:=fLMolPropValIdx.IndexOf(fMolPropVal[fCurrMol+1])+1;
  if icol<=0 then
    ptColor:=clMissing
  else if icol<=fLMolPropValIdx.Count then
    ptColor:=cMyColors[fLMolPropValIdx.Count,icol]
  else
    ptColor:=cMyColors[fLMolPropValIdx.Count,(icol mod High(cMyColors))];
  for i:=1 to High(fvResponsibility[0]) do
  begin
    //Compute the color here while adding points
    LCSResp.AddXYList(fmatX[i,1],[fmatX[i,2],fvResponsibility[fCurrMol+1,i]*fr/rmax],'',ptColor);
    //cMyColors[fLMolPropValIdx.Count,(icol mod High(cMyColors))+1]);//fCurrMol is a 0-based counter
    //s:=s+FloatToStr(fvResponsibility[fCurrMol+1,i])+' ';
  end;
  //MmLog.Append(s);
  //
  LblMolRec.Caption:='Looking at Record: '+IntToStr(fCurrMol+1)+ ' -|- '+fMolPropVal[fCurrMol+1];
end;

procedure TFormGTMView.TBSizeChange(Sender: TObject);
var
  i: integer;
begin
  {MmLog.Append('Position: '+IntToStr(TBSize.Position));
  for i:=0 to LCSMols.Count-1 do
  begin
    LCSMols.Item[i]^.YList[1]:=0.1*fr*TBSize.Position;
  end;
  ChGTMLatent.Refresh;}
  //LCSMols.BeginUpdate;
end;

end.

