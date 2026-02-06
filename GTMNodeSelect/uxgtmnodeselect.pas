unit uxGTMNodeSelect;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Contnrs, math, StrUtils, UGTMBase, UGTMFull, UGTMSparse, UcGTM,
  UGTMXML, utypes, ulinalg, UnitLLStringList, UnitNodeSelectProc;

type

  { TFrmxGTMNodeSelect }

  TFrmxGTMNodeSelect = class(TForm)
    BtDelFile: TButton;
    BtSDF: TButton;
    BtAddFile: TButton;
    BtOK: TButton;
    BtQuit: TButton;
    BtGTM: TButton;
    BtSVM: TButton;
    CBGenerate: TCheckBox;
    CBZoom: TCheckBox;
    EdGTM: TEdit;
    EdOutput: TEdit;
    EdSVM: TEdit;
    EdSDF: TLabeledEdit;
    EdXmin: TLabeledEdit;
    EdXmax: TLabeledEdit;
    EdYmin: TLabeledEdit;
    EdYmax: TLabeledEdit;
    EdThrld: TLabeledEdit;
    EdSamples: TLabeledEdit;
    EdSeed: TLabeledEdit;
    EdIter: TLabeledEdit;
    EdConv: TLabeledEdit;
    LBFileList: TListBox;
    DlgSDF: TOpenDialog;
    DlgAdd: TOpenDialog;
    DlgGTM: TOpenDialog;
    DlgSVM: TOpenDialog;
    MmLog: TMemo;
    PnlGenerate: TPanel;
    PnlZoom: TPanel;
    procedure BtAddFileClick(Sender: TObject);
    procedure BtDelFileClick(Sender: TObject);
    procedure BtGTMClick(Sender: TObject);
    procedure BtOKClick(Sender: TObject);
    procedure BtQuitClick(Sender: TObject);
    procedure BtSDFClick(Sender: TObject);
    procedure BtSVMClick(Sender: TObject);
    procedure CBGenerateChange(Sender: TObject);
    procedure CBZoomChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
  private

  public

  end;

var
  FrmxGTMNodeSelect: TFrmxGTMNodeSelect;

implementation

{$R *.lfm}

{ TFrmxGTMNodeSelect }

procedure TFrmxGTMNodeSelect.FormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin

end;

procedure TFrmxGTMNodeSelect.FormCreate(Sender: TObject);
var
  dtmp: double;
begin
  {EdGTM.Text:='/home/marcou/workdir/ISIDAGTM2024/GTMNodeSelect/example/train.xml';
  EdSVM.Text:='/home/marcou/workdir/ISIDAGTM2024/GTMNodeSelect/example/train.svm';
  EdOutput.Text:='/home/marcou/workdir/ISIDAGTM2024/GTMNodeSelect/example/train';
  EdSDF.Text:='/home/marcou/workdir/ISIDAGTM2024/GTMNodeSelect/example/train.sdf';
  LBFileList.AddItem('/home/marcou/workdir/ISIDAGTM2024/GTMNodeSelect/example/train_logBCF.prp',nil);
  LBFileList.AddItem('/home/marcou/workdir/ISIDAGTM2024/GTMNodeSelect/example/train.svm',nil);}
  if ParamCount=5 then
  begin
    if TryStrToFloat(ParamStr(1),dtmp) then EdXmin.Text:=ParamStr(1);
    if TryStrToFloat(ParamStr(2),dtmp) then EdXmax.Text:=ParamStr(2);
    if TryStrToFloat(ParamStr(3),dtmp) then EdYmin.Text:=ParamStr(3);
    if TryStrToFloat(ParamStr(4),dtmp) then EdYmax.Text:=ParamStr(4);
    if TryStrToFloat(ParamStr(5),dtmp) then EdThrld.Text:=ParamStr(5);
  end;
  if ParamCount=9 then
  begin
    if TryStrToFloat(ParamStr(1),dtmp) then EdXmin.Text:=ParamStr(1);
    if TryStrToFloat(ParamStr(2),dtmp) then EdXmax.Text:=ParamStr(2);
    if TryStrToFloat(ParamStr(3),dtmp) then EdYmin.Text:=ParamStr(3);
    if TryStrToFloat(ParamStr(4),dtmp) then EdYmax.Text:=ParamStr(4);
    if TryStrToFloat(ParamStr(5),dtmp) then EdThrld.Text:=ParamStr(5);
    EdGTM.Text:=ParamStr(6);
    EdSVM.Text:=ParamStr(7);
    EdOutput.Text:=ExtractFilePath(EdGTM.Text);
    //Copy(EdGTM.Text,1,RPos('.',EdGTM.Text)-1);
    EdSDF.Text:=ParamStr(8);
    LBFileList.AddItem(ParamStr(9),nil);
    LBFileList.AddItem(ParamStr(7),nil);
  end;
