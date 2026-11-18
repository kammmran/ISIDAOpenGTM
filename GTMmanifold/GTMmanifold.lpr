program GTMmanifold;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, uGTMmanifold, UnitLicence
  { you can add units after this },sysutils;

{$R *.res}

begin
  {$IfDef WINDOWS}DefaultFormatSettings.DateSeparator:='-';{$EndIf}
  {$IfDef LOCALES}DefaultFormatSettings.DecimalSeparator:='.';DefaultFormatSettings.ShortDateFormat:='d/m/y';{$EndIf}
  RequireDerivedFormResource:=True;
  Application.Initialize;
  CheckLicence(); //after Initialize: on macOS (Cocoa) a dialog shown earlier creates a plain NSApplication and the LCL main loop then crashes
  Application.CreateForm(TFrmGTMmanifold, FrmGTMmanifold);
  Application.Run;
end.

