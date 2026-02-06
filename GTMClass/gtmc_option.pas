unit gtmc_option;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  DOM,
  XMLRead,
  XMLWrite;

type
  TGTMCOpt = class(TPersistent)
  private
    private
    FMinRespAD: double; // Min responsability value to be in applicability domain
    FMinResp: double;   // Min responsability value to count for landscape
    FMinDens: double;   // Min density
    FNfolds: integer;   // Number of folds in cross-validation
    FMapFileNme: string;    // The GTM file
    FtrRspFileNme: string;  // Training Responsibilities file name
    FtrPrpFileNme: string;  // Training Properties file name
    FteRspFileNme: string;  // Test Responsibilities file name
    FtePrpFileNme: string;  // Test Properties file name
    FOutFileNme: string;    // Output base name
    FMdlFileNme: string;    // Landscape file name
    FAuthor: string;    // Author of the landscape
    FuseLandscape: boolean; // Use landscape
    FPropComment: string;   // Comments for property file
    FPropName: shortstring; // Short property name (max 255 char)
    FTitle: string;     // A title for the map
    FwriteLSOnly: boolean; // Write the landscape
    FBuild: boolean;    // Building mode
    FPred: boolean;     // Prediction mode
    FValidate: boolean; // Validation mode
    FclassNormalization: boolean;  // Class normalization
    FPRatio: double;    // Prevalence ratio - recommended value 0.5
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
    property classNormalization: boolean read FclassNormalization write FclassNormalization;
    property PRatio: double read FPRatio write FPRatio;
    //procedure SaveToFile(const FileName: string);
    //procedure LoadFromFile(const FileName: string);

    procedure WriteOptions();
    constructor Create;
    destructor Destroy; override;


  end;


implementation

destructor TGTMCOpt.Destroy;
begin
  inherited Destroy;
end;

constructor TGTMCOpt.Create;
begin
  MinRespAD := 0.0;//Min responsability value to be in applicability domain
  MinResp := 0.0; //Min responsability value to count for landscape
  MinDens := 0.0; //Min density
  Nfolds:=0;      // Cross-validation
  MapFileNme := '';
  trRspFileNme := '';
  trPrpFileNme := '';
  teRspFileNme := '';
  tePrpFileNme := '';
  OutFileNme := 'default';
  MdlFileNme:= 'default';
  Author:='';
  useLandscape := False;
  PropComment:='';
  PropName:='default';
  Title:='no title';
  writeLSOnly  := False;
  Build    := False;
  Pred     := False;
  Validate := False;
  classNormalization:= False;
  PRatio:=1.0; // Prevalence ratio
end;

{procedure TGTMCOpt.SaveToFile(const FileName: string);
var
  Doc: TXMLDocument;
  Root, Node: TDOMNode;
begin
  Doc := TXMLDocument.Create;
  try
    // Create the root element
    Root := Doc.CreateElement('TGTMCOpt');
    Doc.AppendChild(Root);

    // Add elements for each field
    Node := Doc.CreateElement('MinRspAD');
    Node.TextContent := FloatToStr(FMinRspAD);
    Root.AppendChild(Node);

    Node := Doc.CreateElement('MinRspLd');
    Node.TextContent := FloatToStr(FMinRspLd);
    Root.AppendChild(Node);

    Node := Doc.CreateElement('MapFileNme');
    Node.TextContent := FMapFileNme;
    Root.AppendChild(Node);

    // ...

    // Save XML to file
    WriteXMLFile(Doc, FileName);
  finally
    Doc.Free;
  end;
end;

procedure TGTMCOpt.LoadFromFile(const FileName: string);
var
  Doc: TXMLDocument;
  Root: TDOMNode;
begin
  ReadXMLFile(Doc, FileName);
  try
    Root := Doc.DocumentElement;

    // Load each element into respective fields
    if Assigned(Root.FindNode('MinRspAD')) then
      FMinRspAD := StrToFloat(Root.FindNode('MinRspAD').TextContent);

    if Assigned(Root.FindNode('MinRspLd')) then
      FMinRspLd := StrToFloat(Root.FindNode('MinRspLd').TextContent);

    if Assigned(Root.FindNode('MapFileNme')) then
      FMapFileNme := Root.FindNode('MapFileNme').TextContent;

    // ... [Repeat for other fields]
  finally
    Doc.Free;
  end;
end;}

procedure TGTMCOpt.WriteOptions();
  begin
    writeln('***********************************');
    writeln('*                                 *');
    writeln('*           ISIDA/GTMClass        *');
    writeln('*                                 *');
    writeln('* Marcou G.Plyer L.               *');
    writeln('*                                 *');
    writeln('* Université de Strasbourg  2024  *');
    writeln('***********************************');
    writeln;
    writeln('GTM model                                 : ' + MapFileNme);
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
    if classNormalization=true then
      writeln('Used class normalization                : '+BoolToStr(classNormalization));
    writeln('Min. responsibility value for AD        : ' + FloatToStr(MinRespAD));
    writeln('Min. responsibility value for landscape : ' + FloatToStr(MinResp));
    writeln('Min. density value for AD               : ' + FloatToStr(MinDens));
    writeln('Prevalence Ratio - PRatio               : ' + FloatToStr(PRatio));
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

