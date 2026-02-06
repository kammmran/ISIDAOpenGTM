unit uxGTMapTool;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, SpinEx, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ExtCtrls, MaskEdit, ugtm_options, UnitProc;

type

  { TFGTMapTool }

  TFGTMapTool = class(TForm)
    BtOK: TButton;
    BtModel: TButton;
    BtQuit: TButton;
    BtSVMfile: TButton;
    BtOut: TButton;
    BtPC123: TButton;
    CBPreprocess: TComboBox;
    CBSaveInfo: TCheckBox;
    CBScaleInit: TComboBox;
    EdConv: TEdit;
    EdPC123: TEdit;
    Edn: TEdit;
    EdOut: TEdit;
    Edk: TEdit;
    Edm: TEdit;
    EdModel: TEdit;
    Edw: TEdit;
    EdSVMfile: TEdit;
    Edl: TEdit;
    FSEScaleInit: TFloatSpinEditEx;
    LblPC123: TLabel;
    LblScaleInit: TLabel;
    LblConv: TLabel;
    Lbln: TLabel;
    LblOut: TLabel;
    Lblk: TLabel;
    LblInputSVM: TLabel;
    Lblm: TLabel;
    LblModel: TLabel;
    Lblw: TLabel;
    Lbll: TLabel;
    MLog: TMemo;
    ODlgModel: TOpenDialog;
    ODlgSVMfile: TOpenDialog;
    ODlgOut: TSelectDirectoryDialog;
    ODPC123: TOpenDialog;
    RGTrainUse: TRadioGroup;
    procedure BtModelClick(Sender: TObject);
    procedure BtOKClick(Sender: TObject);
    procedure BtOutClick(Sender: TObject);
    procedure BtPC123Click(Sender: TObject);
    procedure BtQuitClick(Sender: TObject);
    procedure BtSVMfileClick(Sender: TObject);
    procedure CBScaleInitChange(Sender: TObject);
    procedure RGTrainUseSelectionChanged(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  FGTMapTool: TFGTMapTool;

implementation

{$R *.lfm}

{ TFGTMapTool }

procedure TFGTMapTool.BtQuitClick(Sender: TObject);
begin
  {$IfDef DARWIN}Halt;{$EndIf}
  {$IfNDef DARWIN}Application.Terminate;{$EndIf}
end;

procedure TFGTMapTool.BtOutClick(Sender: TObject);
begin
  if ODlgOut.Execute then
    EdOut.Text:=ODlgOut.FileName;
end;

procedure TFGTMapTool.BtPC123Click(Sender: TObject);
begin
  if (ODPC123.Execute) then
    EdPC123.Text:=ODPC123.FileName;
end;

procedure TFGTMapTool.BtOKClick(Sender: TObject);
var
  GTMOpt: TRGtmOptions;
  SLog: TStringList;
  bErr: boolean;
begin
  BtOK.Enabled:=False;
  bErr:=False;
  GTMOpt:=TRGtmOptions.Create;
  GTMOpt.GTMType:=BISHOP;
  GTMOpt.outputFile:=EdOut.Text;
  GTMOpt.modelFile:=EdModel.Text;
  GTMOpt.doProjection:=False;
  if RGTrainUse.ItemIndex<=0 then
    GTMOpt.inputFile:=EdSVMfile.Text
  else
  begin
    GTMOpt.doProjection:=True;
    GTMOpt.projFile:=EdSVMfile.Text;
  end;
  if CBSaveInfo.Checked=True then
    GTMOpt.p3D:=True;
  try
    GTMOpt.iScaleInit:=CBScaleInit.ItemIndex;
    GTMOpt.fScaleInit:=FSEScaleInit.Value;
    GTMOpt.PCAFile:=EdPC123.Text;
    GTMOpt.nSamples:=StrToInt(Edk.Text);
    GTMOpt.nCenters:=StrToInt(Edm.Text);
    GTMOpt.nIter:=StrToInt(Edn.Text);
    GTMOpt.alpha:=StrToFloat(Edl.Text);
    GTMOpt.sigma:=StrToFloat(Edw.Text);
    GTMOpt.preprocess:=CBPreprocess.ItemIndex;
    if(CBPreprocess.ItemIndex=-1) then begin
      GTMOpt.preprocess:=0;
      CBPreprocess.ItemIndex:=0;
      CBPreprocess.Refresh;
    end;
    //GTMOpt.convCriteria:=;
  except
    ShowMessage('ERROR: invalid input.');
    bErr:=True;
  end;
  If (not bErr) then
  begin
    SLog:=TStringList(MLog.Lines);// TStringList.Create;
    //MLog.SelStart:=Length(MLog.Text);
    if RGTrainUse.ItemIndex<=0 then begin //Default training setup
      if (GTMOpt.nSamples<=0) then
      begin
        if (GTMOpt.sigma=-1) then //default nSamples and sigma
        begin
          GTMOpt.sigma:=2*sqrt(4/GTMOpt.nCenters);//sigma=2*(spacing between RBF)
          GTMOpt.nSamples := 25*GTMOpt.nCenters;//Round(sqr(5.64 /GTMOptions.sigma));
        end else //default nSample but sigma defined
          GTMOpt.nSamples := 25*GTMOpt.nCenters;//Round(sqr(5.64 /GTMOptions.sigma));
      end else if (GTMOpt.sigma=-1) then //defined nSample but sigma undefined
        GTMOpt.sigma := 5.64 / sqrt(GTMOpt.nSamples); // Recommendation to have O(100) samples within 2 sigma radius
      // nSample and sigma defined: nothing to do
      if (GTMOpt.alpha=-1) then
        GTMOpt.alpha := 1; // Each weight defining the GTM manifold obeys a standard normal distribution
      //Welcome(SLog);
      //if GTMOpt.projFile='' then GTMOpt.projFile:=GTMOpt.inputFile;
      Application.ProcessMessages;
      GTMOpt.WriteOptions(SLog);
      Application.ProcessMessages;
    end else
    begin
         ReadGTMModel(GTMOpt,GTMOpt.modelFile,SLog);
         Application.ProcessMessages;
    end;
    //Program continues
    case GTMOpt.GTMType of
      BISHOP:
        begin
          if (GTMOpt.nBlocks<1) then DoClassicGTM(GTMOpt,SLog)
          else DoClassicGTMb(GTMOpt,SLog);
        end;
      INCREMENTAL: DoIncrementalGTM(GTMOpt,SLog);
      MULTINOMIAL:
        begin
          if GTMOpt.nBlocks<1 then DoMultinomialGTM(GTMOpt,SLog)
          else DoMultinomialGTMb(GTMOpt,SLog);
        end
    else begin
        Exception.Create('ERROR: GTM type not recognized');
        Application.Terminate;
      end;
    end;
    //FreeAndNil(SLog);
    MLog.Lines.Add('***All calculations finished successfully!***');
  end;
  BtOK.Enabled:=True;
  FreeAndNil(GTMOpt);
end;

procedure TFGTMapTool.BtModelClick(Sender: TObject);
begin
  if ODlgModel.Execute then
    EdModel.Text:=ODlgModel.FileName;
end;


procedure TFGTMapTool.BtSVMfileClick(Sender: TObject);
begin
  if ODlgSVMfile.Execute then
    EdSVMfile.Text:=ODlgSVMfile.FileName;
    EdOut.Text:=ChangeFileExt(EdSVMfile.Text,'');
end;

procedure TFGTMapTool.CBScaleInitChange(Sender: TObject);
begin
  If CBScaleInit.ItemIndex=2 then FSEScaleInit.Visible:=True
  else FSEScaleInit.Visible:=False;
end;

procedure TFGTMapTool.RGTrainUseSelectionChanged(Sender: TObject);
//Update the interface from traning to using a map
begin
  If RGTrainUse.ItemIndex=1 then
  begin
    CBSaveInfo.Enabled:=True;
    EdModel.Enabled:=True;
    LblModel.Enabled:=True;
    BtModel.Enabled:=True;
    Lblk.Visible:=False;
    Lblm.Visible:=False;
    Lbll.Visible:=False;
    Lblw.Visible:=False;
    LblConv.Visible:=False;
    Lbln.Visible:=False;
    Edk.Visible:=False;
    Edm.Visible:=False;
    Edl.Visible:=False;
    Edw.Visible:=False;
    Edn.Visible:=False;
    EdConv.Visible:=False;
    CBPreprocess.Visible:=False;
    EdModel.Text:='';
    //
    CBScaleInit.Visible:=False;
    LblScaleInit.Visible:=False;
    FSEScaleInit.Visible:=False;
    //
    LblPC123.Visible:=False;
    EdPC123.Visible:=False;
    BtPC123.Visible:=False;
  end else
  begin
    EdModel.Text:='';
    CBSaveInfo.Enabled:=False;
    EdModel.Enabled:=False;
    LblModel.Enabled:=False;
    BtModel.Enabled:=False;
    Lblk.Visible:=True;
    Lblm.Visible:=True;
    Lbll.Visible:=True;
    Lblw.Visible:=True;
    LblConv.Visible:=True;
    Lbln.Visible:=True;
    Edk.Visible:=True;
    Edm.Visible:=True;
    Edl.Visible:=True;
    Edw.Visible:=True;
    Edn.Visible:=True;
    EdConv.Visible:=True;
    CBPreprocess.Visible:=True;
    //
    CBScaleInit.Visible:=True;
    LblScaleInit.Visible:=True;
    FSEScaleInit.Visible:=(CBScaleInit.ItemIndex=2);
    //
    LblPC123.Visible:=True;
    EdPC123.Visible:=True;
    BtPC123.Visible:=True;
  end;
end;

end.

