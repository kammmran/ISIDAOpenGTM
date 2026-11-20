program xGTMNodeSelect;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, uxGTMNodeSelect, UcGTM, UGTMBase, UGTMFull, UGTMSparse, UGTMXML,
  utypes, ISIDA_descriptor
  { you can add units after this }, SysUtils;

{$R *.res}

begin
  {$IfDef WINDOWS}DefaultFormatSettings.DateSeparator:='-';{$EndIf}
  {$IfDef LOCALES}DefaultFormatSettings.DecimalSeparator:='.';DefaultFormatSettings.ShortDateFormat:='d/m/y';{$EndIf}
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TFrmxGTMNodeSelect, FrmxGTMNodeSelect);
  Application.Run;
end.

