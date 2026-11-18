program xGTMClass;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, uxGTMClass, UGTMClass, GTMClassFunctions, UnitClsStats, UnitCVsvm
  { you can add units after this }, sysutils, UnitLicence;

{$R *.res}

begin
  {$IfDef WINDOWS}DefaultFormatSettings.DateSeparator:='-';{$EndIf}
  {$IfDef LOCALES}DefaultFormatSettings.DecimalSeparator:='.';DefaultFormatSettings.ShortDateFormat:='d/m/y';{$EndIf}
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  Application.Initialize;
  CheckLicence(); //after Initialize: on macOS (Cocoa) a dialog shown earlier creates a plain NSApplication and the LCL main loop then crashes
  Application.CreateForm(TFrmxGTMClass, FrmxGTMClass);
  Application.Run;
end.

