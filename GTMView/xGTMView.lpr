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
  RequireDerivedFormResource:=True;
  Application.Initialize;
  CheckLicence(); //after Initialize: on macOS (Cocoa) a dialog shown earlier creates a plain NSApplication and the LCL main loop then crashes
  Application.CreateForm(TFormGTMView, FormGTMView);
  Application.Run;
end.

