unit uxGTMreg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Spin,
  strutils, UGTMReg, GTMRegFunctions, UnitClsStat, UnitCVsvm, FileUtil, LazFileUtils;

type

  { TFrmGTMReg }

  TFrmGTMReg = class(TForm)
    BtOK: TButton;
    BtQuit: TButton;
    BtModelChose: TButton;
    BtRespChose: TButton;
    BtOutChose: TButton;
    BtPropChose: TButton;
    EdtAuthor: TEdit;
    EdtPropName: TEdit;
    EdtTitle: TEdit;
    EdtProp: TEdit;
    EdtOut: TEdit;
    EdtResp: TEdit;
    EdtModel: TEdit;
    EdtComment: TEdit;
    FSEminDens: TFloatSpinEdit;
    FSEminResp: TFloatSpinEdit;
    FSETthrd: TFloatSpinEdit;
    FSETtau: TFloatSpinEdit;
    FSEminRespAD: TFloatSpinEdit;
    FSETalpha: TFloatSpinEdit;
    FSETbeta: TFloatSpinEdit;
    LblFolds: TLabel;
    LblAuthor: TLabel;
    LblMinDens: TLabel;
    LblminResp: TLabel;
    LblTthrd: TLabel;
    LblTtau: TLabel;
    LblminRespAD: TLabel;
    LblPropName: TLabel;
    LblTitle: TLabel;
    LblProp: TLabel;
    LblOut: TLabel;
    LblResp: TLabel;
    LblModel: TLabel;
    LblComment: TLabel;
    LblTalpha: TLabel;
    LblTbeta: TLabel;
    MmLog: TMemo;
    ODModel: TOpenDialog;
    ODResp: TOpenDialog;
    ODProp: TOpenDialog;
    RBtValidate: TRadioButton;
    RBtBuild: TRadioButton;
    RBtPred: TRadioButton;
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
  FrmGTMReg: TFrmGTMReg;

implementation

{$R *.lfm}

{ TFrmGTMReg }

procedure TFrmGTMReg.BtQuitClick(Sender: TObject);
begin
  {$IfDef DARWIN}Halt;{$EndIf}
  {$IfNDef DARWIN}Application.Terminate;{$EndIf}
end;

procedure TFrmGTMReg.BtRespChoseClick(Sender: TObject);
var
  ip: integer;
  stmp0,stmp1:string;
begin
  if ODResp.Execute then
  begin
    stmp0:=ODResp.FileName;
    EdtResp.Text:=stmp0;
    ip:=Pos('R.svm',stmp0);
    if ip=0 then ip:=Pos('R.svm',stmp0);
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
        stmp1:=Copy(EdtResp.Text,1,ip-1)+'_reg_pred';
        EdtOut.Text:=stmp1;
      end;
    end;
  end;
end;

procedure TFrmGTMReg.MmLogChange(Sender: TObject);
begin
  MmLog.SelStart:=MmLog.Lines.Text.Length-1;
end;

procedure TFrmGTMReg.RBtBuildChange(Sender: TObject);
var
  ip: integer;
  stmp0, stmp1, stmp2: string;
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
    //
    LblModel.Caption:='GTM file:';
    EdtModel.Hint:='File name of the GTM model (XML)';
    EdtModel.TextHint:=''; //Reinit the text hint before getting the new value
    EdtModel.TextHint:='Enter a GTM model file name (XML)';
    // Automatic fill the form.
    ip:=Pos('_reg',EdtModel.Text);
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
    stmp0:=ExtractFileNameWithoutExt(EdtProp.Text)+'_reg';
    if stmp0 <> EdtOut.Text then EdtOut.Text:=stmp0;
  end;
end;

