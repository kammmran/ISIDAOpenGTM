unit gtmr_option;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DOM, XMLRead, XMLWrite;

type
  TGTMROpt = class(TPersistent)
  private
    FMinRespAD: double;//Min responsability value to be in applicability domain
    FMinResp: double; //Min responsability value to count for landscape
    FMinDens: double; //Min density
    FNfolds: integer; //Number of folds in cross-validation
    FMapFileNme: string; //The GTM file
    FtrRspFileNme: string; // training Responsibilities file name
    FtrPrpFileNme: string; // training Properties file name
    FteRspFileNme: string; // test Responsibilities file name
    FtePrpFileNme: string; // test Properties file name
    FOutFileNme: string; //Output base name
    FMdlFileNme: string; //Landscape file name
    FAuthor: string; //Author of the landscape
    FuseLandscape: boolean; //Use landscape
    FPropComment: string; //Comments for property file
    FPropName: shortstring; //short property name (max 255 char)
    FTitle: string; // A title for the map
    FwriteLSOnly: boolean; //Write the landscape
    FBuild: boolean; //Building mode
    FPred: boolean; //Prediction mode
    FValidate: boolean; // Validation mode
    Ftau: double;//Trustworthiness constant - recommended value 0.01
    Falpha: double;//Trustworthiness density exponent - recommended value 0.1
    Fbeta: double;//Trustworthiness coherence exponent - recommended value 1.0
    FTthrd: double;//Thrustworthiness threshold AD - recommended value 0.7
  public
    property MinRespAD: double read FMinRespAD write FMinRespAD;
    property MinResp: double read FMinResp write FMinResp;
    property MinDens: double read FMinDens write FMinDens;
    property Nfolds: integer read FNfolds write FNfolds;
    property MapFileNme: string read FMapFileNme write FMapFileNme;
    property trRspFileNme: string read FtrRspFileNme write FtrRspFileNme;
    property trPrpFileNme: string read FtrPrpFileNme write FtrPrpFileNme;
    property teRspFileNme: string read FteRspFileNme write FteRspFileNme;
    property tePrpFileNme: string read FtePrpFileNme write FtePrpFileNme;
    property OutFileNme: string read FOutFileNme write FOutFileNme;
    property MdlFileNme: string read FMdlFileNme write FMdlFileNme;
    property Author: string read FAuthor write FAuthor;
    property useLandscape: boolean read FuseLandscape write FuseLandscape;
    property PropComment: string read FPropComment write FPropComment;
    property PropName: shortstring read FPropName write FPropName;
    property Title: string read FTitle write FTitle;
    property writeLSOnly: boolean read FwriteLSOnly write FwriteLSOnly;
    property Build: boolean read FBuild write FBuild;
    property Pred: boolean read FPred write FPred;
    property Validate: boolean read FValidate write FValidate;
    property tau: double read Ftau write Ftau;
    property alpha: double read Falpha write Falpha;
    property beta: double read Fbeta write Fbeta;
    property Tthrd: double read FTthrd write FTthrd;

    procedure WriteOptions();
    destructor Destroy; override;
    constructor Create;
  end;


implementation

destructor TGTMROpt.Destroy;
begin
  inherited Destroy;
end;

constructor TGTMROpt.Create;
begin
  MinRespAD := 0.0;//Min responsability value to be in applicability domain
  MinResp := 0.0; //Min responsability value to count for landscape
  MinDens := 0.0; //Min density
  tau:=0.0;
  alpha:=0.0;
  beta:=0.0;
  Tthrd:=0.0;;
  Nfolds:=0;
  MapFileNme := '';
  trRspFileNme := '';
  trPrpFileNme := '';
  teRspFileNme := '';
  tePrpFileNme := '';
  OutFileNme := 'default';
  Author:='';
  useLandscape := False;
  writeLSOnly  := False;
  PropName:='default';
  Title:='no title';
  Build    := False;
  Pred     := False;
  Validate := False;
end;

procedure TGTMROpt.WriteOptions();
  begin
    writeln('***********************************');
    writeln('*                                 *');
    writeln('*           ISIDA/GTMReg          *');
    writeln('*                                 *');
    writeln('* Marcou G., Lin A., Plyer L.     *');
    writeln('*                                 *');
    writeln('* Université de Strasbourg  2023  *');
    writeln('***********************************');
    writeln;
    writeln('GTM model                               : ' + MapFileNme);
    if not useLandscape then
    begin
      writeln('Input training responsibilities         : ' + trRspFileNme);
      writeln('Input training properties               : ' + trPrpFileNme);
      writeln('Property short name                     : ' + PropName);
      writeln('Title                                   : ' + Title);
      writeln('Author                                  : ' + Author);
      writeln('Comment                                 : ' + PropComment);
    end
    else
    begin
      writeln('Input landscape                         : ' + MdlFileNme);
      writeln('Input test responsibilities             : ' + teRspFileNme);
      writeln('Input test properties                   : ' + tePrpFileNme);
    end;
    writeln('Min. responsibility value for AD        : ' + FloatToStr(MinRespAD));
    writeln('Min. responsibility value for landscape : ' + FloatToStr(MinResp));
    writeln('Min. density value for AD               : ' + FloatToStr(MinDens));
    writeln('Trustwothiness - tau                    : ' + FloatToStr(tau));
    writeln('Trustwothiness - alpha                  : ' + FloatToStr(alpha));
    writeln('Trustwothiness - beta                   : ' + FloatToStr(beta));
    writeln('Trustwothiness - threshold              : ' + FloatToStr(Tthrd));
    writeln('Base of output file names               : ' + OutFileNme);
    writeln;
    if Build then writeln('Building a landscape');
    if Pred then begin
      if FileExists(tePrpFileNme) then begin
        writeln('Model validation on new data');
        writeln('Input test responsibilities         : ' + teRspFileNme);
        writeln('Input test properties               : ' + tePrpFileNme);
      end else begin
        writeln('Using landscape for predictions');
        writeln('Responsibilities                    : ' + teRspFileNme);
      end;
    end;
    if Validate then begin
      writeln('Validation of landscape');
      Writeln('Cross-validation, number of folds     : ' + IntToStr(Nfolds));
    end;
    writeln('***********************************');
  end;

end.

