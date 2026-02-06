program GTMmanifold;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, uGTMmanifold, GLScene_RunTime, UnitLicence
  { you can add units after this },sysutils;

{$R *.res}

begin
  {$IfDef WINDOWS}DefaultFormatSettings.DateSeparator:='-';{$EndIf}
  {$IfDef LOCALES}DefaultFormatSettings.DecimalSeparator:='.';DefaultFormatSettings.ShortDateFormat:='d/m/y';{$EndIf}
  CheckLicence();
  RequireDerivedFormResource:=True;
  Application.Initialize;
  Application.CreateForm(TFrmGTMmanifold, FrmGTMmanifold);
  Application.Run;
end.

