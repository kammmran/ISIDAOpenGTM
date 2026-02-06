program xGTMView;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, tachartlazaruspkg, fpvectorialpkg, UnitGTMView, UGTMXML,
  U_BASE_GRAPHES, U_GRAPHES, U_TYPE_GRAPHES, UnitMoleculeGraphic, UnitMolDraw,
  UnitLicence,sysutils;

{$R *.res}

begin
  {$IfDef WINDOWS}DefaultFormatSettings.DateSeparator:='-';{$EndIf}
  {$IfDef LOCALES}DefaultFormatSettings.DecimalSeparator:='.';DefaultFormatSettings.ShortDateFormat:='d/m/y';{$EndIf}
  CheckLicence();
  RequireDerivedFormResource:=True;
  Application.Initialize;
  Application.CreateForm(TFormGTMView, FormGTMView);
  Application.Run;
end.