procedure TFrmGTMReg.RBtPredChange(Sender: TObject);
var
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
    //
    LblModel.Caption:='Landscape model file:';
    EdtModel.Hint:='File name of the Landscape model (XML)';
    EdtModel.TextHint:='';
    EdtModel.TextHint:='Enter a Landscape model file name (XML)';
    //
    stmp0:=ExtractFileNameWithoutExt(EdtModel.Text)+'_reg.xml';
    stmp1:=ExtractFileNameWithoutExt(EdtModel.Text)+'_reg.XML';
    stmp2:='';
    if FileExists(stmp0) then stmp2:=stmp0
    else if FileExists(stmp1) then stmp2:=stmp1
    else if EdtProp.TextHint<>'' then
    begin
      stmp0:=ExtractFileNameWithoutExt(EdtProp.Text)+'_reg.xml';
      stmp1:=ExtractFileNameWithoutExt(EdtProp.Text)+'_reg.XML';
      if FileExists(stmp0) then stmp2:=stmp0
      else if FileExists(stmp1) then stmp2:=stmp1
    end;
    EdtModel.Text:=stmp2;
    stmp0:=ExtractFileNameWithoutExt(EdtProp.Text)+'_reg_pred';
    if stmp0 <> EdtOut.Text then EdtOut.Text:=stmp0;
  end;
end;

procedure TFrmGTMReg.RBtValidateChange(Sender: TObject);
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
    //
    LblModel.Caption:='GTM file:';
    EdtModel.Hint:='File name of the GTM model (XML)';
    EdtModel.TextHint:=''; //Reinit the text hint before getting the new value
    EdtModel.TextHint:='Enter a GTM model file name (XML)';
    //
    ip:=Pos('_reg',EdtModel.Text);
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
    stmp0:=ExtractFileNameWithoutExt(EdtProp.Text)+'_reg_CV';
    if stmp0 <> EdtOut.Text then EdtOut.Text:=stmp0;
  end;
end;

procedure TFrmGTMReg.BtOutChoseClick(Sender: TObject);
begin
  if SDOut.Execute then
    EdtOut.Text:=SDOut.FileName+ChangeFileExt(ODProp.FileName,'_reg');
end;

procedure TFrmGTMReg.BtPropChoseClick(Sender: TObject);
begin
  if ODProp.Execute then
    EdtProp.Text:=ODProp.FileName;
  if EdtProp.Text<>'' then
  begin
    if RBtBuild.Checked then
      EdtOut.Text:=ExtractFileNameWithoutExt(EdtProp.Text)+'_reg'
    else if RBtPred.Checked then
      EdtOut.Text:=ExtractFileNameWithoutExt(EdtProp.Text)+'_reg_pred'
    else if RBtValidate.Checked then
      EdtOut.Text:=ExtractFileNameWithoutExt(EdtProp.Text)+'_reg_CV';
  end;
end;

procedure TFrmGTMReg.BtModelChoseClick(Sender: TObject);
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
        EdtOut.Text:=ExtractFileNameWithoutExt(EdtProp.Text)+'_reg'
      else if RBtPred.Checked then
        EdtOut.Text:=ExtractFileNameWithoutExt(EdtProp.Text)+'_reg_pred'
      else if RBtValidate.Checked then
        EdtOut.Text:=ExtractFileNameWithoutExt(EdtProp.Text)+'_reg_CV';
    end else
    begin
      if (RBtBuild.Checked=True) or (RBtValidate.Checked=True) then
        EdtOut.Text:=ChangeFileExt(ODModel.FileName,'_reg')
      else if RBtPred.Checked=True then EdtOut.Text:=ExtractFileDir(ODModel.FileName)+DirectorySeparator+'Predictions' ;
    end;
  end;
end;

procedure TFrmGTMReg.BtOKClick(Sender: TObject);
var
  aGTMReg: TGTMReg;
  aCV: TCVsvm;
  SLtrain,SLtest,SLProp:TStringList;
  kfold,i,ii: integer;
  aClsStat: TClsStat;
  aStat,aStatSum: TAoD;
  pdbl: PDouble;
