unit uxGTMClass;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Spin,
  UGTMClass, GTMClassFunctions, UnitClsStats, UnitCVsvm, FileUtil, strutils;

type

  { TFrmxGTMClass }

  TFrmxGTMClass = class(TForm)
    BtModelChose: TButton;
    BtOK: TButton;
    BtOutChose: TButton;
    BtPropChose: TButton;
    BtQuit: TButton;
    BtRespChose: TButton;
    CBclassNormalize: TCheckBox;
    EdtAuthor: TEdit;
    EdtComment: TEdit;
    EdtModel: TEdit;
    EdtOut: TEdit;
    EdtProp: TEdit;
    EdtPropName: TEdit;
    EdtResp: TEdit;
    EdtTitle: TEdit;
    FSEminDens: TFloatSpinEdit;
    FSEClsThrd: TFloatSpinEdit;
    FSEminResp: TFloatSpinEdit;
    LblMinDens: TLabel;
    LblClsThrd: TLabel;
    LblminResp: TLabel;
    LblAuthor: TLabel;
    LblComment: TLabel;
    LblFolds: TLabel;
    LblModel: TLabel;
    LblOut: TLabel;
    LblProp: TLabel;
    LblPropName: TLabel;
    LblResp: TLabel;
    LblTitle: TLabel;
    MmLog: TMemo;
    ODModel: TOpenDialog;
    ODProp: TOpenDialog;
    ODResp: TOpenDialog;
    RBtBuild: TRadioButton;
    RBtPred: TRadioButton;
    RBtValidate: TRadioButton;
    SDOut: TSelectDirectoryDialog;
    SEfolds: TSpinEdit;
    procedure BtModelChoseClick(Sender: TObject);
    procedure BtOKClick(Sender: TObject);
    procedure BtOutChoseClick(Sender: TObject);
    procedure BtPropChoseClick(Sender: TObject);
    procedure BtQuitClick(Sender: TObject);
    procedure BtRespChoseClick(Sender: TObject);
    procedure MmLogChange(Sender: TObject);
    procedure RBtBuildChange(Sender: TObject);
    procedure RBtPredChange(Sender: TObject);
    procedure RBtValidateChange(Sender: TObject);
  private

  public

  end;

var
  FrmxGTMClass: TFrmxGTMClass;

implementation

{$R *.lfm}

{ TFrmxGTMClass }

procedure TFrmxGTMClass.BtQuitClick(Sender: TObject);
begin
  {$IfDef DARWIN}Halt;{$EndIf}
  {$IfNDef DARWIN}Application.Terminate;{$EndIf}

end;

procedure TFrmxGTMClass.BtRespChoseClick(Sender: TObject);
var
  ip: integer;
  stmp0,stmp1:string;
begin
  if ODResp.Execute then
  begin
    stmp0:=ODResp.FileName;
    EdtResp.Text:=stmp0;
    ip:=Pos('R.svm',stmp0);
    if ip=0 then ip:=Pos('R.SVM',stmp0);
    if ip<>0 then
    begin
      stmp1:=Copy(EdtResp.Text,1,ip-1)+'.prp';
      if not FileExists(stmp1) then stmp1:=Copy(EdtResp.Text,1,ip-1)+'.PRP';
      if FileExists(stmp1) then EdtProp.Text:=stmp1;
    end;
    if RBtPred.Checked=True then
    begin
      if ip<>0 then
      begin
        stmp1:=Copy(EdtResp.Text,1,ip-1)+'_cls_pred';
        EdtOut.Text:=stmp1;
      end;
    end;
  end;
end;

procedure TFrmxGTMClass.MmLogChange(Sender: TObject);
begin
  MmLog.SelStart:=MmLog.Lines.Text.Length-1;
end;

procedure TFrmxGTMClass.RBtBuildChange(Sender: TObject);
var
  ip: integer;
  stmp0, stmp1, stmp2:string;