end;

procedure TFrmxGTMNodeSelect.BtSDFClick(Sender: TObject);
begin
  if DlgSDF.Execute then
    EdSDF.Text:=DlgSDF.FileName;
end;

procedure TFrmxGTMNodeSelect.BtSVMClick(Sender: TObject);
begin
  if DlgSVM.Execute then
  begin
    EdSVM.Text:=DlgSVM.FileName;
    LBFileList.AddItem(EdSVM.Text,nil);
  end;
end;

procedure TFrmxGTMNodeSelect.CBGenerateChange(Sender: TObject);
begin
  If CBGenerate.Checked then
    PnlGenerate.Visible:=True
  else
    PnlGenerate.Visible:=False;
end;

procedure TFrmxGTMNodeSelect.CBZoomChange(Sender: TObject);
begin
  PnlZoom.Visible:=True;
end;

procedure TFrmxGTMNodeSelect.BtAddFileClick(Sender: TObject);
var
  w: integer;
begin
  if DlgAdd.Execute then
  begin
     LBFileList.AddItem(DlgAdd.FileName,nil);
     w:=LBFileList.Canvas.TextWidth(DlgAdd.FileName);
     if w>LBFileList.ScrollWidth then
        LBFileList.ScrollWidth:=w;
  end;
end;

procedure TFrmxGTMNodeSelect.BtDelFileClick(Sender: TObject);
var
  i: integer;
begin
  if LBFileList.SelCount > 0 then                 //Delete only if at least one string in the list box is selected
    for i:=LBFileList.Items.Count - 1 downto 0 do //Iterate through all the items
      if LBFileList.Selected[i] then              //If selected...
        LBFileList.Items.Delete(i);               //...delete the item (String)
end;

procedure TFrmxGTMNodeSelect.BtGTMClick(Sender: TObject);
var
  sSVMF,sSDFF,sPRPF: string;
begin
  if DlgGTM.Execute then begin
    EdGTM.Text:=DlgGTM.FileName;
    EdOutput.Text:=ExtractFilePath(EdGTM.Text);
    //Copy(EdGTM.Text,1,RPos('.',EdGTM.Text)-1);
    sSVMF:=Copy(EdGTM.Text,1,RPos('.',EdGTM.Text)-1)+'.svm';
    sSDFF:=Copy(EdGTM.Text,1,RPos('.',EdGTM.Text)-1)+'.sdf';
    sPRPF:=Copy(EdGTM.Text,1,RPos('.',EdGTM.Text)-1)+'.prp';
    if FileExists(sSVMF) then begin
      EdSVM.Text:=sSVMF;
      LBFileList.AddItem(sSVMF,nil);
    end;
    if FileExists(sPRPF) then begin
      LBFileList.AddItem(sPRPF,nil);
    end;
    if FileExists(sSDFF) then begin
      EdSDF.Text:=sSDFF;
    end;
  end;
end;

