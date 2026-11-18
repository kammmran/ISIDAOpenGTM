unit unit_xgtmresample;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Spin, UnitGTMReSampleProc, unit_GTMReSample_option, FileUtil, LazFileUtils;

type

  { TFrmGTMReSample }

  TFrmGTMReSample = class(TForm)
    BtModel: TButton;
    BtSVM: TButton;
    BtOK: TButton;
    BtQuit: TButton;
    EdOut: TEdit;
    EdModel: TEdit;
    EdSVM: TEdit;
    LblOut: TLabel;
    LblModel: TLabel;
    LblSVM: TLabel;
    LblWidth: TLabel;
    LblNodes: TLabel;
    LblHeight: TLabel;
    MmLog: TMemo;
    ODModel: TOpenDialog;
    ODSVM: TOpenDialog;
    RBPseudo: TRadioButton;
    RBRect: TRadioButton;
    SEWidth: TSpinEdit;
    SEHeight: TSpinEdit;
    SENodes: TSpinEdit;
    procedure BtModelClick(Sender: TObject);
    procedure BtOKClick(Sender: TObject);
    procedure BtQuitClick(Sender: TObject);
    procedure BtSVMClick(Sender: TObject);
    procedure RBPseudoChange(Sender: TObject);
    procedure SEWidthChange(Sender: TObject);
  private

  public

  end;

var
  FrmGTMReSample: TFrmGTMReSample;

implementation

{$R *.lfm}

{ TFrmGTMReSample }

procedure TFrmGTMReSample.BtQuitClick(Sender: TObject);
begin
  {$IfDef DARWIN}Halt;{$EndIf}
  {$IfNDef DARWIN}Close;{$EndIf}
end;

procedure TFrmGTMReSample.BtSVMClick(Sender: TObject);
begin
  if (ODSVM.Execute) then
    EdSVM.Text:=ODSVM.FileName;
end;

procedure TFrmGTMReSample.RBPseudoChange(Sender: TObject);
begin
  If RBPseudo.Checked then
  begin
    LblWidth.Visible:=False;
    LblHeight.Visible:=False;
    SEWidth.Visible:=False;
    SEHeight.Visible:=False;
    LblNodes.Visible:=True;
    SENodes.Visible:=True;
  end else begin
    LblWidth.Visible:=True;
    LblHeight.Visible:=True;
    SEWidth.Visible:=True;
    SEHeight.Visible:=True;
    LblNodes.Visible:=False;
    SENodes.Visible:=False;
  end;
end;

procedure TFrmGTMReSample.SEWidthChange(Sender: TObject);
begin
  SEHeight.Value:=SEWidth.Value;
end;

procedure TFrmGTMReSample.BtModelClick(Sender: TObject);
begin
  if ODModel.Execute then
  begin
    EdModel.Text:=ODModel.FileName;
    EdOut.Text:=ExtractFileNameWithoutExt(EdModel.Text);
  end;
end;

procedure TFrmGTMReSample.BtOKClick(Sender: TObject);
var
  GTMRSopt: TGTMReSample_option;
begin
  GTMRSopt:=TGTMReSample_option.Create;
  GTMRSopt.model:=EdModel.Text;
  GTMRSopt.input:=EdSVM.Text;
  GTMRSopt.output:=EdOut.Text;
  if RBRect.Checked then
  begin
    GTMRSopt.height:=SEHeight.Value;
    GTMRSopt.width:=SEWidth.Value;
    GTMRSopt.newK:=0;
  end else
  begin
      GTMRSopt.height:=0;
      GTMRSopt.width:=0;
      GTMRSopt.newK:=SENodes.Value;
  end;
  GTMRSopt.b3D:=False;
  if GTMRSopt.input<>'' then
    GTMRSopt.bRmat:=True
  else
    GTMRSopt.bRmat:=False;
  if (GTMRSopt.newK<>0) or ((GTMRSopt.height<>0) and (GTMRSopt.width<>0)) then
    DoReSampling(GTMRSopt,MmLog.Lines)
  else
    ShowMessage('WARNING: number of nodes not defined');
  FreeAndNil(GTMRSopt);
end;

end.