begin
  if RBtBuild.Checked then
  begin
    SEfolds.Enabled:=False;
    LblFolds.Enabled:=False;
    LblAuthor.Enabled:=True;
    EdtAuthor.Enabled:=True;
    LblTitle.Enabled:=True;
    EdtTitle.Enabled:=True;
    LblComment.Enabled:=True;
    EdtComment.Enabled:=True;
    LblPropName.Enabled:=True;
    EdtPropName.Enabled:=True;
    FSEminResp.Enabled:=True;
    FSEminDens.Enabled:=True;
    FSEClsThrd.Enabled:=True;
    CBclassNormalize.Enabled:=True;
    //
    LblModel.Caption:='GTM file:';
    EdtModel.Hint:='File name of the GTM model (XML)';
    EdtModel.TextHint:=''; //Reinit the text hint before getting the new value
    EdtModel.TextHint:='Enter a GTM model file name (XML)';
    // Automatic fill the form.
    ip:=Pos('_cls',EdtModel.Text);
    if ip<>0 then
    begin
      stmp0:=Copy(EdtModel.Text,1,ip-1)+'.xml';
      stmp1:=Copy(EdtModel.Text,1,ip-1)+'.XML';
      stmp2:='';
      if FileExists(stmp0) then stmp2:=stmp0
      else if FileExists(stmp1) then stmp2:=stmp1
      else
      begin
        stmp0:=TrimRightSet(ExtractFileNameWithoutExt(EdtResp.Text),['R']);
        stmp1:=stmp0+'.XML';
        stmp0:=stmp0+'.xml';
        //stmp0:=ExtractFileNameWithoutExt(EdtResp.Text)+'.xml';
        //stmp1:=ExtractFileNameWithoutExt(EdtResp.Text)+'.XML';
        if FileExists(stmp0) then stmp2:=stmp0
        else if FileExists(stmp1) then stmp2:=stmp1;
      end;
      EdtModel.Text:=stmp2;
    end;
    stmp0:=ExtractFileNameWithoutExt(EdtProp.Text)+'_cls';
    if stmp0 <> EdtOut.Text then EdtOut.Text:=stmp0;
  end;
end;

procedure TFrmxGTMClass.RBtPredChange(Sender: TObject);
var
  ip: integer;
  stmp0,stmp1,stmp2: string;
begin
  if RBtPred.Checked then
  begin
    SEfolds.Enabled:=False;
    LblFolds.Enabled:=False;
    LblAuthor.Enabled:=False;
    EdtAuthor.Enabled:=False;
    LblTitle.Enabled:=False;
    EdtTitle.Enabled:=False;
    LblComment.Enabled:=False;
    EdtComment.Enabled:=False;
    LblPropName.Enabled:=False;
    EdtPropName.Enabled:=False;
    FSEminResp.Enabled:=False;
    FSEminDens.Enabled:=False;
    FSEClsThrd.Enabled:=False;
    CBclassNormalize.Enabled:=False;
    //
    LblModel.Caption:='Landscape model file:';
    EdtModel.Hint:='File name of the Landscape model (XML)';
    EdtModel.TextHint:='';
    EdtModel.TextHint:='Enter a Landscape model file name (XML)';
    //
    stmp0:=ExtractFileNameWithoutExt(EdtModel.Text)+'_cls.xml';
    stmp1:=ExtractFileNameWithoutExt(EdtModel.Text)+'_cls.XML';
    stmp2:='';
    if FileExists(stmp0) then stmp2:=stmp0
    else if FileExists(stmp1) then stmp2:=stmp1
    else if EdtProp.TextHint<>'' then
    begin
      stmp0:=ExtractFileNameWithoutExt(EdtProp.Text)+'_cls.xml';
      stmp1:=ExtractFileNameWithoutExt(EdtProp.Text)+'_cls.XML';
      if FileExists(stmp0) then stmp2:=stmp0
      else if FileExists(stmp1) then stmp2:=stmp1
    end;
    EdtModel.Text:=stmp2;
    stmp0:=ExtractFileNameWithoutExt(EdtProp.Text)+'_cls_pred';
    if stmp0 <> EdtOut.Text then EdtOut.Text:=stmp0;
  end;