procedure TFrmxGTMNodeSelect.BtOKClick(Sender: TObject);
var
  smols,smodel,soutput: string;
  snodes: string;
  sSDF: string;
  stmp,sfile, sline: string;
  sSVMsel:string;
  xmin,xmax,ymin,ymax: double;
  LLt0,LLt,LLtmin,thrld,RMxThrld,dConv: double;
  ngenerate, nseed: integer;
  MaxIter: integer;
  ii,ik: integer;
  NSel: integer;
  aGTMXML: TGTMXML;
  aGTMBase: TGTMBase;
  acGTM,zcGTM: TcGTM;//a GTM and the zoomed GTM
  aGTMSparse: TGTMSparse;
  XT: TMatrix;
  aSmpleX, aSmpleZ:TMatrix;
  MxR: TVector;
  MxRNode: TIntVector;
  bgenerate, bzoom: boolean;
  SLnodes,SLbox: TStringList;
  SLmols:TLLStringList;
  SLFileList: TStringList; // a list of files - 1 title line, 1 molecule per line
  SLtmp: TStringList;
  SLlog: TStringList;
  OLSDF: TObjectList;
  ii1,jj1: integer;
begin
  smols:='';
  smodel:='';
  soutput:='default';
  snodes:='';
  sSDF:='';
  stmp:='';
  sfile:='';
  xmin:=-1;
  xmax:=1;
  ymin:=-1;
  ymax:=1;
  LLt:=MinDouble;
  LLtmin:=MinDouble;
  thrld:=NaN;
  RMxThrld:=NaN;
  dConv:=0.01;
  ngenerate:=0;
  nseed:=-1;
  MaxIter:=0;
  bgenerate:=False;
  bzoom:=False;
  aGTMBase:=nil;
  acGTM:=nil;
  acGTM:=nil;
  aGTMSparse:=nil;
  aGTMXML:=nil;
  XT:=nil;
  aSmpleX:=nil;
  aSmpleZ:=nil;
  DimVector(MxR,0);
  DimIntVector(MxRNode,0);
  SLnodes:=TStringList.Create;
  SLbox:=TStringList.Create;
  SLFileList:=TStringList.Create;
  SLmols:=TLLStringList.Create;
  SLtmp:=TStringList.Create;
  SLlog:=TStringList.Create;
  OLSDF:=TObjectList.Create; OLSDF.OwnsObjects:=True;
  // parse parameters
  bzoom:=CBZoom.Checked;
  smols:=EdSVM.Text;
  smodel:=EdGTM.Text;
  soutput:=EdOutput.Text;
  SLnodes.Clear;
  sSDF:=EdSDF.Text;
  LoadSDF(sSDF,OLSDF);
  SLFileList.Clear;
  for ii:=0 to LBFileList.Count-1 do
  begin
      stmp:=LBFileList.Items[ii];
      if FileExists(stmp) then
      begin
        SLFIleList.Add(stmp);
      end else
      begin
         raise Exception.Create('ERROR: Can''t locate file: '+stmp);
         Exit;
      end;
  end;
  try
     stmp:=EdXmin.Text; xmin:=StrToFloat(stmp);
     stmp:=EdXmax.Text; xmax:=StrToFloat(stmp);
     stmp:=EdYmin.Text; ymin:=StrToFloat(stmp);
     stmp:=EdYmax.Text; ymax:=StrToFloat(stmp);
     stmp:=EdThrld.Text; thrld:=StrToFloat(stmp);
     if (xmin>=xmax) then begin
       Exception.Create('ERROR: wrong range value - Xmin='+EdXmin.Text+' Xmax='+EdXmax.Text);
       EdXmin.Text:='';
       EdXmax.Text:='';
       Exit;
     end;
     if (ymin>=ymax) then begin
       Exception.Create('ERROR: wrong range value - Ymin='+EdYmin.Text+' Ymax='+EdYmax.Text);
       EdYmin.Text:='';
       EdYmax.Text:='';
       Exit;
     end;
  except
    Exception.Create('ERROR: Impossible to convert a value: '+stmp);
    EdXmin.Text:='';
    EdXmax.Text:='';
    EdYmin.Text:='';
    EdYmax.Text:='';
    EdThrld.Text:='';
    Exit;
  end;
  if (thrld<0) or (thrld>1) then
  begin
    Exception.Create('ERROR: threshold value must be within range [0,1]');
    Exit;
  end;
  if CBGenerate.Checked then
  begin
    bgenerate:=True;
    try
      stmp:=EdSamples.Text; ngenerate:=StrToInt(stmp);
      stmp:=EdSeed.Text; nseed:=StrToInt(stmp);
    except
      Exception.Create('ERROR: Impossible to convert a value: '+stmp);
      EdSamples.Text:='';
      edSeed.Text:='';
      Exit;
    end;
  end;
  if CBZoom.Checked then
  begin
    try
      MaxIter:=StrToInt(EdIter.Text);
      if MaxIter<0 then
         Raise Exception.Create('ERROR: Number of iteration must be a positive integer');
      dConv:=StrToFloat(EdConv.Text);
      if dConv<0 then
         Raise Exception.Create('ERROR: Convergence is a small positive float');
    except
      EdIter.Text:='';
      EdConv.Text:='';
      Exit;
    end;
  end;
  //
  MmLog.Lines.Add('GTM model: '+smodel);
  soutput:=IncludeTrailingPathDelimiter(soutput);
  MmLog.Lines.Add('Outputs base name: '+soutput);
  MmLog.SelStart:=Length(MmLog.Text); Application.ProcessMessages;
  // Restrict the application to full size GTM
  acGTM:=TcGTM.Create;
  aGTMXML:=TGTMXML.Create;
  aGTMXML.ReadGTMModel(acGTM,smodel);
  FreeAndNil(aGTMXML);
  acGTM.Restart:=True;//This GTM is supposed to have been already trained
  //Load the molecules into the molecule list and the GTM.
  SLmols.LoadFromFile(smols);
  acGTM.ReadMols(smols);
  // Project the input dataset
  DimVector(MxR,acGTM.N);
  DimIntVector(MxRNode,acGTM.N);
  acGTM.Init;
  acGTM.Project(True,False,True,True);
  // Locate max. responsibilities and their locations
  for ii:=1 to acGTM.N do
    acGTM.MxR(ii,MxRNode[ii],MxR[ii]);
  //
  MmLog.Lines.Add('Submanifold definition...'); MmLog.SelStart:=Length(MmLog.Text);  Application.ProcessMessages;
  //
  //Restricted Likelihood
  MmLog.Lines.Add('Concerned nodes ID:'); MmLog.SelStart:=Length(MmLog.Text);  Application.ProcessMessages;
  snodes:=' ';//snodes: string of selected nodes IDs
  for ik:=1 to acGTM.K do begin //SelNode=TRUE -> node is selected to be used for projection and it is updatable during optimization
    if (acGTM.matX[ik,1]>=xmin) and (acGTM.matX[ik,1]<=xmax) and (acGTM.matX[ik,2]>=ymin) and (acGTM.matX[ik,2]<=ymax) then begin
      acGTM.SelNode[ik]:=True;
      snodes:=snodes+IntToStr(ik)+' ';
    end
    else
      acGTM.SelNode[ik]:=False;
  end;
  // Keep max. responsibilities only on the selected nodes
  for ii:=1 to acGTM.N do
    if acGTM.SelNode[MxRNode[ii]]=False then MxR[ii]:=0;
  PopThrldToMxRThrld(SLmols,acGTM.N,MxR,thrld,RMxThrld);
  //
  MmLog.Lines.Add('('+snodes+')'); MmLog.SelStart:=Length(MmLog.Text);  Application.ProcessMessages;
  //Load the molecules into the molecule list and the GTM.
  //SLmols.LoadFromFile(smols);
  //acGTM.ReadMols(smols);
  //Selection based on the likelihood on the restricted manifold
  //RestrictedLikelyhood(SLmols,acGTM,thrld,LLt,LLtmin,SLlog);
  MmLog.Lines.Add(SLlog.Text); MmLog.SelStart:=Length(MmLog.Text);  Application.ProcessMessages;
  SLlog.Clear;
  //Output the selected molecules sorted according to their likelyhood int the file *_Sorted.svm
  //Maybe useless?
  {sfile:=soutput+'_Sorted.svm';
  if FileExists(sfile) then
    DeleteFile(sfile);
  SLmols.SaveToFile(sfile);}
  // Filter the SDF
  NSel:=0;
  stmp:='';
  for ii:=1 to acGTM.N do
    if MxR[ii]>RMxThrld then begin
      stmp:=stmp+' '+IntToStr(ii);
      Inc(NSel);
    end;
  MmLog.Lines.Add('Selected Molecules ('+IntToStr(NSel)+'):');
  MmLog.Lines.Add(stmp);;
  if sSDF<>'' then
  begin
    //FilterByLikelyhood(acGTM,LLtmin,OLSDF);
    //FilterByRMx(acGTM,RMxThrld,OLSDF);
    FilterByRMx(MxR,acGTM.N,RMxThrld,OLSDF);
    stmp:=soutput+ExtractFileName(sSDF);
    sfile:=copy(stmp,1,RPos('.',stmp)-1)+'_Selected.sdf';
    //sfile:=copy(sSDF,1,RPos('.',sSDF)-1)+'_Selected.sdf';
    if FileExists(sfile) then
      DeleteFile(sfile);
    WriteSDF(sfile,OLSDF);
  end;
  // Filter requested files
  for ii:=0 to SLFileList.Count-1 do
  begin
    stmp:=SLFileList[ii];
    SLtmp.Clear;
    SLtmp.LoadFromFile(stmp);
    if ExtractFileExt(stmp)='.prp' then
    begin
      sline:=SLtmp[0];
      SLtmp.Delete(0);
    end;
    //FilterByLikelyhood(acGTM,LLtmin,SLtmp);
    //FilterByRMx(acGTM,RMxThrld,SLtmp);
    FilterByRMx(MxR,acGTM.N,RMxThrld,SLtmp);
    if ExtractFileExt(stmp)='.prp' then
    begin
      SLtmp.Insert(0,sline);
    end;
    stmp:=soutput+ExtractFileName(stmp);
    sfile:=copy(stmp,1,RPos('.',stmp)-1)+'_Selected'+copy(stmp,RPos('.',stmp),Length(stmp));
    if FileExists(sfile) then
      DeleteFile(sfile);
    SLtmp.SaveToFile(sfile);
  end;
  {//Identify the SVM with selected molecules.
  sSVMsel:='';
  stmp:=EdSVM.Text;
  stmp:=soutput+ExtractFileName(stmp);
  sfile:=copy(stmp,1,RPos('.',stmp)-1)+'_Selected'+copy(stmp,RPos('.',stmp),Length(stmp));
  if FileExists(sfile) then sSVMsel:=sfile;}
  //
  // Filter the X matrix
  //FilterByLikelyhood(acGTM,LLtmin,XT);
  //FilterByRMx(acGTM,RMxThrld,XT);
  FilterByRMx(MxR,acGTM.N,acGTM,RMxThrld,XT);
  //
  SLtmp.Clear;
  //Sample generation
  if bgenerate then begin
    if nseed>=0 then RandSeed:=nseed else randomize; //Control of pseudo-random number generator
    GeneratedFromSelected(acGTM,ngenerate,aSmpleX,aSmpleZ);
    SLtmp.Clear;
    PrintMat(aSmpleX,'SampleX',1,ngenerate,1,acGTM.D,SLtmp);//In the initial space of the data
    sfile:=soutput+ExtractFileName(EdGTM.Text);
    sfile:=ChangeFileExt(sfile,'')+'_SampleX.mat';
    //sfile:=ChangeFileExt(soutput,'')+'_SampleX.mat';
    if FileExists(sfile) then
      DeleteFile(sfile);
    SLtmp.SaveToFile(sfile);//In the initial frame set
    MmLog.Lines.Add('Sampled data in the initial frame have been saved in: '+sfile); MmLog.SelStart:=Length(MmLog.Text);  Application.ProcessMessages;
    SLtmp.Clear;
    PrintMat(aSmpleZ,'SampleZ',1,ngenerate,1,acGTM.D,SLtmp);
    sfile:=soutput+ExtractFileName(EdGTM.Text);
    sfile:=ChangeFileExt(sfile,'')+'_SampleZ.mat';
    //sfile:=ChangeFileExt(soutput,'')+'_SampleZ.mat';
    if FileExists(sfile) then
      DeleteFile(sfile);
    SLtmp.SaveToFile(sfile);//In the frame set of the manifold
    MmLog.Lines.Add('Sampled data in the frame of the manifold have been saved in: '+sfile); MmLog.SelStart:=Length(MmLog.Text);  Application.ProcessMessages;
  end;
  //Zoom
  if bzoom then begin
    soutput:=soutput+ChangeFileExt(ExtractFileName(EdGTM.Text),'');
    zcGTM:=TcGTM.Create;
    SLlog.Clear;
    ii1:=High(XT);
    jj1:=High(XT[0]);
    DoZoomOnGTM(acGTM,zcGTM,xmax,xmin,ymax,ymin,XT,TStringList(MmLog.Lines),MaxIter);
    MmLog.Lines.Add(SLlog.Text); MmLog.SelStart:=Length(MmLog.Text);  Application.ProcessMessages;
    //Projection and saving
    sfile:=soutput+'_ZoomPrj.mat';
    if FileExists(sfile) then DeleteFile(sfile);
    sfile:=soutput+'_ZoomR.svm';
    if FileExists(sfile) then DeleteFile(sfile);
    sfile:=soutput+'_Zoom.xml';
    if FileExists(sfile) then DeleteFile(sfile);
    MmLog.Lines.Add('...Computing projections'); MmLog.SelStart:=Length(MmLog.Text);  Application.ProcessMessages;
    //
    zcGTM.Project(False,False,True,True); //Compute projections
    MmLog.Lines.Add('...Saving files: '+soutput+'_Zoom.*'); MmLog.SelStart:=Length(MmLog.Text);  Application.ProcessMessages;
    WriteGTMMat(zcGTM,soutput+'_Zoom',False,False);
    MmLog.Lines.Add('...Save zoom GTM model: '+soutput+'_Zoom.xml'); MmLog.SelStart:=Length(MmLog.Text);  Application.ProcessMessages;
    aGTMXML:=TGTMXML.Create;
    aGTMXML.WriteGTMModel(zcGTM,soutput+'_Zoom.xml');
    FreeAndNil(aGTMXML);
    //Release memory
    FreeAndNil(zcGTM);
    MmLog.Lines.Add('...done'); MmLog.SelStart:=Length(MmLog.Text);  Application.ProcessMessages;
    soutput:=EdOutput.Text;
  end;
  // stop program loop
  FreeAndNil(SLnodes);
  FreeAndNil(SLbox);
  FreeAndNil(SLmols);
  FreeAndNil(SLtmp);
  FreeAndNil(SLlog);
  FreeAndNil(SLFileList);
  FreeAndNil(OLSDF);
  if aGTMXML<>nil then FreeAndNil(aGTMXML);
  if aGTMBase<>nil then FreeAndNil(aGTMBase);
  if acGTM<>nil then FreeAndNil(acGTM);
  if aGTMSparse<>nil then FreeAndNil(aGTMSparse);
end;

procedure TFrmxGTMNodeSelect.BtQuitClick(Sender: TObject);
begin
  Close;
end;

end.