begin
  if RBtBuild.Checked=True then
  begin
    aGTMReg:= TGTMReg.Create;
    aGTMReg.ReadGTMModel(EdtModel.Text); //Setup the GTM model from the XML file
    aGTMReg.PrpName:=EdtPropName.Text;
    aGTMReg.MinRspToNode:=FSEminResp.Value;
    aGTMReg.MinDensityLS:=FSEminDens.Value;
    aGTMReg.MinRspAD:=FSEminRespAD.Value;
    aGTMReg.dTtau:=FSETtau.Value;
    aGTMReg.dTalpha:=FSETalpha.Value;
    aGTMReg.dTbeta:=FSETbeta.Value;
    aGTMReg.dTT:=FSETthrd.Value;
    TrainLandscape(aGTMReg,EdtResp.Text,EdtProp.Text,EdtOut.Text,EdtAuthor.Text,EdtTitle.Text,EdtComment.Text,MmLog.Lines);
    FreeAndNil(aGTMReg);
  end else if RBtPred.Checked=True then
  begin
    aGTMReg:= TGTMReg.Create;
    MmLog.Lines.Add('Begin to read specified landscape and projected responsibilities.');
    readLandscape(EdtModel.Text,aGTMReg);
    if (aGTMReg=nil) then exit;
    MmLog.Lines.Add('Min. responsibility on labeled nodes for AD: '+ FloatToStr(aGTMReg.MinRspAD)+
      ', Min. responsiblity value to contribute landscape: '+ FloatToStr(aGTMReg.MinRspToNode)+
      ', Min. density value to contribute landscape: '+ FloatToStr(aGTMReg.MinDensityLS)+
      ', Number of nodes: '+ IntToStr(aGTMReg.K));
    if (EdtProp.Text='') or (not FileExists(EdtProp.Text)) then
      UseLandscape(aGTMReg,EdtResp.Text,EdtOut.Text,MmLog.Lines)
    else
    begin
     aClsStat:=TClsStat.Create;
     SLtest:=TStringList.Create;
     SLProp:=TStringList.Create;
     SLtest.LoadFromFile(EdtResp.Text);
     SLProp.LoadFromFile(EdtProp.Text);
     for i:=1 to SLProp.Count-1 do //Ignore line 1: a comment
     begin
       new(pdbl);
       pdbl^:=StrToFloat(SLProp[i]);
       SLtest.Objects[i-1]:=TObject(pdbl);
     end;
     UseLandscape(aGTMReg,SLtest,EdtOut.Text,aClsStat,MmLog.Lines);
     for i:=0 to SLtest.Count-1 do
     begin
       pdbl:=Pdouble(SLtest.Objects[i]);
       if pdbl<>nil then dispose(pdbl);
     end;
     FreeAndNil(SLProp);
     FreeAndNil(SLtest);
     //
     MmLog.Lines.Add('/------------ Performances ------------\');
     MmLog.Lines.Add('RMSE         ='+FloatToStrF(aClsStat.RMSE(),ffFixed,3,4));
     MmLog.Lines.Add('MAE          ='+FloatToStrF(aClsStat.MAE(),ffFixed,3,4));
     MmLog.Lines.Add('Relative RMSE='+FloatToStrF(aClsStat.RelRMSE(),ffFixed,3,4));
     MmLog.Lines.Add('Relative MAE ='+FloatToStrF(aClsStat.RelMAE(),ffFixed,3,4));
     MmLog.Lines.Add('R2det        ='+FloatToStrF(aClsStat.R2det(),ffFixed,3,4));
     MmLog.Lines.Add('CCC          ='+FloatToStrF(aClsStat.CCC(),ffFixed,3,4));
     MmLog.Lines.Add('R2cor        ='+FloatToStrF(aClsStat.R2cor(),ffFixed,3,4));
    end;
    FreeAndNil(aClsStat);
    FreeAndNil(aGTMReg);
  end else if RBtValidate.Checked=True then
  begin
    //Setup cross validation
    aClsStat:=TClsStat.Create; //A place to store exp and pred values and compute statistics
    SLtrain:=TStringList.Create;
    SLtest:= TStringList.Create;
    aCV:=TCVsvm.Create;
    aCV.Nfolds:=SEfolds.Value;
    aCV.SetSLSVMFromFileAndPropP(EdtResp.Text,EdtProp.Text);//Property values are attached to the responsibilities via a pointer
    //Do CV
    SetLength(aStat,7);
    SetLength(aStatSum,7);
    for i:=Low(aStatSum) to high(aStatSum) do aStatSum[i]:=0;
    for kfold:=1 to aCV.Nfolds do
    begin
      aCV.GenerateFold(kfold,SLtrain,SLtest);
      aGTMReg:= TGTMReg.Create;
      aGTMReg.ReadGTMModel(EdtModel.Text); //Setup the GTM model from the XML file
      aGTMReg.PrpName:=EdtPropName.Text;
      aGTMReg.MinRspToNode:=FSEminResp.Value;
      aGTMReg.MinDensityLS:=FSEminDens.Value;
      aGTMReg.MinRspAD:=FSEminRespAD.Value;
      aGTMReg.dTtau:=FSETtau.Value;
      aGTMReg.dTalpha:=FSETalpha.Value;
      aGTMReg.dTbeta:=FSETbeta.Value;
      aGTMReg.dTT:=FSETthrd.Value;
      TrainLandscape(aGTMReg,SLtrain,EdtOut.Text+'_train-fold'+IntToStr(kfold),EdtAuthor.Text,EdtTitle.Text,EdtComment.Text,MmLog.Lines);
      UseLandscape(aGTMReg,SLtest,EdtOut.Text+'_test-fold'+IntToStr(kfold),aClsStat,MmLog.Lines);
      //Output results
      aStat[0]:=aClsStat.RMSE();
      aStat[1]:=aClsStat.MAE();
      aStat[2]:=aClsStat.RelRMSE();
      aStat[3]:=aClsStat.RelMAE();
      aStat[4]:=aClsStat.CCC();
      aStat[5]:=aClsStat.R2det();
      aStat[6]:=aClsStat.R2cor();
      for i:=Low(aStatSum) to High(aStatSum) do
        aStatSum[i]:=aStatSum[i]+aStat[i];
      MmLog.Lines.Add('*------------- fold '+IntToStr(kfold)+' -------------*');
      MmLog.Lines.Add('RMSE         ='+FloatToStrF(aStat[0],ffFixed,3,4));
      MmLog.Lines.Add('MAE          ='+FloatToStrF(aStat[1],ffFixed,3,4));
      MmLog.Lines.Add('Relative RMSE='+FloatToStrF(aStat[2],ffFixed,3,4));
      MmLog.Lines.Add('Relative MAE ='+FloatToStrF(aStat[3],ffFixed,3,4));
      MmLog.Lines.Add('R2det        ='+FloatToStrF(aStat[4],ffFixed,3,4));
      MmLog.Lines.Add('CCC          ='+FloatToStrF(aStat[5],ffFixed,3,4));
      MmLog.Lines.Add('R2cor        ='+FloatToStrF(aStat[6],ffFixed,3,4));
      //
      FreeAndNil(aGTMReg);
    end;
    // Averaged performances
    for i:=Low(aStatSum) to High(aStatSum) do
      aStatSum[i]:=aStatSum[i]/kfold;
    MmLog.Lines.Add('************** Averaged performances **************');
    MmLog.Lines.Add('RMSE         ='+FloatToStrF(aStatSum[0],ffFixed,3,4));
    MmLog.Lines.Add('MAE          ='+FloatToStrF(aStatSum[1],ffFixed,3,4));
    MmLog.Lines.Add('Relative RMSE='+FloatToStrF(aStatSum[2],ffFixed,3,4));
    MmLog.Lines.Add('Relative MAE ='+FloatToStrF(aStatSum[3],ffFixed,3,4));
    MmLog.Lines.Add('R2det        ='+FloatToStrF(aStatSum[4],ffFixed,3,4));
    MmLog.Lines.Add('CCC          ='+FloatToStrF(aStatSum[5],ffFixed,3,4));
    MmLog.Lines.Add('R2cor        ='+FloatToStrF(aStatSum[6],ffFixed,3,4));
    //
    FreeAndNil(aClsStat);
    FreeAndNil(aCV);
    FreeAndNil(SLtrain);
    FreeAndNil(SLtest);
  end;
  MmLog.Lines.Add('.............. Calculations complete ..............');
end;

end.