end;

procedure TFrmxGTMClass.RBtValidateChange(Sender: TObject);
var
  ip: integer;
  stmp0, stmp1, stmp2: string;
begin
  if RBtValidate.Checked=True then
  begin
    SEfolds.Enabled:=True;
    LblFolds.Enabled:=True;
    LblAuthor.Enabled:=False;
    EdtAuthor.Enabled:=False;
    LblTitle.Enabled:=False;
    EdtTitle.Enabled:=False;
    LblComment.Enabled:=False;
    EdtComment.Enabled:=False;
    LblPropName.Enabled:=False;
    EdtPropName.Enabled:=False;
    FSEminResp.Enabled:=True;
    FSEminDens.Enabled:=True;
    FSEClsThrd.Enabled:=True;
    CBclassNormalize.Enabled:=True;
    //
    LblModel.Caption:='GTM file:';
    EdtModel.Hint:='File name of the GTM model (XML)';
    EdtModel.TextHint:=''; //Reinit the text hint before getting the new value
    EdtModel.TextHint:='Enter a GTM model file name (XML)';
    //
    ip:=Pos('_cls',EdtModel.Text);
    if ip<>0 then
    begin
      stmp0:=Copy(EdtModel.Text,1,ip-1)+'.xml';
      stmp1:=Copy(EdtModel.Text,1,ip-1)+'.XML';
      stmp2:='';
      if FileExists(stmp0) then stmp2:=stmp0
      else if FileExists(stmp1) then stmp2:=stmp1
      else
      begin
        stmp0:=TrimRightSet(ExtractFileNameWithoutExt(EdtResp.Text),['R']);
        stmp1:=stmp0+'.XML';
        stmp0:=stmp0+'.xml';
        if FileExists(stmp0) then stmp2:=stmp0
        else if FileExists(stmp1) then stmp2:=stmp1;
      end;
      EdtModel.Text:=stmp2;
    end;
    stmp0:=ExtractFileNameWithoutExt(EdtProp.Text)+'_cls_CV';
    if stmp0 <> EdtOut.Text then EdtOut.Text:=stmp0;
  end;
end;

procedure TFrmxGTMClass.BtOKClick(Sender: TObject);
var
  aGTMClass: TGTMClass;
  aCV: TCVsvm;
  SLtrain,SLtest,SLProp:TStringList;
  kfold,i,ii: integer;
  aClsStat: TClsStats;
  aStat,aStatSum: TAoD;
  pdbl: PDouble;
  ipos: integer;//position in string
  sres: string;
