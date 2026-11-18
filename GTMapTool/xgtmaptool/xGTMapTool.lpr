program xGTMapTool;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, lazcontrols, uxGTMapTool, UnitProc, UcGTM, UGTMBase, ugtm_options,
  UnitLicence, ISIDA_descriptor, utypes
  { you can add units after this },sysutils;

{$R *.res}

begin
  {$IfDef WINDOWS}DefaultFormatSettings.DateSeparator:='-';{$EndIf}
  {$IfDef LOCALES}DefaultFormatSettings.DecimalSeparator:='.';DefaultFormatSettings.ShortDateFormat:='d/m/y';{$EndIf}
  RequireDerivedFormResource:=True;
  Application.Initialize;
  CheckLicence(); //after Initialize: on macOS (Cocoa) a dialog shown earlier creates a plain NSApplication and the LCL main loop then crashes
  Application.CreateForm(TFGTMapTool, FGTMapTool);
  Application.Run;
end.

