unit uxGTMapTool;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ugtm_options, UnitProc;

type

  { TFGTMapTool }

  TFGTMapTool = class(TForm)
    BtOK: TButton;
    BtQuit: TButton;
    BtSVMfile: TButton;
    BtOut: TButton;
    CBPreprocess: TComboBox;
    Edn: TEdit;
    EdOut: TEdit;
    Edk: TEdit;
    Edm: TEdit;
    Edw: TEdit;
    EdSVMfile: TEdit;
    Edl: TEdit;
    Lbln: TLabel;
    LblOut: TLabel;
    Lblk: TLabel;
    LblInputSVM: TLabel;
    Lblm: TLabel;
    Lblw: TLabel;
    Lbll: TLabel;
    MLog: TMemo;
    ODlgSVMfile: TOpenDialog;
    ODlgOut: TSelectDirectoryDialog;
    procedure BtOKClick(Sender: TObject);
    procedure BtOutClick(Sender: TObject);
    procedure BtQuitClick(Sender: TObject);
    procedure BtSVMfileClick(Sender: TObject);
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
  Application.Terminate;
end;

procedure TFGTMapTool.BtOutClick(Sender: TObject);
begin
  if ODlgOut.Execute then
    EdOut.Text:=ODlgOut.FileName;
end;

procedure TFGTMapTool.BtOKClick(Sender: TObject);
var
  GTMOpt: TRGtmOptions;
  SLog: TStringList;
  bErr: boolean;
begin
  bErr:=False;
  GTMOpt:=TRGtmOptions.Create;
  GTMOpt.GTMType:=BISHOP;
  GTMOpt.inputFile:=EdSVMfile.Text;
  GTMOpt.outputFile:=EdOut.Text;
  try
    GTMOpt.sqrtSamples:=StrToInt(Edk.Text);
    GTMOpt.sqrtCenters:=StrToInt(Edm.Text);
    GTMOpt.nIter:=StrToInt(Edn.Text);
    GTMOpt.alpha:=StrToFloat(Edl.Text);
    GTMOpt.sigma:=StrToFloat(Edw.Text);
    GTMOpt.preprocess:=CBPreprocess.ItemIndex;
  except
    ShowMessage('ERROR: invalid input.');
    bErr:=True;
  end;
  If (not bErr) then
  begin
    SLog:=TStringList(MLog.Lines);// TStringList.Create;
    Welcome(SLog);
    //MLog.Lines.Add(SLog.Text);
    Application.ProcessMessages;
    //SLog.Clear;
    GTMOpt.WriteOptions(SLog);
    //MLog.Lines.Add(SLog.Text);
    Application.ProcessMessages;
    //SLog.Clear;
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
  FreeAndNil(GTMOpt);
end;

procedure TFGTMapTool.BtSVMfileClick(Sender: TObject);
begin
  if ODlgSVMfile.Execute then
    EdSVMfile.Text:=ODlgSVMfile.FileName;
    EdOut.Text:=ChangeFileExt(EdSVMfile.Text,'');
end;

end.