begin
  if RBtBuild.Checked=True then
  begin
    aGTMClass:= TGTMClass.Create;
    aGTMClass.ReadGTMModel(EdtModel.Text); //Setup the GTM model from the XML file
    aGTMClass.PrpName:=EdtPropName.Text;
    aGTMClass.MinRspToNode:=FSEminResp.Value;
    aGTMClass.MinDensityLS:=FSEminDens.Value;
    if CBclassNormalize.Checked then
      aGTMClass.bClassNormalize:=True
    else
      aGTMClass.bClassNormalize:=False;
    TrainLandscape(aGTMClass,EdtResp.Text,EdtProp.Text,EdtOut.Text,EdtAuthor.Text,EdtTitle.Text,EdtComment.Text,MmLog.Lines);
    FreeAndNil(aGTMClass);
  end else if RBtPred.Checked=True then
  begin
    aGTMClass:= TGTMClass.Create;
    MmLog.Lines.Add('Begin to read specified landscape and projected responsibilities.');
    readLandscape(EdtModel.Text,aGTMClass);
    MmLog.Lines.Add('Min. responsibility value for AD: '+ FloatToStr(aGTMClass.MinRspToNode)+
      ', Min. responsiblity value to contribute landscape: '+ FloatToStr(aGTMClass.MinDensityLS)+
      ', Number of nodes: '+ IntToStr(aGTMClass.K));
    if (EdtProp.Text='') or (not FileExists(EdtProp.Text)) then
      UseLandscape(aGTMClass,EdtResp.Text,EdtOut.Text,MmLog.Lines)
    else
    begin
     aClsStat:=TClsStats.Create;
     SLtest:=TStringList.Create;
     SLProp:=TStringList.Create;
     SLtest.LoadFromFile(EdtResp.Text);
     SLProp.LoadFromFile(EdtProp.Text);
     for i:=1 to SLProp.Count-1 do //Ignore line 1: a comment
     begin
       ii:=i-1;
       sres:=SLProp[i];
       ipos:=pos(' ',SLtest[ii]);
       sres:=sres+copy(SLtest[ii],ipos,Length(SLtest[ii]));
       SLtest[ii]:=sres;
     end;
     UseLandscape(aGTMClass,1,SLtest,EdtOut.Text,aClsStat,MmLog.Lines);
     FreeAndNil(SLProp);
     FreeAndNil(SLtest);
     //
     MmLog.Lines.Add('/------------ Performances ------------\');
     MmLog.Lines.Add('Accuracy          ='+FloatToStrF(aClsStat.Accuracy,ffFixed,3,4));
     MmLog.Lines.Add('Balanced Accuracy ='+FloatToStrF(aClsStat.BalancedAccuracy,ffFixed,3,4));
     for i:=1 to aGTMClass.classSL.Count-1 do
     begin
       MmLog.Lines.Add('Precision('+aGTMClass.classSL[i]+')='+FloatToStrF(aClsStat.Precision(i-1),ffFixed,3,4));
       MmLog.Lines.Add('Recall('+aGTMClass.classSL[i]+')   ='+FloatToStrF(aClsStat.Recall(i-1),ffFixed,3,4));
       MmLog.Lines.Add('F('+aGTMClass.classSL[i]+')        ='+FloatToStrF(aClsStat.Fmeasure(i-1),ffFixed,3,4));
       MmLog.Lines.Add('MCC('+aGTMClass.classSL[i]+')      ='+FloatToStrF(aClsStat.MCC(i-1),ffFixed,3,4));
     end;
    end;
    FreeAndNil(aClsStat);
    FreeAndNil(aGTMClass);
  end else if RBtValidate.Checked=True then
  begin
    //Setup cross validation
    aClsStat:=TClsStats.Create; //A place to store exp and pred values and compute statistics
    SLtrain:=TStringList.Create;
    SLtest:= TStringList.Create;
    aCV:=TCVsvm.Create;
    aCV.Nfolds:=SEfolds.Value;
    aCV.SetSLSVMFromFileAndProp(EdtResp.Text,EdtProp.Text);//Property values are attached in column 1
    //Do CV
    SetLength(aStat,2);
    SetLength(aStatSum,2);
    for i:=Low(aStatSum) to high(aStatSum) do aStatSum[i]:=0;
    for kfold:=1 to aCV.Nfolds do
    begin
      aCV.GenerateFold(kfold,SLtrain,SLtest);
      aGTMClass:= TGTMClass.Create;
      aGTMClass.MinRspToNode:=FSEminResp.Value;
      aGTMClass.MinDensityLS:=FSEminDens.Value;
      aGTMClass.ReadGTMModel(EdtModel.Text); //Setup the GTM model from the XML file
      aGTMClass.PrpName:=EdtPropName.Text;
      if CBclassNormalize.Checked then
        aGTMClass.bClassNormalize:=True
      else
        aGTMClass.bClassNormalize:=False;
      TrainLandscape(aGTMClass,SLtrain,EdtOut.Text+'_train-fold'+IntToStr(kfold),EdtAuthor.Text,EdtTitle.Text,EdtComment.Text,MmLog.Lines);
      aGTMClass.SetMolCountToZero;
      UseLandscape(aGTMClass,1,SLtest,EdtOut.Text+'_test-fold'+IntToStr(kfold),aClsStat,MmLog.Lines);
      //Output results
      aStat[0]:=aClsStat.Accuracy();
      aStat[1]:=aClsStat.BalancedAccuracy();
      for i:=Low(aStatSum) to High(aStatSum) do
        aStatSum[i]:=aStatSum[i]+aStat[i];
      MmLog.Lines.Add('*------------- fold '+IntToStr(kfold)+' -------------*');
      MmLog.Lines.Add('Accuracy         ='+FloatToStrF(aStat[0],ffFixed,3,4));
      MmLog.Lines.Add('Balanced Accuracy ='+FloatToStrF(aStat[1],ffFixed,3,4));
      //
      FreeAndNil(aGTMClass);
    end;
    // Averaged performances
    for i:=Low(aStatSum) to High(aStatSum) do
      aStatSum[i]:=aStatSum[i]/kfold;
    MmLog.Lines.Add('************** Averaged performances **************');
    MmLog.Lines.Add('Accuracy          ='+FloatToStrF(aStatSum[0],ffFixed,3,4));
    MmLog.Lines.Add('Balanced Accuracy ='+FloatToStrF(aStatSum[1],ffFixed,3,4));
    //
    FreeAndNil(aClsStat);
    FreeAndNil(aCV);
    FreeAndNil(SLtrain);
    FreeAndNil(SLtest);
  end;
  MmLog.Lines.Add('.............. Calculations complete ..............');
end;

procedure TFrmxGTMClass.BtOutChoseClick(Sender: TObject);
begin
  if SDOut.Execute then
    EdtOut.Text:=SDOut.FileName+ChangeFileExt(ODProp.FileName,'_cls');
end;

procedure TFrmxGTMClass.BtPropChoseClick(Sender: TObject);
begin
  if ODProp.Execute then
    EdtProp.Text:=ODProp.FileName;
  if EdtProp.Text<>'' then
  begin
    if RBtBuild.Checked then
      EdtOut.Text:=ExtractFileNameWithoutExt(EdtProp.Text)+'_cls'
    else if RBtPred.Checked then
      EdtOut.Text:=ExtractFileNameWithoutExt(EdtProp.Text)+'_cls_pred'
    else if RBtValidate.Checked then
      EdtOut.Text:=ExtractFileNameWithoutExt(EdtProp.Text)+'_cls_CV';
  end;
end;

procedure TFrmxGTMClass.BtModelChoseClick(Sender: TObject);
var
  stmp: string;
begin
  if ODModel.Execute then
  begin
    EdtModel.Text:=ODModel.FileName;
    stmp:=ChangeFileExt(ODModel.FileName,'R.svm');
    if FileExists(stmp) then
      EdtResp.Text:=stmp;
    stmp:=ChangeFileExt(ODModel.FileName,'.prp');
    if FileExists(stmp) then
      EdtProp.Text:=stmp;
    if EdtProp.Text<>'' then
    begin
      if RBtBuild.Checked then
        EdtOut.Text:=ExtractFileNameWithoutExt(EdtProp.Text)+'_cls'
      else if RBtPred.Checked then
        EdtOut.Text:=ExtractFileNameWithoutExt(EdtProp.Text)+'_cls_pred'
      else if RBtValidate.Checked then
        EdtOut.Text:=ExtractFileNameWithoutExt(EdtProp.Text)+'_cls_CV';
    end else
    begin
      if (RBtBuild.Checked=True) or (RBtValidate.Checked=True) then
        EdtOut.Text:=ChangeFileExt(ODModel.FileName,'_cls')
      else if RBtPred.Checked=True then EdtOut.Text:=ExtractFileDir(ODModel.FileName)+DirectorySeparator+'Predictions' ;
    end;
  end;
end;

end.

